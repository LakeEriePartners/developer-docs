---
title: Origin Policy
sidebar_label: Origin Policy
---

# Origin Policy

The Connect SDK transmits health-plan member credentials between the
host page and `app.tpastream.com`. Those bytes must travel encrypted.
Two reinforcing checks enforce that:

1. **Browser-side**, at `StreamConnect()` init time, the SDK refuses to
   mount if the host page is not a [secure context][secure-context].
2. **Server-side**, `app.tpastream.com` refuses to send the CORS
   `Access-Control-Allow-Origin` header for `/sdk-api/*` and
   `/patientaccessapi/*` requests originating from a non-allowed
   scheme.

Both layers allow the same set of origins:

| Scheme | Host pattern | Allowed | Notes |
|---|---|---|---|
| `https://` | any | ✅ | Production use |
| `http://` | `localhost` (any port) | ✅ | Local development |
| `http://` | `127.0.0.1` (any port) | ✅ | Local development |
| `http://` | `[::1]` (any port) | ✅ | Local development (IPv6 loopback) |
| `http://` | anything else | ❌ | Including staging, internal hostnames |
| `file://` | — | ❌ | |
| Any other scheme | — | ❌ | |

## What you'll see if the policy blocks your page

### Browser console (SDK init)

```text
[stream-connect-sdk] init failed: host page must be served over HTTPS
(or from http://localhost, http://127.0.0.1, or http://[::1] for local
development). The current page origin http://staging.example.com is
insecure, and the SDK transmits member credentials — sending those
over plain HTTP would expose them in transit. See
https://developers.tpastream.com/connect/origin-policy for the fix.
```

If you wired the optional `handleInitErrors` callback in your
`StreamConnect({ … })` call, the same message is also delivered to
that callback as an `Error` so your monitoring picks it up.

### Browser network tab (server-side enforcement, fallback)

If you somehow reach the network — older SDK versions, a non-SDK
client — the request to `/sdk-api/*` completes, but the response is
missing the `Access-Control-Allow-Origin` header, and the browser
blocks the JavaScript from reading the body. The console shows a
generic CORS error:

```text
Access to fetch at 'https://app.tpastream.com/sdk-api/tpastream_sdk'
from origin 'http://staging.example.com' has been blocked by CORS
policy: No 'Access-Control-Allow-Origin' header is present on the
requested resource.
```

The SDK's init-time guard is intended to fire first so you don't have
to deduce the cause from this message.

## How to fix it

For **production**:

* Serve the host page over `https://`. Almost every hosting platform
  (Vercel, Netlify, Cloudflare Pages, CloudFront + ACM, an nginx +
  Let's Encrypt deployment) provides a free TLS certificate for your
  domain. If you're loading the host page in an iframe inside another
  product, the host product must itself be HTTPS — the SDK can't
  upgrade the parent context.

For **local development**:

* `vite dev`, `webpack-dev-server`, `next dev`, `create-react-app`,
  `npm run dev` for most frameworks, etc. all default to
  `http://localhost:<port>`. That's already allowed — no config
  change needed.
* If your dev server binds to a LAN hostname like
  `http://my-machine.local:3000` or your office's hostname, that
  fails the loopback check. Either bind to `localhost`/`127.0.0.1`,
  or run a local TLS proxy (Caddy, `mkcert` + a tiny nginx) in front
  of the dev server.

## Related

* [SDK Quickstart](/docs/connect/quickstart) — the smallest possible
  page that mounts the SDK.
* [Stream Connect SDK changelog][changelog] — `0.8.2` is the first
  release that includes the init-time guard.

[secure-context]: https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts
[changelog]: https://github.com/TPAStream/stream-connect-js-sdk/blob/master/CHANGELOG.md
