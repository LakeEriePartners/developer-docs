---
title: Pagination
sidebar_label: Pagination
---

# Pagination

List endpoints (`/api/claims`, `/api/policy_holder`, etc.) return a
paginated envelope rather than a bare array:

```json
{
  "data": [
    { "...": "..." }
  ],
  "page": 1,
  "per_page": 10,
  "pages": 7,
  "total": 64,
  "has_next": true,
  "has_prev": false,
  "next_num": 2,
  "prev_num": null
}
```

- `page` is 1-based.
- `per_page` defaults to 10 when omitted.
- `data` holds the records for this page. The other top-level fields
  describe where you are in the result set.

Pass `page` and `per_page` as query parameters to walk the set:

```bash
curl -L \
  -H "Authorization: SSH-JWT <your_signed_jwt>" \
  "https://app.tpastream.com/api/claims?page=1&per_page=100"
```

Iterate until `has_next` is `false`.
