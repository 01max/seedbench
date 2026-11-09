# Provider and tooling observations

Verified on 2026-11-07. Only synthetic text and a generated checkerboard image
were sent to providers. The supplied ebooks were not sent to either provider,
and no C411 publication or distribution was started.

## Postimages

The authenticated helper uploaded a synthetic PNG and returned a direct
`i.postimg.cc` URL. An independent retrieval confirmed HTTP image content with
`image/png` and a PNG signature. The source was **600 × 900**, while the hosted
image was **512 × 768**. The helper also reported that reduction.

Uploading successfully does not preserve native dimensions or establish cover
adequacy. The hosted result falls below the operator's 600 × 900 portrait-cover
quality target and can still be used as a smaller cover. Verify returned image
properties after every upload; source
properties cannot satisfy a hosted-image check. No larger re-upload was made,
and no selected ebook cover was hosted. The synthetic URL and image hashes
remain in the private evidence inventory.

The [2026-11-08 policy review](c411-ebook-policy.md) found no numerical site cover
minimum in the reviewed pages. The complete image-host allowlist and C411
acceptance of a Postimages URL remain unverified; the HTML policy's examples
are non-exhaustive.

## OpenAI

A probe used the existing Windmill OpenAI resource, without copying its key
into the repository or arguments. The first snapshot requested,
`gpt-4.1-nano-2025-04-14`, returned HTTP 404 with `model_not_found`. A read of
the accessible model catalog then identified
`gpt-4.1-mini-2025-04-14` as an available compatible model.

The successful Responses API request used `text.format` with a strict JSON
schema, explicit required fields, `additionalProperties: false`, a nullable
title, and an enum restricting evidence identifiers to the supplied synthetic
identifier. It returned HTTP 200, the requested model snapshot, and valid
fields and evidence identifiers. The request specified `store: false` and
provided no tools. Usage was 108 input tokens and 18 output tokens.

A second request deliberately omitted `additionalProperties`; the API rejected
that strict schema with HTTP 400 and `invalid_json_schema`. This verifies the
tested transport and schema capability. It does not certify factual accuracy,
the application prompts, provider defaults, or production evidence handling.
The resource still requires a deliberate application connection assignment.

References: [Responses structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses)
and [the tested model family](https://developers.openai.com/api/docs/models/gpt-4.1-mini).

## Linux tool selection

The [synthetic container check](../script/tooling/README.md) ran successfully
on Linux x86-64 using a digest-pinned Debian Bookworm base. The container ran
as UID/GID 65534 with no network, host mounts, or writable root filesystem.

| Purpose | Verified tool/package version |
| --- | --- |
| EPUB/MOBI metadata and extracted text | Calibre `6.13.0+repack-2+deb12u10` |
| PDF metadata, text, and page rendering | Poppler utilities `22.12.0-2+deb12u3` |
| OCR to a text sidecar | Tesseract `5.3.0-2`, French data `1:4.1.0-2` |
| Private torrent creation | mktorrent `1.1-3` |
| Synthetic fixtures and independent hash verification | Python `3.11.2-1+b1`, Pillow `9.4.0-1.1+deb12u1`, ReportLab `3.6.12-1+deb12u1` |

The probe confirmed EPUB and MOBI metadata/text extraction, PDF metadata/text,
French OCR of an image-only PDF, rejection of a corrupt PDF, unchanged source
hashes, a private single-file torrent with the exact name and size, and every
piece hash. Flipping one payload byte produced a hash mismatch.

Calibre returned exit code **0** for a corrupt MOBI fixture. That fixture also
lacked the required `BOOKMOBI` signature. Treat metadata output as evidence and
perform independent signature/structure checks; a successful command alone is
not certification. Analysis sidecars must remain outside torrent contents.

These tools are compatible candidates for the application image. The final
application image, dependencies, parser bounds, encrypted inputs, hostile
archives, and real-file acceptance still require their own verification.

References: [Calibre metadata CLI](https://manual.calibre-ebook.com/generated/en/ebook-meta.html)
and [Tesseract CLI](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html).

## Existing deployment storage observation

A read-only probe in the existing `george-basics` Windmill worker found its
torrent-inbox mount but no `/data/completed` or `/data/completed/uploads`.
The worker ran as root; its successful access cannot establish permissions for
an unprivileged application or Deluge daemon. No file was created, modified,
renamed, or moved by that probe.

That observation does not define application paths or require George access for
portable development checks. Host binds, application roots, and client roots
are [deployment configuration](storage-configuration.md). The selected host's
actual mounts, service permissions, RPC behavior, and intended network
interfaces remain deployment acceptance checks. The existing torrent inbox is
not proof of canonical payload access.

The application now uses the verified Trixie runtime recorded in
[supported runtime](runtime.md). Its CI repeats the synthetic tooling checks;
the dated standalone Bookworm observations above remain historical evidence.
