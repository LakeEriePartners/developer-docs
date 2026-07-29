---
title: Connect API
sidebar_label: Overview
---

# Connect API

The Connect API is the HTTP contract underneath the
[Connect SDK](/connect/overview) — the same endpoints the SDK drives,
documented directly for integrations that need to run the
carrier-connection flow from their own code.

**The SDK is the recommended integration.** It ships the entire flow —
carrier picker, credential forms, MFA prompts, progress handling, error
states — as a drop-in, and it is where our integration effort goes. The
Connect API is the engine without the car: you build the UI, the MFA
prompt plumbing, the state machine, the reattach logic, and the error
handling yourself, against the contract documented here.

## Should you use this?

Probably not. Most integrations are better served by the SDK, and if
your concern is visual control, [headless mode](/sdk/headless) gets you
fully custom UI while we keep the state machine — far less work than
this. The Connect API exists for the narrow case where the SDK
genuinely cannot fit: the flow has to run from your own code and
embedding our JavaScript is off the table. If you think that's you,
talk to us before you build — we'll help you scope what you're
taking on.

## What the flow looks like

```
 1. POST /bootstrap                        create or resolve the member, get carriers
 2. GET  /payer/{employer}/{payer}         get the carrier's credential form
 3. POST /policy_holder  submit credentials, get a task
 4. GET  /v3/connect/progress/{task}/stream    watch progress (SSE — separate base URL, see below)
      └─ if multi-factor is required:
         PUT /validate-credentials/{ph}/{task}  {method}
         PUT /validate-credentials/{ph}/{task}  {code}
 5. GET  /policy_holder/{ph}  confirm final state
```

Steps 1–3 and 5 are relative to the base URL
(`https://app.tpastream.com/connect/v1`). Step 4 is the one deliberate
exception: the progress stream is served by a different backend at
`https://app.tpastream.com/v3/connect/...` and authenticates with the
per-task `task_token` instead of the usual headers — details in the
[reference](/connect-api/reference#event-stream). A plain polling GET
under the normal base URL works as an alternative.

Steps 3 and 4 are the interesting part and are covered in detail in
[Multi-factor authentication](/connect-api/two-factor).

Start with the [Quickstart](/connect-api/quickstart) for a working
end-to-end walkthrough, or the
[Endpoint reference](/connect-api/reference) if you already know the
shape you want.

## Two things you cannot move to your backend

Be aware of these before you plan the integration. Neither is a
limitation of the API; both are properties of how carriers work.

### 1. Multi-factor authentication needs a live member

Roughly a third of credential submissions across our customer base end
up challenged by the carrier for a one-time code. When that happens the
carrier is holding an authenticated session open and waiting. Your
backend can own that session and drive it, but a real person still has to
read a code off their phone and give it to you — the validation allows
about five minutes per prompt before giving up.

Practically, that means your front end needs a way to prompt the member
and hand the code back to your server. It does not mean you need our UI —
it means the interaction cannot be fully batched or deferred.

### 2. Patient Access API carriers require a browser redirect

Some carriers authenticate through their own OAuth flow rather than by
accepting credentials. The member is sent to the carrier's website, signs
in there, and is redirected back to your application with an access
token in the query string. That redirect has to happen in a browser; there
is no server-to-server equivalent.

If you support these carriers you will need a small front-end step for
them. See [Endpoint reference → Patient Access
API](/connect-api/reference#patient-access-api).

## What changes when credentials flow through your server

With the SDK, carrier credentials go from the member's browser directly
to TPA Stream. Your servers never see them. With the Connect API they
pass through your infrastructure, which moves part of the compliance
boundary onto you:

- **Never log request bodies** on the credential-submit path, and audit
  any framework-level request logging, APM tooling, or error reporter
  that captures payloads by default.
- **Never persist credentials.** Forward them and drop them. TPA Stream
  stores what it needs to re-authenticate; you do not need a copy.
- **Terms of use acceptance is yours to collect correctly.** The
  `accept` and `tenants_accept` fields on the credential submit are the
  member's affirmative consent. If you render your own form you are
  representing that the member actually saw and accepted the terms.
  Fetch them from
  [`GET /terms_of_service`](/connect-api/reference#get-terms_of_service)
  rather than reproducing the text yourself, so it stays current.

Talk to your TPA Stream contact before going live if your business
associate agreement predates this integration pattern.

## Stability

Endpoints, request shapes, and response fields documented in this
section are covered by a compatibility commitment: we will not remove or
rename them, and any new fields will be additive. Behavior not documented
here — undocumented response fields, incidental ordering, exact error
copy — may change without notice.

If you need something the documented surface doesn't cover, ask rather
than reverse-engineering it from network traces. Undocumented behavior
you depend on is behavior we don't know we need to preserve.

## Next

- [Authentication](/connect-api/authentication) — tokens, headers, and
  how each request identifies the member.
- [Quickstart](/connect-api/quickstart) — a complete connection, start
  to finish, in curl.
- [Multi-factor authentication](/connect-api/two-factor) — the state
  machine and how to drive it.
- [Endpoint reference](/connect-api/reference) — every endpoint,
  parameter, and response shape.
