---
title: REST API
sidebar_label: Overview
---

# REST API

TPA Stream exposes a REST API rooted at
[`https://app.tpastream.com/api`](https://app.tpastream.com/api). All
requests must use HTTPS.

For the per-endpoint reference (request/response shape, parameters,
try-it-out), see the [API Reference](/api-reference/tpa-stream-api), which is
generated from the canonical OpenAPI spec at build time.

## Authentication at a glance

The REST API supports **two** authentication methods:

| Method | Status | Performance | Notes |
|---|---|---|---|
| **SSH-JWT** | Recommended | Fast | Modern, key-based authentication |
| **API Token (Basic Auth)** | Deprecated | Slower | Supported for backwards compatibility |

See [Authentication](/api/authentication) for the setup walkthrough
and the troubleshooting table.

## Companion pages

- [Authentication](/api/authentication) — set up SSH-JWT, sign your
  first request, troubleshoot common 4xx responses.
- [Pagination](/api/pagination) — the envelope shape and how to walk
  through pages.
- [Security](/api/security) — IP allowlists.
- [Generating an SSH Key](/api/ssh-keys) — copy-paste-able commands
  for Ed25519, RSA, and ECDSA.
- [Generating a GPG Key](/api/gpg-keys) — for signed deliverables.
- [A Note About Date Ranges](/api/date-ranges) — how range-typed
  fields like `date_of_service` are serialized.
