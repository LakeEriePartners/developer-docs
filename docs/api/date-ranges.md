---
title: A Note About Date Ranges
sidebar_label: Date Ranges
---

# A Note About Date Ranges

Types of data that are date ranges are serialized to JSON as an
object with `bounds`:

```json
{
  "bounds": "[)",
  "end": "2025-09-16",
  "start": "2025-09-15"
}
```

A date of service may span multiple days (for example, a hospital
stay), so it's stored as a range.

In text form:

| Symbol | Meaning |
|---|---|
| `[` | Inclusive lower bound |
| `(` | Exclusive lower bound |
| `]` | Inclusive upper bound |
| `)` | Exclusive upper bound |

For more details and examples, see the PostgreSQL documentation:
[Range Types — Inclusivity](https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-INCLUSIVITY).
