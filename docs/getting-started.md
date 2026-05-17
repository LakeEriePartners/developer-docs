---
title: Getting Started
sidebar_label: Getting Started
---

# Getting Started

## Connecting the Health Insurance API to your application

To get claim data into your application, a member first connects their
health insurance account with your application through TPA Stream's
API. The easiest path is the
[Connect SDK](/connect/overview), a small JavaScript client library
that drops into any web or mobile app.

The SDK is highly configurable and meant to live inside your
application. Once embedded, the member can select an insurance
carrier, enter their credentials, and verify them in real time. Once
they're connected, TPA Stream starts receiving their claim data
asynchronously.

## Retrieving claim data

Typically TPA Stream begins receiving a member's claims within a
minute of them connecting their account through the SDK. It can take
anywhere from several minutes to several hours to receive every claim,
generally ordered newest first.

There are several ways to get claim data into your application:

- **As soon as possible** — implement the
  [Claim Webhook](/connect/webhooks-claim). TPA Stream POSTs each new
  claim to a URL you provide.
- **Pull on demand** — use the
  [REST API](/api/overview).
- **Daily CSV feed** — TPA Stream can set up a daily file feed via
  sFTP, FTPS, or to an S3 bucket. Contact
  [sales@tpastream.com](mailto:sales@tpastream.com) to enable.
