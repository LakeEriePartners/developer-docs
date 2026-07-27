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
authenticated session open. That session has a limited lifetime. This is
the one place in the Connect API where a real person has to act inside a
bounded window.

## The state machine

After you submit credentials you have a `task_id`. Poll
[`GET /validate-credentials/{policy_holder_id}/{task_id}`](/connect-api/reference#get-validate-credentials)
and drive off `state`:

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

When you poll into `WAITING_FOR_METHOD_CHOICE`:

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

Then keep polling. You will move through `TRIGGERING_TWO_FACTOR_AUTH`
into `WAITING_FOR_TWO_FACTOR_CODE`.

Some carriers offer only one method and skip this state entirely, going
straight to `WAITING_FOR_TWO_FACTOR_CODE`. Handle both.

## Submitting the code

```bash
tpa -X PUT "$TPA_BASE/validate-credentials/630364/3bb088ed-..." -d '{
  "user_email": "member@example.com",
  "code": "482915"
}'
```

Same endpoint, different key. Keep polling afterward.

If the carrier rejects the code — wrong digits, expired, mistyped — the
state returns to `WAITING_FOR_TWO_FACTOR_CODE` with a `message`
explaining why. Surface that message and let the member try again. Do
**not** restart the credential submission; the carrier session is still
open and a fresh submit will send a second code and confuse the member.

## Polling cadence

| Situation | Interval |
|---|---|
| Right after credential submit | 3 seconds |
| Waiting on the member to pick a method or type a code | 5 seconds |
| Anything past 2 minutes on the same state | 10 seconds |

Stop polling once you reach `SUCCESS` or `FAILURE`. There is no reason
to poll a terminal task, and no new information will arrive.

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

## Server-sent events

There is also an event stream:

```
GET https://app.tpastream.com/v3/sdk/progress/{task_id}/stream?token={task_token}
```

It pushes the same state transitions as they happen, authenticated by the
`task_token` returned alongside `task_id` on the credential submit.

**We recommend polling instead for server-side integrations.** The stream
was built for browsers and carries browser-shaped constraints: the
`task_token` is valid for about ten minutes, and the server closes the
stream after roughly the same interval with a `timeout` event. A member
who takes longer than that to find their phone will outlive the stream.
The polling endpoint has neither limit and is authenticated the same way
as every other call.

If a stream does close on you, the underlying validation is unaffected —
it keeps running, and polling will show you where it landed.

## Failure modes worth handling

| Symptom | Cause | Response |
|---|---|---|
| `FAILURE` immediately after submit | Credentials rejected outright. | Show `message`, let the member re-enter. |
| Stuck in `PENDING` past a few minutes | Carrier is slow or degraded. | Keep polling, but tell the member it's taking a while. |
| `WAITING_FOR_TWO_FACTOR_CODE` with a `message` | The previous code was rejected. | Show the message, accept another code. |
| `SUCCESS` with `credentials_are_valid: false` | The carrier authenticated but the account has a problem. | Check `login_problem` on the policy holder. |
| `SUCCESS` with `pending: true` | No verdict yet; we will keep trying in the background. | Treat as provisional success, not failure. |
