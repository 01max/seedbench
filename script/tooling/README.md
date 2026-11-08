# Synthetic Linux tooling check

Build and run the isolated verification image from the repository root:

```sh
docker build --platform linux/amd64 -t seedbench-tools:verification \
  -f script/tooling/Dockerfile script/tooling
docker run --rm --platform linux/amd64 --network none --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=256m --cap-drop ALL \
  --security-opt no-new-privileges --pids-limit 128 --memory 1g --cpus 2 \
  seedbench-tools:verification
```

Only this directory enters the build context. The run has no host mounts,
network access, operator files, or credentials, and uses UID/GID `65534:65534`.
All fixtures and extracted sidecars are generated in disposable container
scratch space. Each external command has a 60-second timeout. The image uses
a digest-pinned Debian Bookworm base; installed package versions are included
in the JSON report. Package resolution uses the current Debian repositories,
so preserve the report and image identity when comparing runs.

The check exercises Calibre metadata/text extraction from synthetic EPUB and
MOBI, Poppler PDF metadata/text extraction, French Tesseract OCR of a rendered
scanned PDF into a text sidecar, and mktorrent creation. A separate bencode
reader checks private metadata, the exact single-file inventory, and every
piece hash, including detection of changed bytes. Source hashes are checked
after inspection and torrent creation.

Calibre conversion is used to manufacture the synthetic MOBI fixture and to
extract analysis text. It is not permission to replace an uploaded ebook.
`ebook-meta` can exit successfully for malformed MOBI input; the report records
that behavior and the missing signature. Real intake must separately validate
file signatures and structure before accepting extracted metadata. Passing
these fixtures does not certify encrypted, hostile, or arbitrary ebooks.

See [provider and tooling observations](../../docs/provider-tooling.md) for the
tested versions, actual provider responses, and remaining prerequisites.
