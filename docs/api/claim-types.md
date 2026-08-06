---
title: Claim Types
sidebar_label: Claim Types
---

# Claim Types

Every claim carries a `type` describing what kind of care it covers.
It serializes as a nested object:

```json
{
  "type": {
    "name": "medical",
    "type_id": 1
  }
}
```

The set is closed. There are five values, they are fixed in the
application rather than stored in a configurable table, and they are
not tenant-configurable — you will not see a different set for a
different employer.

| `name` | `type_id` | Suggested label |
|---|---|---|
| `medical` | 1 | Medical |
| `dental` | 2 | Dental |
| `rx` | 3 | Rx |
| `vision` | 4 | Vision |
| `facility` | 5 | Facility |

A static five-entry map is enough to render these. You don't need to
handle carrier-specific codes: carriers send us a wide range of
proprietary type codes, and we normalize all of them onto these five
before they reach the API.

## `type` can be null

When the carrier doesn't tell us what kind of claim it is, the whole
`type` object is `null` — not an object with an empty `name`:

```json
{
  "type": null
}
```

This is uncommon but not rare, so handle it explicitly rather than
assuming `type` is always present. Displaying it as "Unknown" is the
convention we use in the TPA Stream web app. The
[claim webhook example payload](/connect/webhook-examples#claim-webhook)
shows a claim in this state.

## `name` values are identifiers, not labels

The `name` strings are stable machine identifiers. They are always
lowercase, so you get `rx` — never `Rx` or `RX`.

Don't render them to end users as-is. If you're generating labels
programmatically, title-casing gets you four of the five and you'll
want to special-case the fifth:

```js
const CLAIM_TYPE_LABELS = {
  medical: 'Medical',
  dental: 'Dental',
  rx: 'Rx',
  vision: 'Vision',
  facility: 'Facility',
};

const claimTypeLabel = (type) =>
  CLAIM_TYPE_LABELS[type?.name] ?? 'Unknown';
```

Match on `name` rather than `type_id` if you want your code to stay
readable; the two are equivalent and always travel together.

## What `facility` means

Four of the five names are self-explanatory. `facility` is the one
worth a note: it means facility-billed care — typically an inpatient
hospital stay — as opposed to a professional claim billed by an
individual provider.

It's the rarest of the five by a wide margin. Whether you surface it
as its own category, relabel it something like "Hospital", or fold it
into Medical for member-facing copy is a presentation decision on your
side. We'd just recommend not showing the bare word `facility` to a
member without context.

## Field naming

The REST API emits `type_id` in snake_case, matching the rest of the
API. If you're seeing `typeId`, something in your own stack is
converting keys to camelCase — worth confirming before you key a
lookup table off the field name.

## Prescription type

Claim *lines* carry a separate and unrelated `prescription_type_id` /
`prescription_type_str` pair, which describes whether a prescription
is generic or brand:

| `prescription_type_str` | `prescription_type_id` |
|---|---|
| `generic` | 1 |
| `brand` | 2 |

Like claim type, it's nullable, and it appears on the claim line
rather than the claim.
