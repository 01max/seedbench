"""Exercise Linux ebook tools with disposable, synthetic fixtures only."""

import hashlib
import json
import os
import platform
import subprocess
import tempfile
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.pdfgen import canvas


def run(*arguments, succeeds=True):
    result = subprocess.run(arguments, capture_output=True, timeout=60, check=False)
    if succeeds and result.returncode:
        raise RuntimeError(f"{arguments[0]} failed ({result.returncode}): "
                           + result.stderr.decode(errors="replace")[-2000:])
    if not succeeds and result.returncode == 0:
        raise AssertionError(f"{arguments[0]} accepted corrupt fixture")
    return result.stdout.decode(errors="replace")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_epub(root):
    path = root / "synthetic.epub"
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        archive.writestr("META-INF/container.xml", '''<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
<rootfiles><rootfile full-path="OEBPS/content.opf"
media-type="application/oebps-package+xml"/></rootfiles></container>''')
        archive.writestr("OEBPS/content.opf", '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="id">urn:uuid:11111111-1111-4111-8111-111111111111</dc:identifier>
<dc:title>Synthetic verification</dc:title><dc:creator>Test Author</dc:creator>
<dc:language>fr</dc:language></metadata><manifest>
<item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
<item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
</manifest><spine toc="toc"><itemref idref="chapter"/></spine></package>''')
        archive.writestr("OEBPS/chapter.xhtml", '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Synthetic verification</title>
</head><body><h1>Document synthetique</h1>
<p>SEEDBENCH SYNTHETIC EVIDENCE. Ceci est un document de verification.</p></body></html>''')
        archive.writestr("OEBPS/toc.ncx", '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head>
<meta name="dtb:uid" content="urn:uuid:11111111-1111-4111-8111-111111111111"/>
</head><docTitle><text>Synthetic verification</text></docTitle><navMap>
<navPoint id="chapter" playOrder="1"><navLabel><text>Document synthetique</text>
</navLabel><content src="chapter.xhtml"/></navPoint></navMap></ncx>''')
    return path


def bdecode(data):
    def read(offset):
        token = data[offset:offset + 1]
        if token == b"i":
            end = data.index(b"e", offset)
            return int(data[offset + 1:end]), end + 1
        if token in (b"l", b"d"):
            output = [] if token == b"l" else {}
            offset += 1
            while data[offset:offset + 1] != b"e":
                value, offset = read(offset)
                if token == b"d":
                    item, offset = read(offset)
                    output[value] = item
                else:
                    output.append(value)
            return output, offset + 1
        end = data.index(b":", offset)
        length = int(data[offset:end])
        start = end + 1
        return data[start:start + length], start + length

    value, offset = read(0)
    assert offset == len(data)
    return value


def verify_ebooks(root):
    epub = make_epub(root)
    original_epub = digest(epub)
    assert "Synthetic verification" in run("ebook-meta", str(epub))
    epub_text = root / "epub.txt"
    run("ebook-convert", str(epub), str(epub_text))
    assert "SEEDBENCH SYNTHETIC EVIDENCE" in epub_text.read_text()

    # Conversion manufactures the synthetic MOBI fixture; operator files are never mounted.
    mobi = root / "synthetic.mobi"
    run("ebook-convert", str(epub), str(mobi), "--mobi-file-type", "old")
    original_mobi = digest(mobi)
    assert mobi.read_bytes()[60:68] == b"BOOKMOBI"
    assert "Synthetic verification" in run("ebook-meta", str(mobi))
    mobi_text = root / "mobi.txt"
    run("ebook-convert", str(mobi), str(mobi_text))
    assert "SEEDBENCH SYNTHETIC EVIDENCE" in mobi_text.read_text()
    assert digest(epub) == original_epub and digest(mobi) == original_mobi

    corrupt = root / "corrupt.mobi"
    corrupt.write_bytes(b"not an ebook")
    corrupt_result = subprocess.run(["ebook-meta", str(corrupt)], capture_output=True,
                                    timeout=60, check=False)
    assert corrupt.read_bytes()[60:68] != b"BOOKMOBI"
    return epub, {"epub_metadata_and_text": True, "mobi_metadata_and_text": True,
                  "corrupt_mobi_signature_mismatch": True,
                  "ebook_meta_corrupt_mobi_exit_code": corrupt_result.returncode,
                  "ebook_hashes_preserved": True}


def verify_pdf_and_ocr(root):
    pdf = root / "synthetic.pdf"
    document = canvas.Canvas(str(pdf))
    document.setTitle("Synthetic verification")
    document.drawString(72, 720, "SEEDBENCH SYNTHETIC EVIDENCE")
    document.save()
    original_pdf = digest(pdf)
    assert "Pages:" in run("pdfinfo", str(pdf))
    assert "SEEDBENCH SYNTHETIC EVIDENCE" in run("pdftotext", str(pdf), "-")

    image = Image.new("RGB", (2000, 600), "white")
    drawing = ImageDraw.Draw(image)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 64)
    drawing.text((80, 150), "DOCUMENT SYNTHETIQUE SEEDBENCH", font=font, fill="black")
    png = root / "scan-source.png"
    image.save(png)
    scanned_pdf = root / "scanned.pdf"
    document = canvas.Canvas(str(scanned_pdf), pagesize=(1000, 300))
    document.drawImage(str(png), 0, 0, width=1000, height=300)
    document.save()
    original_scan = digest(scanned_pdf)
    assert not run("pdftotext", str(scanned_pdf), "-").strip()
    rendered = root / "rendered"
    run("pdftoppm", "-singlefile", "-scale-to", "2000", "-png", str(scanned_pdf), str(rendered))
    sidecar = root / "ocr"
    run("tesseract", str(rendered.with_suffix(".png")), str(sidecar), "-l", "fra", "--psm", "6", "txt")
    assert "DOCUMENT SYNTHETIQUE SEEDBENCH" in sidecar.with_suffix(".txt").read_text()
    assert digest(pdf) == original_pdf and digest(scanned_pdf) == original_scan
    corrupt = root / "corrupt.pdf"
    corrupt.write_bytes(b"not a PDF")
    run("pdfinfo", str(corrupt), succeeds=False)
    return {"pdf_metadata_and_text": True, "scanned_pdf_french_ocr_sidecar": True,
            "corrupt_pdf_rejected": True, "pdf_hashes_preserved": True}


def verify_torrent(root, payload):
    torrent = root / "synthetic.torrent"
    original = digest(payload)
    # The loopback discard port is inert; creation never contacts this URL.
    run("mktorrent", "-p", "-a", "http://127.0.0.1:9/announce", "-l", "18",
        "-o", str(torrent), str(payload))
    metadata = bdecode(torrent.read_bytes())
    info = metadata[b"info"]
    assert info[b"private"] == 1
    assert info[b"name"].decode() == payload.name
    assert info[b"length"] == payload.stat().st_size
    assert b"files" not in info
    content = payload.read_bytes()
    size = info[b"piece length"]
    expected = b"".join(hashlib.sha1(content[i:i + size]).digest()
                        for i in range(0, len(content), size))
    assert info[b"pieces"] == expected
    assert digest(payload) == original
    modified = content[:-1] + bytes([content[-1] ^ 1])
    altered = b"".join(hashlib.sha1(modified[i:i + size]).digest()
                       for i in range(0, len(modified), size))
    assert altered != info[b"pieces"]
    return {"private_single_file_torrent": True, "piece_hashes_verified": True,
            "byte_mismatch_detected": True, "payload_hash_preserved": True}


def main():
    with tempfile.TemporaryDirectory(prefix="seedbench-tools-") as directory:
        root = Path(directory)
        os.chdir(root)
        payload, ebooks = verify_ebooks(root)
        pdf = verify_pdf_and_ocr(root)
        torrent = verify_torrent(root, payload)
        packages = run("dpkg-query", "-W", "-f=${Package}=${Version}\n", "calibre",
                       "poppler-utils", "tesseract-ocr", "tesseract-ocr-fra", "mktorrent",
                       "python3", "python3-pil", "python3-reportlab").splitlines()
        print(json.dumps({"system": platform.system(), "machine": platform.machine(),
                          "packages": packages, "checks": {**ebooks, **pdf, **torrent}}, indent=2))


if __name__ == "__main__":
    main()
