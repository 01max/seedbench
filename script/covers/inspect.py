"""Read bounded raster properties and a comparison grid without changing image bytes."""
import hashlib
import json
import sys
import warnings
from PIL import Image, ImageOps

Image.MAX_IMAGE_PIXELS = 20_000_000
warnings.simplefilter('error', Image.DecompressionBombWarning)
try:
    with Image.open(sys.argv[1]) as image:
        if image.format not in ('JPEG', 'PNG', 'WEBP') or getattr(image, 'n_frames', 1) != 1:
            raise ValueError('Unsupported raster')
        width, height = image.size
        if min(width, height) < 1 or max(width, height) > 12_000 or width * height > 20_000_000:
            raise ValueError('Raster bounds exceeded')
        media_type = Image.MIME[image.format]
        image.load()
        displayed = ImageOps.exif_transpose(image)
        width, height = displayed.size
        grid = list(displayed.convert('RGB').resize((16, 24)).tobytes())
    with open(sys.argv[1], 'rb') as source:
        digest = hashlib.sha256(source.read()).hexdigest()
    print(json.dumps({'width': width, 'height': height, 'media_type': media_type, 'sha256': digest, 'grid': grid}))
except (OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
    sys.exit(1)
