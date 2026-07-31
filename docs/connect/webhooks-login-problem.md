---
title: Login Problem Webhook
sidebar_label: Login Problem Webhook
---

# Login Problem Webhook

TPA Stream can POST to a customer-provided URL whenever the **login
state of a carrier login (policy holder) changes** — for example when
a previously working credential becomes invalid, gets locked by the
carrier, or starts requiring multi-factor authentication.

This is the webhook to wire up if your application prompts members to
fix their credentials: it tells you the moment a login stops working,
without waiting for the member to notice.

## Trigger

The webhook fires whenever TPA Stream's crawler detects that a policy
holder's `login_problem` state has **changed** — including a change
back to `valid` after the member fixes their credentials. One POST is
made per tenant associated with the policy holder.

Common `login_problem` values:

| Value | Meaning |
|---|---|
| `valid` | Credentials work. |
| `invalid` | Carrier rejected the username/password. |
| `locked` | The carrier locked the account (usually too many bad attempts). |
| `needs_two_factor` | The carrier requires multi-factor authentication to proceed. |
| `inactive` | The account appears inactive on the carrier side. |
| `sec_question` | A security question is blocking the login. |

The set of values may grow over time; treat unknown values as "member
action may be required" and surface `login_correction_message`, which
always carries a member-readable explanation.

## Configuring the URL

To edit the URL, open **Account Settings** on the settings page, just
like the [Claim Webhook URL](/connect/webhooks-claim#configuring-the-url).
This webhook is feature-flagged per tenant — contact TPA Stream
support to enable it if the field isn't shown.

## Request shape

POST with `Content-Type: application/json`. See
[Webhook Examples](/connect/webhook-examples#login-problem-webhook)
for the full payload shape.

Like every TPA Stream webhook, the request is signed via the
`TPAStream-Signature` header and retried on failure per
[Webhook Security](/connect/webhook-security#response-codes-and-retries).

## Missed a webhook?

Webhook delivery is at-most-4-hours of retries. If your endpoint was
down longer than that — or you want to reconcile — use the
[Events Feed](/connect/events-feed), which records every login
problem change for 90 days and lets you page forward from a cursor.
