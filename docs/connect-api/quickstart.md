---
title: Connect API Quickstart
sidebar_label: Quickstart
---

# Quickstart

A complete carrier connection, start to finish, in curl. Every call here
is one your backend would make. Nothing in this walkthrough requires a
browser except where noted.

Set up your environment first:

```bash
export TPA_BASE=https://app.tpastream.com/connect/v1
export TPA_CONNECT_TOKEN=...      # your public Connect token
export TPA_MEMBER=member@example.com
```

And a helper so the examples stay readable:

```bash
tpa() { curl -sS -H "X-TPAStream-Token: $TPA_CONNECT_TOKEN" \
                 -H "X-Connect-API-Version: 1" \
                 -H "Content-Type: application/json" "$@"; }
```

## 1. Bootstrap the member

This is the only call that may reference a member who doesn't exist yet.
It creates or resolves the member, attaches them to the employer, and
returns the carriers available to them.

```bash
tpa -X POST "$TPA_BASE/bootstrap" -d '{
  "system_key": "EMP-1234",
  "vendor": "internal",
  "employer_name": "Acme Corp",
  "user_first_name": "Dana",
  "user_last_name": "Reyes",
  "user_email": "member@example.com",
  "date_of_birth": "1985-04-12"
}'
```

```json
{
  "data": {
    "user": { "id": 90210, "email": "member@example.com" },
    "employer": { "id": 203246, "name": "Acme Corp" },
    "tenant": { "id": 1141, "name": "Acme Benefits" },
    "payers": [
      { "id": 6, "name": "UnitedHealthcare", "logo_url": "https://..." },
      { "id": 116, "name": "Blue Cross Blue Shield of Massachusetts" }
    ]
  }
}
```

Hold onto `employer.id` and `user.id`. You will need the employer id on
almost every subsequent call.

Render `payers` however you like — this is your carrier picker.

## 2. Fetch the carrier's credential form

Carriers ask for different things. Some want a username and password,
some add a member id, a date of birth, or security questions. Rather than
hard-coding per-carrier forms, fetch the schema:

```bash
tpa -G "$TPA_BASE/payer/203246/6" --data-urlencode "email=$TPA_MEMBER"
```

```json
{
  "data": {
    "id": 6,
    "name": "UnitedHealthcare",
    "logo_url": "https://...",
    "onboard_form": { "...": "JSON Schema describing the fields" },
    "onboard_ui_schema": { "...": "presentation hints for those fields" },
    "has_security_questions": false,
    "supports_interoperability_apis": false,
    "register_url": "https://www.myuhc.com/register",
    "website_home_url_netloc": "myuhc.com"
  }
}
```

`onboard_form` is a JSON Schema. Drive your form from it and you get new
carriers, and changes to existing ones, without a deploy.

Two fields worth branching on:

