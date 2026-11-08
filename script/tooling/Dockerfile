FROM ruby@sha256:ff110532f77ece9a77d75159600193852442509aa5f1314beb3c99dc4b3298b4

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       calibre fonts-dejavu-core mktorrent poppler-utils python3-pil \
       python3-reportlab tesseract-ocr tesseract-ocr-fra \
    && rm -rf /var/lib/apt/lists/*

COPY verify.py /opt/tooling/verify.py
ENV CALIBRE_CONFIG_DIRECTORY=/tmp/calibre QT_QPA_PLATFORM=offscreen
USER 65534:65534
ENTRYPOINT ["/usr/bin/python3", "/opt/tooling/verify.py"]
