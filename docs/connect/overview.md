---
title: Connect SDK
sidebar_label: Overview
---

# Connect SDK

The [Stream Connect JavaScript SDK](https://github.com/TPAStream/stream-connect-js-sdk)
lets users of your web or mobile application connect their health
insurance accounts to your application.

For a working integration, follow the
[Quickstart](/connect/quickstart). For the full reference (init
options, lifecycle callbacks, error handling, MFA, theming), see the
[SDK Reference](/sdk/), which is generated from the SDK repository's
own docs at the version pinned in this build.

## What it does

- Renders a wizard that lets the member pick their carrier, enter
  credentials, and confirm enrollment.
- Validates credentials against the carrier in real time when
  supported.
- Hands off to the carrier for redirect-based flows (Patient Access
  API and similar) when applicable.
- Calls back into your application at every step so you can theme it,
  log analytics, or inject custom UI.

## Companion: webhooks

The SDK is the **connect** half of the story. Once the member is
connected, TPA Stream starts crawling and POSTs results to your
application via:

- [Claim Webhook](/connect/webhooks-claim) — fires for every new
  claim.
- [First Crawl Completion Webhook](/connect/webhooks-crawl) — fires
  once after the first successful crawl per policy holder.
- [Login Problem Webhook](/connect/webhooks-login-problem) — fires
  when a connected carrier login stops working (or starts working
  again).

All webhook payloads are signed; see
[Webhook Security](/connect/webhook-security) before you wire any of
them up in production.

## Companion: events feed

Webhooks are push-only. The [Events Feed](/connect/events-feed) is
the durable, cursor-paged record of the same occurrences — use it to
recover from missed webhooks, reconcile your consumer, or skip
webhooks entirely and poll.
