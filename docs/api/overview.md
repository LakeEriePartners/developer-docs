---
title: REST API
sidebar_label: Overview
---

# REST API

The canonical inventory of every endpoint TPA Stream exposes — full
URLs, parameters, request and response shapes, and a try-it-out
console — lives in the [API Reference](/api-reference/tpa-stream-api).
It is generated at build time from the OpenAPI spec served live at
[`https://app.tpastream.com/openapi.json`](https://app.tpastream.com/openapi.json).
The pages in this section cover the cross-cutting concerns that
apply to every endpoint: authentication, pagination, IP allowlists,
key generation, and how a couple of distinctive field types
(date ranges, etc.) are serialized.

All requests must use HTTPS.

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
