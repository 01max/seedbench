"""Create malformed synthetic containers, never modify operator files."""
import pathlib
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(root / "book.epub") as original:
    members = {name: original.read(name) for name in original.namelist()}


def save(name, changes):
    with zipfile.ZipFile(root / name, "w", compression=zipfile.ZIP_DEFLATED) as target:
        for entry, content in {**members, **changes}.items():
            target.writestr(entry, content, compress_type=zipfile.ZIP_STORED if entry == "mimetype" else zipfile.ZIP_DEFLATED)


save("encrypted.epub", {"META-INF/encryption.xml": b'<encryption><EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/></encryption>'})
save("bomb.epub", {"large.txt": b"x" * (8 * 1024 * 1024 + 1)})
save("entity.epub", {"book.opf": b'<!DOCTYPE package [<!ENTITY e "unsafe">]><package>&e;</package>'})
save("utf16.epub", {"book.opf": '<!DOCTYPE package [<!ENTITY e "unsafe">]><package>&e;</package>'.encode("utf-16")})
save("missing.epub", {"book.opf": members["book.opf"].replace(b"chapter.xhtml", b"missing.xhtml")})
save("escape.epub", {"book.opf": members["book.opf"].replace(b"chapter.xhtml", b"../../outside.xhtml")})
save("nested.epub", {"book.opf": members["book.opf"].replace(b"chapter.xhtml", b"nested/../chapter.xhtml")})
(root / "disguised.pdf").write_bytes((root / "book.epub").read_bytes())
(root / "broken.mobi").write_bytes(b"\0" * 60 + b"BOOKMOBI" + b"\0" * 100)
# Change a member without updating its CRC.
raw = bytearray((root / "book.epub").read_bytes())
position = raw.index(b"Sample text")
raw[position] = ord("X")
(root / "crc.epub").write_bytes(raw)
