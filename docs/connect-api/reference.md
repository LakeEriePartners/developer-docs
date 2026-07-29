---
title: Connect API Reference
sidebar_label: Endpoint reference
---

# Endpoint reference

Base URL: `https://app.tpastream.com/connect/v1`

Every request needs the headers described in
[Authentication](/connect-api/authentication#headers). Every request
except `POST /tpastream_sdk` must also
[identify the member](/connect-api/authentication#identifying-the-member).

All successful responses are wrapped in a `data` envelope:

```json
{ "data": { } }
```

## Endpoints at a glance

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/tpastream_sdk` | Bootstrap the member; list carriers |
| `GET` | `/payer/{employer_id}/{payer_id}` | Carrier detail and credential schema |
| `GET` | `/terms_of_service` | Current terms of use HTML |
| `POST` | `/policy_holder_sdk/policy_holder` | Submit credentials, start validation |
| `PUT` | `/policy_holder_sdk/policy_holder/{id}` | Resubmit credentials for an existing connection |
| `GET` | `/policy_holder_sdk/policy_holder/{id}` | Connection status |
| `GET` | `/validate-credentials/{ph_id}/{task_id}` | Validation state |
| `PUT` | `/validate-credentials/{ph_id}/{task_id}` | Supply an MFA method or code |
| `GET` | `/fix-credentials` | All of the member's connections |
| `GET` `POST` | `/interop` | Patient Access API (OAuth carriers) |

---

## POST /tpastream_sdk

Creates or resolves the member, attaches them to the employer, and
returns the carriers available to them. The only endpoint that may
reference a member who does not exist yet.

**Body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `system_key` | string | Yes | Your identifier for the employer. |
| `vendor` | string | Yes | Your vendor label. |
| `employer_name` | string | Yes | Display name; used if the employer is being created. |
| `user_email` | string | Yes | The member's email. Becomes their identity for every later call. |
| `user_first_name` | string | Yes | |
| `user_last_name` | string | Yes | |
| `date_of_birth` | string | No | `YYYY-MM-DD`. |
| `phone_number` | string | No | |
| `member_system_key` | string | No | Your identifier for the member. |

**Response** — `data.user`, `data.employer`, `data.tenant`,
`data.payers` (array of `{id, name, logo_url}`).

Safe to call repeatedly for the same member; it resolves rather than
duplicating.

---

## GET /payer/\{employer_id\}/\{payer_id\}

Carrier detail, including the schema for its credential form.

**Query** — `email` (required), `referer` (optional, free-form
attribution string).

**Response**

| Field | Notes |
|---|---|
| `id`, `name`, `logo_url` | Display basics. |
| `onboard_form` | JSON Schema for the carrier's credential fields. |
| `onboard_ui_schema` | Presentation hints for those fields. |
| `has_security_questions` | Whether the carrier may ask security questions. |
| `supports_interoperability_apis` | `true` means OAuth redirect, not credentials. See [Patient Access API](#patient-access-api). |
| `register_url` | Where a member with no carrier account should sign up. |
| `website_home_url_netloc` | The carrier's portal host, for display. |
| `redirect_vendor_name` | Set when the carrier authenticates through a third party. |
| `blogs` | Optional help articles: `id`, `title`, `article`. |

Drive your form from `onboard_form` rather than hard-coding per-carrier
fields, so carrier changes don't require a deploy.

---

## GET /terms_of_service

**Query** — `email` (required).

**Response** — `data.html_string`, the current terms of use as HTML.

Fetch and render this rather than reproducing the text. The member's
acceptance is recorded through `accept` and `tenants_accept` on the
credential submit.

---

## POST /policy_holder_sdk/policy_holder

Submits credentials, creates the connection, and dispatches a validation
against the carrier.

**Body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `user_email` | string | Yes | Identifies the member. May be supplied as `user.email` instead. |
| `employer_id` | integer | Yes | From the bootstrap response. |
| `payer_id` | integer | Yes | May also be supplied as `payer.id`. |
| `username` | string | Usually | Whatever the carrier calls it. |
| `password` | string | Usually | |
| `date_of_birth` | string | Carrier-dependent | `YYYY-MM-DD`, or `null`. |
| `member_id` | integer | No | Attach to a specific member record. |
| `accept` | boolean | Yes | Member accepted the terms of use. Falsy returns `403`. |
| `tenants_accept` | array | Yes | Non-empty array of tenant ids the member consented to. A string is rejected. |

Any additional fields declared by the carrier's `onboard_form` go at the
top level of the same object. They are validated against that schema;
failures return `422` with per-field detail.

**Response**

| Field | Notes |
|---|---|
| `policy_holder_id` | The connection. Persist this. |
| `task_id` | The running validation. Poll it. |
| `task_token` | Only needed for the [event stream](/connect-api/two-factor#watching-progress-server-sent-events). |

---

## PUT /policy_holder_sdk/policy_holder/\{policy_holder_id\}

Identical body and response to the `POST`. Use when the member is fixing
credentials on a connection that already exists rather than making a new
one.

Changing `username` to one already used by another connection at the same
carrier returns `403`.

---

## GET /policy_holder_sdk/policy_holder/\{policy_holder_id\}

**Query** — `email` (required), `employer_id` (required).

**Response**

| Field | Notes |
|---|---|
| `policy_holder_id`, `uuid` | Identifiers. |
| `payer_id` | The carrier. |
| `login_problem` | `null` when healthy; otherwise names the issue. |
| `login_needs_correction` | `true` when the member must act. |
| `login_correction_message` | What to tell them. |
| `last_successful_crawl_end` | Timestamp of the last successful data pull, or `null`. |
| `claims_synced_count` | Claims retrieved so far. |
| `most_recent_claim_date` | Date of the newest claim. |
| `members` | `id`, `first_name`, `last_name`. |

Note that `login_problem` and its siblings read as `null` while a
validation is still running. Do not interpret an all-null response
mid-validation as success — drive off the validation task instead.

---

## GET /validate-credentials/\{policy_holder_id\}/\{task_id\} {#get-validate-credentials}

Point-in-time validation state — the polling alternative to the
[event stream](#event-stream). See
[Multi-factor authentication](/connect-api/two-factor) for the full state
machine.

**Query** — `email` (required).

**Response**

| Field | Notes |
|---|---|
| `id` | The task id. |
| `state` | See the [state table](/connect-api/two-factor#the-state-machine). |
| `info` | Present on MFA states. Carries `method_list` on `WAITING_FOR_METHOD_CHOICE`. |
| `credentials_are_valid` | On terminal states. `true` means the carrier accepted the login. |
| `pending` | `true` means no verdict yet and we will keep trying. |
| `message` | Member-safe explanation on failures and code rejections. |

`message` is always safe to show a member. Internal error detail is never
returned here.

---

## PUT /validate-credentials/\{policy_holder_id\}/\{task_id\}

Supplies one piece of MFA input. Send exactly one of `method` or `code`
per call.

**Body**

| Field | Type | Notes |
|---|---|---|
| `user_email` | string | Required. |
| `method` | string | The exact string from `info.method_list`. |
| `code` | string | The one-time code the member received. |

Keep watching the state after each call; this endpoint acknowledges the
input rather than reporting the outcome.

---

## Event stream {#event-stream}

```
GET https://app.tpastream.com/v3/sdk/progress/{task_id}/stream?token={task_token}
```

Server-sent events for one validation task. Note the base URL: this
endpoint lives under `/v3/sdk`, not under the Connect API prefix, and
authenticates with the `task_token` from the credential submit instead
of the usual headers.

Events: `state` (task status + stage data), `ping` (heartbeat,
~15s), `timeout` (per-connection ~10-minute cap reached — re-fetch the
policy holder for a fresh `task_token` and resubscribe). The stream
closes itself after a terminal state. A subscribe attempt that returns
`401` `Task not available` means the validation already finished; read
the result via the GET above.

Full usage, including the reattach loop:
[Multi-factor authentication](/connect-api/two-factor#watching-progress-server-sent-events).

## GET /fix-credentials

Every connection belonging to the member, with current status. This is
what a "manage my carriers" screen is built from.

**Query** — `email` (required).
**Headers** — requires
[`X-Connect-Access-Token`](/connect-api/authentication#your-two-keys).

**Response** — `data.user` with the member's policy holders and their
status fields.

---

## Patient Access API

Carriers with `supports_interoperability_apis: true` authenticate through
their own OAuth flow instead of accepting credentials. The member signs
in on the carrier's website and is redirected back to your application.

**This step requires a browser.** There is no server-to-server
equivalent, because the member authenticates directly with the carrier.

Both endpoints require the `X-SDK-State-Id` header — an opaque string you
generate per member session and reuse across the flow.

### POST /interop

**Body** — `user_email` (required).

Begins the flow and returns the carrier authorization URL to send the
member to.

### GET /interop

**Query** — `email` (required).

Reports where the flow stands. Returns `status`, plus `ph_id` once a
connection exists, or `error` if it failed.

### The redirect back

The carrier returns the member to your application with query
parameters, notably `accessToken`. Strip these from the URL once read —
leaving them in browser history is unnecessary exposure.

Poll `GET /interop` after the redirect until `status` reports the
connection is established, then treat `ph_id` like any other
`policy_holder_id`.

---

## Response headers worth reading

| Header | Notes |
|---|---|
| `X-Request-Id` | Log this. It is how we find your request in our logs. |
| `X-Set-Connect-Access-Token` | A rolling replacement connect access token. Use it on subsequent requests instead of re-minting. |
