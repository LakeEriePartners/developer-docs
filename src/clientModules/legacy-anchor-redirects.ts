// Re-route bookmarks of the form /<old-page>#<old-anchor> after the
// nginx path-level 301 has already landed the browser on the new
// landing page. Browsers carry the fragment through a 301, so a
// bookmark to /api.html#pagination first hits nginx → 301 →
// /api/overview, then this module checks the fragment on load and
// hops to the dedicated /api/pagination page if the anchor belongs
// there.
//
// Only the cases where the old anchor lives on a DIFFERENT page in
// the new structure need an entry here; same-page anchors work
// automatically because the slugs match.
//
// Implementation note: Docusaurus is a client-side SPA, so we need
// to react both to the initial page load AND to in-app route
// changes. Rather than polling with a MutationObserver, we listen
// for `popstate` and monkey-patch `history.pushState` /
// `replaceState` to emit a custom `locationchange` event. This is
// the standard pattern for SPAs that don't expose a router-event
// API; React Router / TanStack Router and Docusaurus's
// `@docusaurus/router` all funnel through these History calls.

type AnchorMap = Record<string, Record<string, string>>;

const PAGE_TO_ANCHOR_MAP: AnchorMap = {
  // Old /api.html anchors that are now their own pages.
  "/api/overview": {
    "ssh-jwt-preferred": "/api/authentication#ssh-jwt-preferred",
    "api-tokens-legacy": "/api/authentication#api-tokens-legacy",
    "common-mistakes": "/api/authentication#common-authentication-mistakes",
    pagination: "/api/pagination",
    security: "/api/security",
    "generating-an-ssh-key": "/api/ssh-keys",
    "generating-a-gpg-key": "/api/gpg-keys",
    "a-note-about-date-ranges": "/api/date-ranges",
    authentication: "/api/authentication",
  },
  // Old /connect.html anchors that are now their own pages.
  "/connect/overview": {
    // Client library / quickstart group
    "client-library": "/connect/quickstart",
    usage: "/connect/quickstart",
    "javascript-client": "/connect/quickstart",
    "source-code": "/connect/quickstart",
    "detailed-client-usage-docs": "/sdk/client-usage",
    "other-useful-documentation-links": "/sdk/",
    "sdk-client-usage-docs": "/sdk/client-usage",
    "npm-example-recommended": "/connect/quickstart#npm-recommended",
    "cdn-example": "/connect/quickstart#hosted-cdn",
    "pinning-a-cdn-version": "/connect/quickstart#pinning-a-cdn-version",
    "android-example": "/connect/quickstart#android-webview",
    "ios-example": "/connect/quickstart#ios-wkwebview",
    "change-log": "/sdk/",
    // Old per-version changelog anchors all fold to the SDK Reference now.
    "v0-4-8-latest": "/sdk/",
    "v0-4-7": "/sdk/",
    "v0-4-6": "/sdk/",
    "v0-4-5": "/sdk/",
    "v0-4-4": "/sdk/",
    "v0-4-3": "/sdk/",
    // Webhooks split into multiple pages.
    webhooks: "/connect/webhooks-claim",
    "claim-webhook": "/connect/webhooks-claim",
    "claim-webhook-url": "/connect/webhooks-claim#configuring-the-url",
    "replaying-a-claim-post": "/connect/webhooks-claim#replaying-a-claim-post",
    "first-crawl-completion-webhook": "/connect/webhooks-crawl",
    "first-crawl-completion-webhook-url":
      "/connect/webhooks-crawl#configuring-the-url",
    "replaying-a-crawl-completion-post":
      "/connect/webhooks-crawl#replaying-a-crawl-completion-post",
    "request-retries": "/connect/webhook-security#response-codes-and-retries",
    // The Sphinx page had a top-level "Security" heading covering
    // signature verification; it now lives on its own page.
    security: "/connect/webhook-security",
    "tpastream-signature-verification":
      "/connect/webhook-security#tpastream-signature-verification",
    "example-claim-webhook-json-request":
      "/connect/webhook-examples#claim-webhook",
    "example-crawl-webhook-json-request":
      "/connect/webhook-examples#crawl-webhook",
    // "trigger" was a sub-heading under both webhook sections.
    // Default to the claim-webhook page; users on the crawl flow
    // will read down from the page top.
    trigger: "/connect/webhooks-claim#trigger",
  },
};

function currentPath(): string {
  return window.location.pathname.replace(/\/$/, "") || "/";
}

function maybeRedirect(): void {
  if (typeof window === "undefined") return;
  const hash = window.location.hash.replace(/^#/, "");
  if (!hash) return;
  const map = PAGE_TO_ANCHOR_MAP[currentPath()];
  if (!map) return;
  const target = map[hash];
  if (!target) return;
  // Use replace so the back button returns to whatever sent them
  // here, not to the path the 301 dropped them on.
  window.location.replace(target);
}

function installSpaListener(): void {
  // Patch history methods to emit a synthetic event when Docusaurus's
  // router (or any SPA router) navigates without a full reload.
  const w = window as typeof window & { __anchorRedirectInstalled?: boolean };
  if (w.__anchorRedirectInstalled) return;
  w.__anchorRedirectInstalled = true;

  const fire = () => window.dispatchEvent(new Event("locationchange"));
  const origPush = history.pushState;
  history.pushState = function patchedPush(
    ...args: Parameters<typeof origPush>
  ) {
    const r = origPush.apply(this, args);
    fire();
    return r;
  };
  const origReplace = history.replaceState;
  history.replaceState = function patchedReplace(
    ...args: Parameters<typeof origReplace>
  ) {
    const r = origReplace.apply(this, args);
    fire();
    return r;
  };
  window.addEventListener("popstate", fire);
  window.addEventListener("locationchange", maybeRedirect);
}

if (typeof window !== "undefined") {
  installSpaListener();
  if (document.readyState === "complete") {
    maybeRedirect();
  } else {
    window.addEventListener("load", maybeRedirect, { once: true });
  }
}

export {};
