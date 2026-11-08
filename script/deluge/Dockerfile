FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

RUN apt-get update \
    && apt-get install -y --no-install-recommends deluged=2.2.0-1 deluge-web=2.2.0-1 \
    && rm -rf /var/lib/apt/lists/*

COPY verify.py test_startup.py /opt/deluge/
USER 65534:65534
ENTRYPOINT ["/usr/bin/python3", "/opt/deluge/verify.py"]
