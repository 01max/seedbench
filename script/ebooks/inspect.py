"""Read-only ebook measurements. No network, credentials, or workflow decisions."""
import hashlib
import json
import pathlib
import re
import sys
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from urllib.parse import unquote, urlsplit

MAX_ENTRY = 8 * 1024 * 1024
MAX_TOTAL = 128 * 1024 * 1024
MAX_ENTRIES = 2048
SAMPLE = 3000


class Invalid(Exception):
    pass


def require(condition, code):
    if not condition:
        raise Invalid(code)


def xml(data):
    require(len(data) <= 2 * 1024 * 1024, "resource_limit")
    require(not re.search(br"<!\s*(ENTITY|DOCTYPE)", data, re.I), "unsafe_xml")
    return ET.fromstring(data)


def local(tag):
    return tag.split("}")[-1]


def text(node):
    return " ".join(" ".join(node.itertext()).split())


def reference(base, href):
    uri = urlsplit(href)
    require(not uri.scheme and not uri.netloc and not uri.query, "unsafe_reference")
    path = pathlib.PurePosixPath(base).parent / unquote(uri.path)
    require(not path.is_absolute() and ".." not in path.parts and "\\" not in str(path), "unsafe_reference")
    return str(path)


def cover(data, source, work):
    from PIL import Image
    import io
    require(len(data) <= MAX_ENTRY, "resource_limit")
    with Image.open(io.BytesIO(data)) as image:
        require(image.format in ("JPEG", "PNG", "WEBP") and image.width * image.height <= 40_000_000, "unsupported_cover")
        width, height, media = image.width, image.height, Image.MIME[image.format]
        image.verify()
    name = hashlib.sha256(data).hexdigest()
    (work / name).write_bytes(data)
    return {"file": name, "sha256": name, "width": width, "height": height,
            "media_type": media, "source": source, "size_bytes": len(data)}


def epub(source, work):
    with zipfile.ZipFile(source) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        require(0 < len(entries) <= MAX_ENTRIES and len(set(names)) == len(names), "resource_limit")
        require(sum(entry.file_size for entry in entries) <= MAX_TOTAL, "resource_limit")
        for entry in entries:
            require(entry.file_size <= MAX_ENTRY, "resource_limit")
            require(not entry.flag_bits & 1, "encrypted")
            require(entry.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), "unsupported_compression")
            require(not pathlib.PurePosixPath(entry.filename).is_absolute() and ".." not in pathlib.PurePosixPath(entry.filename).parts and "\\" not in entry.filename, "unsafe_reference")
        require(entries[0].filename == "mimetype" and entries[0].compress_type == zipfile.ZIP_STORED, "invalid_epub")
        require(archive.read("mimetype") == b"application/epub+zip", "signature_mismatch")
        # Read every member in chunks: CRC errors and lying sizes must fail even on unsampled entries.
        for entry in entries:
            with archive.open(entry) as stream:
                count = 0
                while chunk := stream.read(65536):
                    count += len(chunk)
                    require(count <= MAX_ENTRY, "resource_limit")
            require(count == entry.file_size, "invalid_epub")
        container = xml(archive.read("META-INF/container.xml"))
        rootfiles = [node for node in container.iter() if local(node.tag) == "rootfile"]
        require(bool(rootfiles), "invalid_epub")
        package_path = reference("root", rootfiles[0].attrib["full-path"])
        package = xml(archive.read(package_path))
        require(local(package.tag) == "package", "invalid_epub")
        if "META-INF/encryption.xml" in names:
            encryption = xml(archive.read("META-INF/encryption.xml"))
            allowed = {"http://www.idpf.org/2008/embedding", "http://ns.adobe.com/pdf/enc#RC"}
            require(all(node.attrib.get("Algorithm") in allowed for node in encryption.iter() if local(node.tag) == "EncryptionMethod"), "encrypted")
        metadata = next(node for node in package if local(node.tag) == "metadata")
        observations = [{"field": {"creator": "author", "identifier": "isbn"}.get(local(node.tag), local(node.tag)),
                         "value": text(node)[:2000], "source": package_path + "#" + node.attrib.get("id", local(node.tag))}
                        for node in metadata if local(node.tag) in ("title", "creator", "identifier", "publisher", "language", "date", "source") and text(node)]
        manifest = {node.attrib["id"]: node for node in package.iter() if local(node.tag) == "item"}
        require(bool(manifest), "invalid_epub")
        for item in manifest.values():
            require(reference(package_path, item.attrib["href"]) in names, "missing_resource")
        spine = [manifest[node.attrib["idref"]] for node in package.iter() if local(node.tag) == "itemref"]
        require(bool(spine), "invalid_epub")
        samples, markers = [], 0
        for index, item in enumerate(spine):
            path = reference(package_path, item.attrib["href"])
            # XHTML DOCTYPE declarations without an internal subset are common; never resolve them.
            raw = archive.read(path)
            require(not re.search(br"<!\s*ENTITY|<!DOCTYPE[^>]*\[", raw, re.I), "unsafe_xml")
            document = ET.fromstring(raw)
            markers += sum("pagebreak" in node.attrib.get("{http://www.idpf.org/2007/ops}type", "").split() for node in document.iter())
            if index < 2 or index == len(spine) - 1:
                samples.append({"source": path, "text": text(document)[:SAMPLE]})
        legacy = {node.attrib.get("content") for node in metadata if node.attrib.get("name") == "cover"}
        covers = []
        for key, item in manifest.items():
            if "cover-image" in item.attrib.get("properties", "").split() or key in legacy:
                require(len(covers) < 5, "resource_limit")
                path = reference(package_path, item.attrib["href"])
                covers.append(cover(archive.read(path), path, work))
        return {"structure": {"archive_entries": len(entries), "spine_documents": len(spine), "page_markers": markers,
                               "page_count": None, "scope": "all archive members and spine documents"},
                "metadata": observations, "samples": samples, "covers": covers}


