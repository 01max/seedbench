FROM ruby@sha256:ff110532f77ece9a77d75159600193852442509aa5f1314beb3c99dc4b3298b4

COPY verify.rb /opt/storage/verify.rb
RUN mkdir -m 0700 /restricted-probe-root
USER 65534:65534
ENTRYPOINT ["ruby", "/opt/storage/verify.rb"]
