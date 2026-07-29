---
title: Multi-factor authentication
sidebar_label: Multi-factor auth
---

# Multi-factor authentication

Most carriers challenge a credential submission with a one-time code at
least some of the time. Across our customer base this is roughly a third
of connection attempts, so treat it as a normal path rather than an edge
case — an integration that only handles the happy path will fail for a
large minority of your members.

While a validation waits on a code, the carrier is holding an
authenticated session open, so the validation will not wait forever:
**the member has about five minutes at each interactive step** (picking
a delivery method, entering the code) before the validation gives up
and the connection is marked as needing member attention. That number —
not any transport detail — is the constraint to design your prompt UX
around.

## The state machine

After you submit credentials you have a `task_id`. Watch its `state`
— over the [event stream](#watching-progress-server-sent-events) or by
[polling](#polling-as-a-fallback) — and drive off it:

```
        POST credentials
               │
               ▼
          ┌─────────┐
          │ PENDING │◄──────────────┐
          └────┬────┘               │
               │                    │
   no MFA ─────┼───── MFA required  │
      │        │                    │
      │        ▼                    │
      │  WAITING_FOR_METHOD_CHOICE  │
      │        │                    │
      │        │ PUT {method}       │
      │        ▼                    │
      │  TRIGGERING_TWO_FACTOR_AUTH ┤  (carrier is sending the code)
      │        │                    │
      │        ▼                    │
      │  WAITING_FOR_TWO_FACTOR_CODE│
      │        │                    │
      │        │ PUT {code}         │
      │        ▼                    │
      │  ENTERING_CODE ─────────────┘  (wrong code returns here
      │        │                        with a message)
      │        ▼
      │  TWO_FACTOR_AUTH_COMPLETE
      │        │
      ▼        ▼
    SUCCESS / FAILURE
```

| State | Terminal | Meaning |
|---|---|---|
| `PENDING` | No | Working. Also reported for the underlying `STARTED` and `RETRY` states. |
| `WAITING_FOR_METHOD_CHOICE` | No | The carrier offers several delivery methods. `info.method_list` holds them. |
| `TRIGGERING_TWO_FACTOR_AUTH` | No | We asked the carrier to send the code. |
| `WAITING_FOR_TWO_FACTOR_CODE` | No | The code is on its way to the member. |
| `ENTERING_CODE` | No | We are submitting the code you supplied. |
| `TWO_FACTOR_AUTH_COMPLETE` | No | The code was accepted. `SUCCESS` follows shortly. |
| `SUCCESS` | Yes | Finished. Read `credentials_are_valid`. |
| `FAILURE` | Yes | Could not complete. Read `message`. |

## Choosing a delivery method

When the state reaches `WAITING_FOR_METHOD_CHOICE`:

```json
{
  "data": {
    "id": "3bb088ed-...",
    "state": "WAITING_FOR_METHOD_CHOICE",
    "info": { "method_list": ["Text to (***) ***-1234", "Email to d***@example.com"] }
  }
}
```

`method_list` is carrier-authored text. Show the strings as-is; do not
try to normalize them into your own categories, and do not assume SMS is
always present or always first.

Send back the exact string the member picked:

```bash
tpa -X PUT "$TPA_BASE/validate-credentials/630364/3bb088ed-..." -d '{
  "user_email": "member@example.com",
  "method": "Text to (***) ***-1234"
}'
```

Then keep watching. You will move through `TRIGGERING_TWO_FACTOR_AUTH`
into `WAITING_FOR_TWO_FACTOR_CODE`. From the moment the method list is
offered, the member has about five minutes to pick one.

Some carriers offer only one method and skip this state entirely, going
straight to `WAITING_FOR_TWO_FACTOR_CODE`. Handle both.

## Submitting the code

```bash
tpa -X PUT "$TPA_BASE/validate-credentials/630364/3bb088ed-..." -d '{
  "user_email": "member@example.com",
  "code": "482915"
}'
```

Same endpoint, different key. Keep watching afterward. The five-minute
clock applies here too: once the carrier sends the code, the member has
about five minutes to supply it.

If the carrier rejects the code — wrong digits, expired, mistyped — the
state returns to `WAITING_FOR_TWO_FACTOR_CODE` with a `message`
explaining why. Surface that message and let the member try again. Do
**not** restart the credential submission; the carrier session is still
open and a fresh submit will send a second code and confuse the member.

## Designing the member experience

Your front end has to prompt the member and get the code back to your
server. The specific transport is up to you — a polled endpoint on your
own API, a websocket, a server-sent stream, or a plain form post all
work. What matters:

- **Do not block your UI on the whole flow.** The member may need a
  minute to find their phone. Let them do other things; surface the
  prompt when it arrives.
- **Show carrier text verbatim.** Method labels and rejection messages
  come from the carrier and are usually more accurate than anything you
  would write.
- **Let them retry the code without starting over.** This is the most
  common recoverable failure in the whole flow.
- **Handle the member walking away.** Decide what your UI does when a
  validation is left hanging, and make sure the member can start a fresh
  attempt later.

## Watching progress: server-sent events

The recommended way to watch a validation is the event stream — states
arrive as they happen, with nothing to poll:

```
GET https://app.tpastream.com/v3/connect/progress/{task_id}/stream?token={task_token}
```

Authentication is the `task_token` returned alongside `task_id` on the
credential submit — a short-lived JWT bound to that one task. From curl:

```bash
curl -N "https://app.tpastream.com/v3/connect/progress/$TASK_ID/stream?token=$TASK_TOKEN"
```

Three event types arrive:

| Event | Payload | Meaning |
|---|---|---|
| `state` | The task's current status and result data | Drive your state machine off this. |
| `ping` | `{}` | Heartbeat every ~15s. Ignore. |
| `timeout` | `{}` | This *connection* hit its ~10-minute cap. Resubscribe (below). The validation is unaffected. |

`state` events carry the raw task metadata: `status` is the state name
from the table above, and `result` holds the stage's data (for
`WAITING_FOR_METHOD_CHOICE`, `result.method_list` is the delivery-method
list). Treat any status you don't recognize as "still working".

### Reattaching

Each stream connection is capped at about ten minutes, and each
`task_token` is scoped to roughly one connection — but the validation
stays subscribable for its entire lifetime. When you receive `timeout`
(or lose the connection):

1. `GET /policy_holder/{id}` — while the validation
   is alive, the response includes the active `task_id` and a **fresh
   `task_token`**.
2. Resubscribe to the stream with the new token.

If a resubscribe fails with `401` and `Task not available`, the
validation has reached a terminal state — read the outcome with
[`GET /validate-credentials/...`](/connect-api/reference#get-validate-credentials)
(or the policy-holder GET) rather than retrying the stream.

One practical shortcut: for connection UX you can stop streaming at
`TWO_FACTOR_AUTH_COMPLETE`. The task keeps running well past it —
retrieving the member's claims can take a long while — but the answer
your member is waiting for (did the connection work?) is already known,
and claims reach you via the
[claim webhook](/connect/webhooks-claim), not the stream.

## Polling as a fallback

If you'd rather not hold streams open,
[`GET /validate-credentials/{policy_holder_id}/{task_id}`](/connect-api/reference#get-validate-credentials)
returns the same states. Poll it every few seconds while a validation
is in flight and stop on `SUCCESS` / `FAILURE`. It is authenticated
like every other Connect API call and needs no `task_token`. Both
transports are supported; pick whichever fits your architecture.

## Failure modes worth handling

| Symptom | Cause | Response |
|---|---|---|
| `FAILURE` immediately after submit | Credentials rejected outright. | Show `message`, let the member re-enter. |
| Stuck in `PENDING` past a few minutes | Carrier is slow or degraded. | Keep watching, but tell the member it's taking a while. |
| `WAITING_FOR_METHOD_CHOICE` / `WAITING_FOR_TWO_FACTOR_CODE` ends in `FAILURE` with no input sent | The member ran out the ~5-minute window at that stage. | The connection is marked as needing attention; let the member start a fresh attempt. |
| Stream emits `timeout` | That connection hit its ~10-minute cap. | [Reattach](#reattaching); the validation is unaffected. |
| Resubscribe returns `401` `Task not available` | The validation reached a terminal state. | Read the outcome via the GET; don't retry the stream. |
| `WAITING_FOR_TWO_FACTOR_CODE` with a `message` | The previous code was rejected. | Show the message, accept another code. |
| `SUCCESS` with `credentials_are_valid: false` | The carrier authenticated but the account has a problem. | Check `login_problem` on the policy holder. |
| `SUCCESS` with `pending: true` | No verdict yet; we will keep trying in the background. | Treat as provisional success, not failure. |