def command(arguments, work):
    with (work / "tool-output").open("wb") as output, (work / "tool-errors").open("wb") as errors:
        completed = subprocess.run(arguments, stdout=output, stderr=errors, pass_fds=(3,), timeout=40, check=False)
    require(completed.returncode == 0, "tool_failed")
    require((work / "tool-output").stat().st_size <= 256 * 1024, "resource_limit")
    return (work / "tool-output").read_text(errors="replace")


def pdf(source, work, ocr):
    with open(source, "rb") as stream:
        require(stream.read(5) == b"%PDF-", "signature_mismatch")
    info = command(["pdfinfo", source], work)
    fields = dict(line.split(":", 1) for line in info.splitlines() if ":" in line)
    require(not fields.get("Encrypted", "").strip().startswith("yes"), "encrypted")
    pages = int(fields.get("Pages", "0").strip())
    require(0 < pages <= 2000, "resource_limit")
    samples, blank = [], []
    selected = sorted({1, min(2, pages), pages})
    for page in selected:
        target = work / ("text-" + str(page))
        command(["pdftotext", "-f", str(page), "-l", str(page), "-layout", source, str(target)], work)
        require(target.stat().st_size <= MAX_ENTRY, "resource_limit")
        content = target.read_text(errors="replace").strip()
        if not content:
            blank.append(page)
        samples.append({"source": "pdf:page:" + str(page), "text": content[:SAMPLE]})
    metadata = [{"field": key.lower(), "value": fields[key].strip()[:2000], "source": "pdfinfo:" + key}
                for key in ("Title", "Author", "Creator", "Producer", "CreationDate") if fields.get(key, "").strip()]
    covers = []
    command(["pdftoppm", "-f", "1", "-l", "1", "-singlefile", "-scale-to", "1600", "-png", source, str(work / "page")], work)
    covers.append(cover((work / "page.png").read_bytes(), "pdf:page:1:rendered", work))
    if ocr:
        for page in selected:
            prefix = work / ("ocr-page-" + str(page))
            command(["pdftoppm", "-f", str(page), "-l", str(page), "-singlefile", "-scale-to", "2000", "-png", source, str(prefix)], work)
            command(["tesseract", str(prefix) + ".png", str(prefix), "-l", "fra", "--psm", "6", "txt"], work)
            require(prefix.with_suffix(".txt").stat().st_size <= MAX_ENTRY, "resource_limit")
            samples.append({"source": "ocr:pdf:page:" + str(page), "text": prefix.with_suffix(".txt").read_text(errors="replace")[:SAMPLE]})
    return {"structure": {"page_count": pages, "sampled_pages": selected, "pages_without_text_in_sample": blank,
                           "scope": "PDF structure and selected pages; completeness not established", "ocr": ocr},
            "metadata": metadata, "samples": samples, "covers": covers}


def main():
    source, format_name, workspace = sys.argv[1:4]
    work = pathlib.Path(workspace)
    try:
        require(format_name in ("epub", "pdf"), "unsupported_format")
        result = epub(source, work) if format_name == "epub" else pdf(source, work, sys.argv[4] == "true")
        result["parser"] = format_name + "-1"
        result["error"] = None
    except subprocess.TimeoutExpired:
        result = {"error": "resource_limit"}
    except Invalid as error:
        result = {"error": str(error)}
    except (KeyError, ValueError, StopIteration, ET.ParseError, zipfile.BadZipFile, OSError):
        result = {"error": "corrupt"}
    output = json.dumps(result, ensure_ascii=True)
    require(len(output) <= 256 * 1024, "resource_limit")
    print(output)


if __name__ == "__main__":
    main()
