---
title: Insurance Cards
sidebar_label: Insurance Cards
---

# Insurance Cards

`GET /api/v3/policy_holder/<id>/insurance-cards` returns the current
insurance ID card images collected for one carrier login (a policy
holder). The full parameter and response reference is in the
[API Reference](/api-reference/tpa-stream-api).

Cards are collected automatically during the normal crawl, for supported
carriers only. The "current" cards are the cards returned by the most
recent crawl that returned cards. Blue Cross Blue Shield of Arizona is
the first supported carrier.

## Response

```json
{
  "data": [
    {
      "id": "00000000-0000-4000-8000-000000000001",
      "label": "medical_front",
      "name": "medical_front.jpg",
      "mime_type": "image/jpeg",
      "createddate": "2026-11-23T12:00:00Z",
      "url": "https://app.tpastream.com/.../policy_holder/123/tpafile/456.jpg"
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | The card's own id (a UUID). |
| `label` | The plan type and side, for example `medical_front` or `medical_back`. `null` for a card saved before labels were collected. |
| `name` | The file name. |
| `mime_type` | The image type, for example `image/jpeg`. |
| `createddate` | When we saved the card. |
| `url` | The download link for the image. |

The response is not paginated. A policy holder with no collected card
returns an empty list: `{"data": []}`.

Permissions and tenant scoping are the same as reading the policy holder
itself. A policy holder that belongs to another organization returns
`404`.

## Downloading an image

Send a `GET` to `url` with the same credentials you used for the API
call. The link is not public.
