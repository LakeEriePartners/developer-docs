---
title: Webhook Security
sidebar_label: Webhook Security
---

# Webhook Security

## Response codes and retries

For webhook POSTs, TPA Stream listens for the following codes from
your server and reacts accordingly:

| Code | Behavior |
|---|---|
| `200` / `2xx` | TPA Stream marks the POST successful. No retry. |
| `406` (Not Acceptable) | TPA Stream marks the POST consciously rejected. No retry. |
| Any other code | TPA Stream retries with exponential backoff for up to 4 hours. |

The `406` semantics are a TPA Stream convention rather than a strict
reading of RFC 7231. Use it when your endpoint received the post but
deliberately chose to drop it (deduplication, business-rule mismatch,
etc.) and you don't want TPA Stream to keep retrying.

## TPAStream-Signature verification

Every webhook request includes a JWT signature in the
`TPAStream-Signature` header. Use it to verify the request originated
from TPA Stream and not some other party.

The signature can be verified using TPA Stream's SSH RSA public key,
fetched from:

```
https://app.tpastream.com/keys
```

The JWT hashing algorithm is `RS256`.

We **strongly recommend** verifying the signature on every webhook
endpoint you wire up. Decoding examples in most languages live at
[jwt.io](https://jwt.io). The library you choose must support
`RS256` (nearly all do) and should also support an `exp` check
(though you can also do that yourself with a UTC timestamp).
