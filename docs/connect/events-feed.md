---
title: Events Feed
sidebar_label: Events Feed
---

# Events Feed

The events feed is the **durable companion to the webhooks**. Every
occurrence that fires (or would fire) a
[Claim Webhook](/connect/webhooks-claim),
[First Crawl Completion Webhook](/connect/webhooks-crawl), or
[Login Problem Webhook](/connect/webhooks-login-problem) is also
recorded as an immutable event you can read back with a simple
cursor-paged GET.

Webhooks are push: if your endpoint is down for longer than the
[retry window](/connect/webhook-security#response-codes-and-retries),
the notification is gone and you have no way to know. The feed fixes
that failure mode:

- **Nothing can be missed.** Page forward with a cursor; an event is
  never inserted behind a cursor you've already passed.
- **Self-serve reconciliation.** Periodically sweep the feed to verify
  your webhook consumer didn't drop anything.
- **Recovery after downtime.** Come back up, resume from your last
  cursor, and process everything that happened while you were down.

You can use the feed **instead of** webhooks (poll it on a schedule)
or **alongside** them (webhooks as the low-latency signal, the feed as
the source of truth). New events become visible in the feed shortly
after they occur — typically within a minute or two.

## Endpoint

```
GET https://app.tpastream.com/api/v2/events
```

Authentication is the same as the rest of the
[REST API](/api/authentication) — SSH-JWT (preferred) or your legacy
API key. Results are scoped to your tenant.

### Query parameters

| Parameter | Default | Description |
|---|---|---|
| `after` | `0` | Cursor: return only events with `id` greater than this. Pass the highest `id` you've processed. |
| `types` | all | Comma-separated filter: `new_claim`, `crawl_completion`, `login_problem`. |
| `limit` | `100` | Page size, 1–1000. |

### Response

```json
{
  "data": [
    {
      "id": 18234,
      "type": "new_claim",
      "created": "2026-07-30T14:03:11.482910+00:00",
      "data": {
        "claim_medical_id": 4821223,
        "policy_holder_id": 189162
      }
    },
    {
      "id": 18235,
      "type": "login_problem",
      "created": "2026-07-30T14:04:02.118834+00:00",
      "data": {
        "policy_holder_id": 189162,
        "payer_id": 42,
        "login_problem": "invalid"
      }
    }
  ],
  "has_more": false
}
```

`has_more: true` means another page is immediately available — keep
paging with `after=<last id>` until it comes back `false`.

## Event types

| `type` | Fires when | `data` fields |
|---|---|---|
| `new_claim` | A claim is retrieved or updated for one of your members (same trigger as the [Claim Webhook](/connect/webhooks-claim)). | `claim_medical_id`, `policy_holder_id` |
| `crawl_completion` | A first crawl completion is posted for a policy holder (same trigger as the [First Crawl Completion Webhook](/connect/webhooks-crawl); recorded for tenants with that webhook configured). | `crawl_id`, `policy_holder_id`, `success`, `crawl_claim_ids` |
| `login_problem` | A policy holder's login state changes (same trigger as the [Login Problem Webhook](/connect/webhooks-login-problem)). | `policy_holder_id`, `payer_id`, `login_problem` |

Events are deliberately **thin**: they carry identifiers and the state
change, not full resources. Fetch the full record through the REST API
when you need it (for example `claim_medical_id` → the claims API).
Unlike webhooks, `new_claim` and `login_problem` events are recorded
whether or not you have the corresponding webhook URL configured.

## Consuming the feed

The canonical consumer is a small poll loop:

1. Persist a single integer: the highest event `id` you've processed.
2. On a schedule (every minute is plenty), `GET /api/v2/events?after=<cursor>`.
3. Process each event idempotently, then advance the cursor.
4. If `has_more` is true, request the next page immediately.

Guarantees to build against:

- `id` is **strictly increasing** and never back-fills: once you've
  seen id N, no event with id ≤ N will ever appear later.
- Delivery is **at-least-once from your perspective** (you choose when
  to advance the cursor), so make processing idempotent.
- Events are retained for **90 days**. Don't let a consumer lag longer
  than that; for cold-start backfills beyond the window, use the REST
  API instead.

## Relationship to webhook replays

Manually replayed webhooks (for example the
[crawl completion replay](/connect/webhooks-crawl#replaying-a-crawl-completion-post))
re-send the webhook only — they do **not** create new feed events,
since the original occurrence is already recorded.