- `supports_interoperability_apis: true` means this carrier uses an OAuth
  redirect instead of credentials. Skip to
  [Patient Access API](/connect-api/reference#patient-access-api) —
  the rest of this walkthrough does not apply.
- `register_url` is where a member with no carrier account should be sent
  to make one. Surface it near your form.

## 3. Fetch the terms of use

The member must accept before you can submit credentials. Fetch the
current text rather than reproducing it:

```bash
tpa -G "$TPA_BASE/terms_of_service" --data-urlencode "email=$TPA_MEMBER"
```

```json
{ "data": { "html_string": "<div>...</div>" } }
```

Render it, and collect two separate affirmative acknowledgements: the
terms of use themselves, and consent for the tenant to access the
account on the member's behalf. They map to `accept` and
`tenants_accept` in the next step.

## 4. Submit credentials

```bash
tpa -X POST "$TPA_BASE/policy_holder" -d '{
  "user_email": "member@example.com",
  "employer_id": 203246,
  "payer_id": 6,
  "username": "dreyes",
  "password": "hunter2",
  "date_of_birth": "1985-04-12",
  "accept": true,
  "tenants_accept": [1141]
}'
```

Any additional fields the carrier's `onboard_form` declares go at the top
level of this same object.

```json
{
  "data": {
    "policy_holder_id": 630364,
    "task_id": "3bb088ed-cc38-4e0f-919f-f2060014ac44",
    "task_token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

Three things to note:

- `accept` must be truthy and `tenants_accept` must be a **non-empty
  array** of tenant ids. A string will be rejected. Missing either
  returns `403`.
- `task_id` identifies the validation now running against the carrier.
  This is what you watch.
- `task_token` authenticates the
  [event stream](/connect-api/two-factor#watching-progress-server-sent-events)
  subscription for this validation. It is short-lived by design; a fresh
  one is minted every time you GET the policy holder while the
  validation is running.

To **reconnect** an existing policy holder after a credential change,
send the same body as a `PUT` to
`/policy_holder/{policy_holder_id}`.

## 5. Watch the validation

The credential submit returned a `task_id` and a `task_token`.
Subscribe to the event stream and states arrive as they happen:

```bash
curl -N "https://app.tpastream.com/v3/connect/progress/3bb088ed-cc38-4e0f-919f-f2060014ac44/stream?token=$TASK_TOKEN"
```

Each connection is capped at ~10 minutes; on the `timeout` event,
re-fetch the policy holder for a fresh `task_token` and resubscribe —
the [MFA page](/connect-api/two-factor#reattaching) has the loop.
Prefer not to hold streams open? Polling works too:

```bash
tpa -G "$TPA_BASE/validate-credentials/630364/3bb088ed-cc38-4e0f-919f-f2060014ac44" \
    --data-urlencode "email=$TPA_MEMBER"
```

```json
{ "data": { "id": "3bb088ed-...", "state": "PENDING" } }
```

Either way, you will land on one of:

| `state` | What it means | What to do |
|---|---|---|
| `PENDING` | Still working. | Keep watching. |
| `WAITING_FOR_METHOD_CHOICE` | The carrier wants a one-time code and is offering delivery methods. | See [multi-factor](/connect-api/two-factor). |
| `WAITING_FOR_TWO_FACTOR_CODE` | A code has been sent. | See [multi-factor](/connect-api/two-factor). |
| `SUCCESS` | Validation finished. | Read `credentials_are_valid`. |
| `FAILURE` | Validation could not complete. | Read `message` and surface it. |

A terminal success:

```json
{
  "data": {
    "id": "3bb088ed-...",
    "state": "SUCCESS",
    "credentials_are_valid": true,
    "pending": false
  }
}
```

`credentials_are_valid: true` means the carrier accepted the login.
`pending: true` means we have not yet reached a verdict and will keep
trying in the background — treat it as "accepted for now, check back",
not as failure.

Most connections that need a one-time code pass through here. Read
[Multi-factor authentication](/connect-api/two-factor) before you ship;
about a third of real connections hit it.

## 6. Confirm the connection

```bash
tpa -G "$TPA_BASE/policy_holder/630364" \
    --data-urlencode "employer_id=203246" \
    --data-urlencode "email=$TPA_MEMBER"
```

```json
{
  "data": {
    "policy_holder_id": 630364,
    "uuid": "8d5f...",
    "payer_id": 6,
    "login_problem": null,
    "login_needs_correction": false,
    "last_successful_crawl_end": null,
    "claims_synced_count": 0
  }
}
```

`login_problem: null` with `login_needs_correction: false` is a healthy
connection. Claims will not be there yet — the first crawl runs
asynchronously and can take a while. Subscribe to the
[First Crawl Completion Webhook](/connect/webhooks-crawl) rather than
polling for them.

## 7. Show the member their connections

For a "manage my carriers" screen:

```bash
tpa -G "$TPA_BASE/fix-credentials" --data-urlencode "email=$TPA_MEMBER" \
    -H "X-Connect-Access-Token: $TPA_ACCESS_TOKEN"
```

Returns every policy holder for the member with its current status, so
you can render reconnect prompts for the ones that need attention. This
endpoint requires a
[connect access token](/connect-api/authentication#your-two-keys).

## Where to go next

- [Multi-factor authentication](/connect-api/two-factor) — required
  reading before launch.
- [Endpoint reference](/connect-api/reference) — every parameter and
  field.
- [Claim webhook](/connect/webhooks-claim) — how connected members'
  claims reach you.
