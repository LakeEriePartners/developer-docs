---
title: Authentication
sidebar_label: Authentication
---

# Authentication

## SSH-JWT (preferred)

SSH-JWT is the **modern and preferred** way to authenticate with the
TPA Stream API.

### 1. Generate an SSH keypair

Run one of the following in your terminal (Linux, macOS, or Git Bash
on Windows):

```bash
ssh-keygen -t ed25519              # recommended for new keys
ssh-keygen -t rsa -b 4096          # broadly compatible
ssh-keygen -t ecdsa -b 521         # NIST P-521
```

- When prompted for a file path, press Enter to accept the default.
- You may optionally set a passphrase.

See [Generating an SSH Key](/api/ssh-keys) for the full prompt
walk-through.

### 2. Add your public key to your TPA Stream account

Visit your account settings at:

```
https://app.tpastream.com/settings/ssh
```

Paste the contents of your **public key file** (for example,
`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`).

You can upload **multiple keys** to the same account. The server tries
each one in turn during verification, so this is the right way to
rotate: upload the new key, leave the old one live until every client
has switched, then delete the old key.

### 3. Sign a JWT with your private key

The JWT must be:

- Signed with the **private key** whose public half you uploaded in
  step 2.
- Carry exactly these three claims: `email`, `iat`, `exp`.
- Use the algorithm matching your key type:

| Key type | JWT `alg` |
|---|---|
| RSA | `RS256` |
| Ed25519 | `EdDSA` |
| ECDSA P-256 | `ES256` |
| ECDSA P-384 | `ES384` |
| ECDSA P-521 | `ES512` |

`email` must match the email on your TPA Stream account
(case-insensitive). `iat` and `exp` are seconds since the Unix epoch;
a short TTL (15 minutes is plenty) is recommended. The server uses
**no clock-skew tolerance**, so a host with a drifted clock will see
tokens rejected as expired or "not yet valid" even when the TTL looks
right. Run NTP, and prefer building a fresh token per request over
caching one for hours.

You can reuse the same signed token across as many requests as you
like until `exp` lapses; each request stamps `last_accessed` on the
matching key but does not consume the token.

Minimum working example in Python (`pyjwt` + `cryptography`):

```python
import time
import jwt
from cryptography.hazmat.primitives import serialization

with open("/path/to/id_ed25519", "rb") as fh:
    private_key = serialization.load_ssh_private_key(
        fh.read(), password=None
    )

now = int(time.time())
token = jwt.encode(
    {
        "email": "you@example.com",
        "iat": now,
        "exp": now + 900,  # 15 minutes
    },
    private_key,
    algorithm="EdDSA",  # RS256 for RSA, ES256/ES384/ES512 for ECDSA P-256/P-384/P-521
)
```

The `serialization.load_ssh_private_key` step handles keys generated
by modern `ssh-keygen`, which writes the OpenSSH
`-----BEGIN OPENSSH PRIVATE KEY-----` format that PyJWT cannot parse
directly. If your file already starts with `-----BEGIN PRIVATE KEY-----`
or `-----BEGIN RSA PRIVATE KEY-----` (PEM), you can pass
`open(...).read()` straight to `jwt.encode` and skip the load step.
To convert in place: `ssh-keygen -p -m PEM -f ~/.ssh/id_rsa`.

A reference implementation that autodetects the algorithm from the
key type lives at
[scripts/crawl/client.py:make_ssh_jwt](https://github.com/LakeEriePartners/stream/blob/master/scripts/crawl/client.py)
in the stream repo.

### 4. Make an authenticated API request

Include the signed token in the `Authorization` header. The scheme
**must** be `SSH-JWT` (case-insensitive), not the `Bearer` that most
JWT tooling defaults to. Sending `Authorization: Bearer <jwt>` falls
through to the legacy API-key parser and authentication fails.

```bash
curl -L \
  -H "Authorization: SSH-JWT <your_signed_jwt>" \
  https://app.tpastream.com/api/claims
```

The server verifies the signature against your registered public key.

### 5. Optional IP allowlist

For an additional layer of security, each user can specify an **IP
CIDR allowlist** (for example, `10.0.0.0/8`). Requests originating
outside this range are rejected. See [Security](/api/security).

## Common authentication mistakes

If your request returns a 4xx, the response body's `message` field
will tell you what's wrong. The most frequent causes:

- **400 — JWT could not be decoded**: the token is malformed (bad
  base64, wrong number of segments, not actually a JWT). Re-encode
  with a known-good library.
- **400 — JWT missing required claim(s)**: at least one of `email`,
  `iat`, or `exp` is absent from the payload. All three are required.
- **401 — JWT could not be verified**: covers two cases on purpose.
  Either the token's signature didn't match any uploaded public key
  for that email, or the email isn't on file at all. The server
  returns the same response for both to keep unauthenticated clients
  from probing which emails have keys uploaded by watching the
  response shape. Confirm the email matches your account exactly and
  you are signing with the private key whose public half you uploaded
  in step 2.
- **401 — JWT has expired**: `exp` is in the past relative to server
  time. If your laptop clock is drifted this can fire even on freshly
  minted tokens, so check NTP before chasing token generation.
- **403** with no descriptive body: authentication succeeded but the
  request hit an IP outside your allowlist (if you configured one),
  or the user lacks permission for the endpoint.
- **Wrong algorithm**: the JWT `alg` header must match the key type
  you uploaded (see the table above). For example, an Ed25519 key
  paired with `RS256` will be rejected as `400 — JWT 'alg' header is
  'RS256'`.
- **DSA keys / unusual ECDSA curves**: TPA Stream accepts RSA,
  Ed25519, and ECDSA on the NIST P-256, P-384, and P-521 curves. DSA
  keys and ECDSA on other curves (e.g. `secp256k1`) are rejected at
  upload time. If you generated a DSA key, regenerate with one of the
  supported types (`ssh-keygen -t ed25519` is the modern default).

## API tokens (legacy)

API tokens (HTTP Basic Auth) are still supported for older
integrations but are **deprecated**. We recommend migrating to
SSH-JWT for improved performance and security.

To use Basic authentication:

```bash
curl -L --user me@example.com:MY_API_KEY https://app.tpastream.com/api/claims
```

You may also send the same credentials base64-encoded in the
`Authorization` header:

```bash
curl -L \
  -H "Authorization: Basic $(echo -n 'me@example.com:MY_API_KEY' | base64)" \
  https://app.tpastream.com/api/claims
```

Notes:

- Basic Auth requests will be rejected if the originating IP address
  is not in the user's allowlist.
- You can manage allowed IP ranges on the
  [Manage Users](https://app.tpastream.com/settings/users) page.
