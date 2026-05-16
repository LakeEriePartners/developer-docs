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
    "client-library": "/connect/quickstart",
    usage: "/connect/quickstart",
    "javascript-client": "/connect/quickstart",
    "npm-example-recommended": "/connect/quickstart#npm-recommended",
    "cdn-example": "/connect/quickstart#hosted-cdn",
    "android-example": "/connect/quickstart#android-webview",
    "ios-example": "/connect/quickstart#ios-wkwebview",
    "sdk-client-usage-docs": "/sdk/client-usage",
    webhooks: "/connect/webhooks-claim",
    "claim-webhook": "/connect/webhooks-claim",
    "first-crawl-completion-webhook": "/connect/webhooks-crawl",
    "request-retries": "/connect/webhook-security#response-codes-and-retries",
    "tpastream-signature-verification":
      "/connect/webhook-security#tpastream-signature-verification",
    "example-claim-webhook-json-request":
      "/connect/webhook-examples#claim-webhook",
    "example-crawl-webhook-json-request":
      "/connect/webhook-examples#crawl-webhook",
  },
};

function maybeRedirect(): void {
  if (typeof window === "undefined") return;
  const hash = window.location.hash.replace(/^#/, "");
  if (!hash) return;
  const path = window.location.pathname.replace(/\/$/, "") || "/";
  const map = PAGE_TO_ANCHOR_MAP[path];
  if (!map) return;
  const target = map[hash];
  if (!target) return;
  // Use replace so the back button returns to whatever sent them here,
  // not to the temporary landing on the old-page-equivalent.
  window.location.replace(target);
}

if (typeof window !== "undefined") {
  // Run on initial load…
  if (document.readyState === "complete") {
    maybeRedirect();
  } else {
    window.addEventListener("load", maybeRedirect, { once: true });
  }
  // …and on every SPA route change inside Docusaurus.
  let lastUrl = window.location.href;
  const observer = new MutationObserver(() => {
    if (window.location.href !== lastUrl) {
      lastUrl = window.location.href;
      maybeRedirect();
    }
  });
  observer.observe(document, { subtree: true, childList: true });
}

export {};
