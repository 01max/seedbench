"""Generate small, synthetic ebook fixtures for parser contract checks."""
import io
import pathlib
import sys
import zipfile
from PIL import Image


def epub(root):
    image = io.BytesIO()
    Image.new("RGB", (600, 900), "purple").save(image, "PNG")
    with zipfile.ZipFile(root / "book.epub", "w") as book:
        book.writestr("mimetype", "application/epub+zip")
        book.writestr("META-INF/container.xml", '<container><rootfiles><rootfile full-path="book.opf"/></rootfiles></container>')
        book.writestr("book.opf", '''<package xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0" unique-identifier="isbn"><metadata><dc:title>Synthetic book</dc:title><dc:creator>Test author</dc:creator><dc:language>fr</dc:language><dc:identifier id="isbn">9780306406157</dc:identifier></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/><item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/></manifest><spine><itemref idref="chapter"/></spine></package>''')
        book.writestr("chapter.xhtml", '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Sample</title></head><body><p>Sample text for a synthetic book.</p></body></html>')
        book.writestr("cover.png", image.getvalue())


if __name__ == "__main__":
    epub(pathlib.Path(sys.argv[1]))
