"""Generate small, synthetic ebook fixtures for parser contract checks."""
import io
import pathlib
import sys
import zipfile
import os
import subprocess
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


def pdf(root):
    from reportlab.pdfgen.canvas import Canvas
    from reportlab.lib.utils import ImageReader
    canvas = Canvas(str(root / "book.pdf"))
    canvas.setTitle("Synthetic PDF")
    canvas.setAuthor("Test author")
    canvas.drawString(60, 700, "Synthetic PDF text for inspection.")
    canvas.showPage()
    canvas.save()
    image = Image.new("RGB", (1600, 2000), "white")
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 50)
    draw.text((100, 200), "Document synthetique pour OCR", fill="black", font=font)
    canvas = Canvas(str(root / "scan.pdf"))
    canvas.drawImage(ImageReader(image), 0, 0, width=595, height=842)
    canvas.showPage()
    canvas.save()


if __name__ == "__main__":
    root = pathlib.Path(sys.argv[1])
    epub(root)
    pdf(root)
    if len(sys.argv) > 2 and sys.argv[2] == "mobi":
        subprocess.run(["ebook-convert", str(root / "book.epub"), str(root / "book.mobi"), "--mobi-file-type", "old"],
                       env={**os.environ, "QT_QPA_PLATFORM": "offscreen"}, stdout=subprocess.DEVNULL, check=True)
