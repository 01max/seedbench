# Provider settings

Sign in and open **Réglages** to configure C411, Deluge, OpenAI, and Postimages.
Only these implementations are offered. Creating a connection saves local
configuration; a separate **Tester** action performs its bounded connection
check. Settings never publishes, changes torrent options, starts a torrent,
generates AI output, or uploads an image.

Each connection has an immutable role/provider, address, and account or daemon
identity. Use a descriptive label and a stable identity that identifies the
actual account/project. For Deluge, the identity is the configured daemon's
host ID from the WebUI. The Deluge address is its HTTP(S) WebUI root, including
an optional reverse-proxy prefix, without `/json`, credentials, or query
parameters. Other providers use their official addresses.

Connections retained from earlier versions may have only their identity and
label. Use **Compléter la configuration** on the existing connection to save its
secret, required model, and missing Deluge address together. Confirm that these
details belong to the recorded identity. Fixed providers receive their official
address. This keeps connection IDs, release assignments, and history intact;
once recorded, an address cannot be changed or cleared. Connection checks report
incomplete configuration until setup succeeds, and stale completion forms are
rejected.

The four checks report their actual scope:

| Provider | Checked | Still unverified by this action |
| --- | --- | --- |
| C411 | Bearer-key access to `GET /api/user/drafts` and its response envelope | Publication, personalized torrent retrieval, submission state |
| Deluge | Web password login, configured daemon presence, connection, connected state | Payload mapping, torrent operations, recheck, tracker/seeding outcome |
| OpenAI | Read access to the exact configured model using `GET /v1/models/{model}` | Generation, structured outputs, project identity, factual accuracy |
| Postimages | Public service-page reachability | API key validity, upload, hosted image properties |

Postimages credentials use the account upload key, not an anonymous fallback.
Its check has a visibly limited status because no read-only credential test is
established. Uploading an image belongs to an explicit image-hosting workflow.
C411 HTTP 403 can indicate scope or upstream filtering; it is not automatically
classified as an invalid key. Raw provider bodies and exceptions are never
rendered or stored as diagnostic messages. HTTP redirects are refused, TLS
verification remains enabled, and responses/timeouts are bounded. Deluge uses
a fresh session cookie for each check and does not save that cookie.
The OpenAI model identifier can be changed on the same connection without
changing account identity; saving it invalidates the previous access check.

The **Choix pour les prochains livres** form controls default connection IDs and
the Automatic AI first pass flag, which starts enabled. Each new release
captures all four role assignments, including explicitly unconfigured roles,
and its own AI choice in the same transaction. Changing defaults does not
retarget an existing release or launch/cancel its work.

Use a release's connections page (`/releases/ID/connections`) to assign a
previously unconfigured role deliberately. Assignment records history and
advances the input revision. An existing assigned identity is retained;
credential rotation is performed on that same connection. Stale forms cannot
overwrite newer defaults or release assignments. Local/manual work remains
available with unconfigured roles.

Credentials are encrypted with Active Record Encryption and rendered as a
constant mask. Request parameters filter passwords, keys, tokens, and credential
objects. A secret rotation requires confirming that it belongs to the same
account/daemon; addresses and identities cannot be edited in place. C411 and
OpenAI checks do not prove account identity, so this declaration remains the
operator's responsibility. For a different account or endpoint, create a new
connection and assign it deliberately. A stale rotation or a check that finishes
after rotation is rejected; old check results do not certify new credentials.

The container entry point supplies the encryption key. By default it creates
`provider_encryption_key` with mode 0600 in the configured state root and shares
it through the existing state mount. Alternatively, provide
`SEEDBENCH_ENCRYPTION_KEY` as 64 hexadecimal characters through the deployment's
environment/secret management. Web, worker, and recovery commands must receive
the same key. No production key is baked into the image or test configuration.
Keep the original key and protected recovery material with backups; replacing
or losing it makes existing credentials unreadable. Do not change the key as a
way to rotate provider credentials; use the Settings rotation action.

References: [Rails encryption](https://guides.rubyonrails.org/active_record_encryption.html),
[recorded C411 contract](c411-api.md),
[Deluge Web API](https://deluge.readthedocs.io/en/deluge-2.2.0/reference/webapi.html),
and [OpenAI model retrieval](https://developers.openai.com/api/reference/resources/models/methods/retrieve).
