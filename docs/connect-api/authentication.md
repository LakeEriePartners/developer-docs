---
title: Connect API Authentication
sidebar_label: Authentication
---

# Authentication

The Connect API authenticates on two axes at once, and you need both on
almost every request:

1. **Which integration is calling** — your Connect token, in a header.
2. **Which member the call is about** — the member's email address, in
   the query string or the request body.

There is no session, no cookie, and no login step. Every request carries
everything it needs.

## Base URL

```
https://app.tpastream.com/connect/v1
```

All requests must use HTTPS.

:::note Legacy path
`https://app.tpastream.com/sdk-api` serves the identical surface and
remains supported indefinitely — it is what the JavaScript SDK uses.
The SDK-era route spellings (`/bootstrap` was `/tpastream_sdk`,
`/policy_holder` was `/policy_holder_sdk/policy_holder`, and
`X-Connect-State-Id` was `X-SDK-State-Id`) likewise remain valid
aliases. New integrations should use `/connect/v1` and the names in
these pages — that is the contract covered by the
[stability commitment](/connect-api/overview#stability).
:::

## Headers

| Header | Required | Value |
|---|---|---|
| `X-TPAStream-Token` | Yes | Your Connect token (the public one). |
| `X-Connect-API-Version` | Yes | `1`. |
| `Content-Type` | On writes | `application/json`. |
| `X-Connect-Access-Token` | Conditional | A short-lived JWT minted from your secret key. Required for [`GET /fix-credentials`](/connect-api/reference#get-fix-credentials); optional but recommended elsewhere. |
| `X-Tenant-Label` / `X-Tenant-Key` | Conditional | Your vendor label and tenant system key. Required if your token spans multiple tenants. |
| `X-Connect-State-Id` | Conditional | An opaque string you generate per member session. Required only on the [Patient Access API](/connect-api/reference#patient-access-api) endpoints. |
| `X-Is-Demo` | No | `1` to run against sandbox data. Omit or send `0` in production. |

A minimal authenticated request:

```bash
curl https://app.tpastream.com/connect/v1/terms_of_service \
  -H "X-TPAStream-Token: $TPA_CONNECT_TOKEN" \
  -H "X-Connect-API-Version: 1" \
  --data-urlencode "email=member@example.com" -G
```

## Identifying the member

Every endpoint except the initial
[`POST /bootstrap`](/connect-api/reference#post-bootstrap)
must say which member the request concerns. Omitting it returns
`403 Forbidden` with `Cannot provide empty user outside of initial post`.

How you pass it depends on the verb:

| Verb | Where the email goes |
|---|---|
| `GET` | `?email=member@example.com` |
| `POST` / `PUT` | `user_email` at the top level of the JSON body, or `user.email` in a nested `user` object |

The email must match a member your token has already bootstrapped via
`POST /bootstrap`. That call is the only one that may reference a
member who doesn't exist yet — it creates them.

## Your two keys

If your integration uses the connect-access-token security model, you
were issued two keys:

- A **public token**. This is the `X-TPAStream-Token` value. It is not a
  secret; the SDK ships it to browsers.
- A **secret key**. This never leaves your infrastructure.

The secret key mints short-lived access tokens:

```bash
curl -X POST https://app.tpastream.com/api/create-connect-token \
  -H "Content-Type: application/json" \
  -d '{
    "connect_access_key": "'"$TPA_CONNECT_TOKEN"'",
    "connect_secret_key": "'"$TPA_CONNECT_SECRET"'"
  }'
```

```json
{ "data": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

Pass the result as `X-Connect-Access-Token`. It expires after one hour.

Responses carry a rolling replacement in the
`X-Set-Connect-Access-Token` response header — read it and use it on
subsequent requests to avoid re-minting. If you let one expire, the next
call fails with `422` and `"error_code": "expired_connect_token"`; mint a
new one and retry.

:::tip Server-side simplification
The one-hour expiry and the rolling refresh exist so a browser can hold a
usable credential without ever seeing your secret key. On a server that
constraint doesn't apply. Minting a token per member session, or on
demand when you see `expired_connect_token`, is simpler than tracking
expiry and costs one extra request.
:::

## Do not share an HTTP client cookie jar

This is the single most important operational detail on this page.

The Connect API establishes a request-scoped identity for the member
named in each request. Responses may set a session cookie as a byproduct.
If your backend serves many members through one HTTP client with a
**shared cookie jar**, a cookie set while handling member A can ride
along on a request about member B.

Configure your HTTP client to **discard cookies entirely**. Every request
is independently authenticated by the headers and the member email, so
there is nothing a cookie needs to carry.

```python
# Python — requests
import requests

session = requests.Session()
session.cookies.set_policy(_BlockAll())  # or build a fresh request each time
```

```javascript
// Node — undici / fetch: do not attach a CookieJar.
// axios: set withCredentials: false (the default) and do not
// install axios-cookiejar-support on this client.
```

If you are using an HTTP client that persists cookies by default, treat
disabling that as a launch blocker, not a cleanup task.

## Rate limits

There are no per-token rate limits on the Connect API today. That is not
an invitation to hammer the API — prefer the
[event stream](/connect-api/two-factor#watching-progress-server-sent-events)
for watching validations, and keep any polling to a few-second cadence.
We will publish limits before enforcing them.

## Error responses

Errors return a JSON body with a `message`, and sometimes a stable
`error_code` you can branch on.

| Status | Meaning |
|---|---|
| `400` | Malformed request, or a required header is missing. |
| `401` | The token is inactive. Contact TPA Stream. |
| `403` | Authenticated, but not permitted — most commonly a missing or unrecognized member email, or terms of use not accepted. |
| `404` | No such record, or a malformed path parameter. |
| `422` | Validation failed, or the connect access token is missing/expired. Check `error_code`. |
| `500` | Our problem. Retry with backoff; if it persists, contact support with the `X-Request-Id` response header. |

Always log the `X-Request-Id` response header. It is the fastest way for
us to find your request in our logs.
