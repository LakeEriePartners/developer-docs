---
title: Connect SDK Quickstart
sidebar_label: Quickstart
---

# Connect SDK Quickstart

This page shows the smallest possible page that mounts the SDK. For
the full step-by-step (token issuance, employer + user configuration,
mobile / WebView patterns, MFA, fix-credentials), see
[**SDK Reference → Quickstart**](/sdk/quickstart) — it's the canonical
source maintained alongside the SDK code itself.

## Demo mode (CDN)

The minimum viable SDK page. Drops the SDK into the
`#sdk-hook` element and runs in `isDemo: true`, which mounts the
wizard but doesn't talk to TPA Stream.

```html
<!DOCTYPE html>
<html>
  <head>
    <script src="https://app.tpastream.com/static/js/sdk.js"></script>
    <script>
      window.StreamConnect({
        el: "#sdk-hook",
        isDemo: true,
      });
    </script>
  </head>
  <body>
    <div id="sdk-hook"></div>
  </body>
</html>
```

To leave demo mode, swap `isDemo: false` and add an `sdkToken` your
backend has issued (the SDK Quickstart walks through the
token-issuance flow). The 0.8 SDK derives tenant / employer / user
context from the token; the older
`tenant: {…}, employer: {…}, user: {…}` init shape from 0.7.x still
works as a backwards-compat path but isn't the recommended pattern
for new integrations.

## npm

```bash
npm install stream-connect-sdk
```

```javascript
import StreamConnect from "stream-connect-sdk";

const sdk = StreamConnect({
  el: "#sdk-hook",
  isDemo: true,
});
```

## Pinning a CDN version

The CDN is versioned. The script tag's `src` selects the version:

- `https://app.tpastream.com/static/js/sdk.js` — always the latest
- `https://app.tpastream.com/static/js/sdk-v-<VersionNumber>.js` — a
  specific version (e.g. `sdk-v-0.8.0.js`). Pinned versions remain
  available indefinitely.

## Mobile (Android, iOS, React Native)

The SDK is web-first. The recommended mobile integration is to embed
an HTML page loading the SDK in a WebView and ferry callbacks to the
native host via `postMessage` / message handlers. See
[SDK Reference → Mobile](/sdk/quickstart#mobile-android-ios-react-native)
for working WebView snippets in React Native, Android, and iOS.
