#!/usr/bin/env bash
# Refresh the committed OpenAPI snapshot from production.
# Run when the API has materially changed and you want the docs to
# reflect it; commit the resulting diff alongside any related
# narrative changes.
#
# Usage:
#   ./scripts/sync-openapi.sh                 # default: prod
#   ./scripts/sync-openapi.sh https://...     # override base URL
set -euo pipefail

BASE_URL="${1:-https://app.tpastream.com}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$SCRIPT_DIR/../openapi/tpastream-api.json"

echo "Fetching ${BASE_URL}/openapi.json"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSL --max-time 30 "${BASE_URL}/openapi.json" -o "$TMP"

if ! jq -e '.openapi and .paths and .info' "$TMP" > /dev/null; then
  echo "ERROR: response from ${BASE_URL}/openapi.json doesn't look like an OpenAPI spec" >&2
  echo "First 200 bytes:" >&2
  head -c 200 "$TMP" >&2
  echo >&2
  exit 1
fi

# The upstream spec (flask-smorest) doesn't define `tags`. Without
# tags, docusaurus-plugin-openapi-docs renders one flat list of 70+
# endpoints and skips emitting sidebar.ts entirely. Inject synthetic
# tags here based on the resource segment of each path so the API
# reference groups sensibly. Tags assigned on operations also drive
# the rendered breadcrumb / category badge per endpoint.
TAGGED="$(mktemp)"
python3 - "$TMP" "$TAGGED" <<'PYEOF'
import json, re, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src) as fh:
    spec = json.load(fh)

# Path-pattern overrides win over the derived tag. Add entries here
# when the derived name reads badly, or to collapse cousin resources
# into one section.
PATH_OVERRIDES = [
    # v3 (preferred) resources — disambiguate by version suffix.
    (re.compile(r"^/api/v3/policy_holder"),           ("Policy Holders (v3)", "Carrier-login records — v3 surface.")),
    (re.compile(r"^/api/v3/(member|account)"),        ("Members (v3)",        "Member roster — v3 surface.")),
    # v2 resources.
    (re.compile(r"^/api/v2/claims"),                  ("Claims (v2)",         "Medical claim records — v2 surface.")),
    (re.compile(r"^/api/v2/policy_holder"),           ("Policy Holders (v2)", "Carrier-login records — v2 surface.")),
    (re.compile(r"^/api/v2/payer"),                   ("Payers (v2)",         "Insurance carriers — v2 surface.")),
    (re.compile(r"^/api/v2/member"),                  ("Members (v2)",        "Member roster — v2 surface.")),
    (re.compile(r"^/api/v2/employer(_access)?"),      ("Employers (v2)",      "Employer roster — v2 surface.")),
    (re.compile(r"^/api/v2/vendor-tenant"),           ("Vendor Tenants (v2)", "Vendor-tenant scoped resources.")),
    (re.compile(r"^/api/v2/invoice"),                 ("Invoice Dashboard (v2)","Invoice dashboard and KPI endpoints.")),
    (re.compile(r"^/api/v2/accounts-terming"),        ("Accounts Terming (v2)","Accounts in termination.")),
    (re.compile(r"^/api/v2/mailgun-webhook"),         ("Webhooks",            "Inbound + outbound webhook plumbing.")),
    # v1 (unversioned) overrides.
    (re.compile(r"^/api/employer/[^/]+/contact"),     ("Employer Contacts",   "Per-employer contact list and CRUD.")),
    (re.compile(r"^/api/employer/[^/]+/invoice"),     ("Invoices",            "Invoices and their nested subscriptions.")),
    (re.compile(r"^/api/employer/[^/]+/subscription"),("Subscriptions",       "Subscription state and subscription lines.")),
    (re.compile(r"^/api/employer-contact"),           ("Employer Contacts",   "Per-employer contact list and CRUD.")),
    (re.compile(r"^/api/subscription"),               ("Subscriptions",       "Subscription state and subscription lines.")),
    (re.compile(r"^/api/invoice_batch"),              ("Invoice Batches",     "Grouped invoice batches.")),
    (re.compile(r"^/api/invoice"),                    ("Invoices",            "Invoices and their nested subscriptions.")),
    (re.compile(r"^/api/policy_holder"),              ("Policy Holders",      "Carrier-login records that produce claims.")),
    (re.compile(r"^/api/claim/[^/]+/tpafile"),        ("Claim Files",         "EOB images, screenshots, and other artifacts attached to claims.")),
    (re.compile(r"^/api/campaign"),                   ("Campaigns",           "Member-outreach campaigns and their attached files.")),
    (re.compile(r"^/api/outbound-task"),              ("Outbound Tasks",      "Export tasks and their attached files.")),
    (re.compile(r"^/api/webhook"),                    ("Webhooks",            "Inbound + outbound webhook plumbing.")),
    (re.compile(r"^/api/crawl"),                      ("Crawls",              "Background carrier-portal crawl runs.")),
    (re.compile(r"^/api/payer"),                      ("Payers",              "Insurance carriers and per-carrier health.")),
    (re.compile(r"^/api/organization"),               ("Organizations",       "Top-level organization resources.")),
]

def tag_for(path):
    for pat, tag in PATH_OVERRIDES:
        if pat.search(path): return tag
    parts = [p for p in path.split("/") if p and not p.startswith("{")]
    if len(parts) >= 2 and parts[0] == "api":
        seg = parts[1]
        label = seg.replace("-", " ").replace("_", " ").title()
        return (label, f"{label} endpoints.")
    return ("Other", "Endpoints that don't fit another category.")

# The upstream spec's individual operations DO carry per-operation
# tags (flask-smorest derives them from the Blueprint name), but the
# top-level `tags` array is empty so docusaurus-plugin-openapi-docs
# can't render a sidebar. Take the union of all operation tags
# (existing + our injected overrides) and write a top-level tags
# array. Our overrides take effect only on operations that arrive
# with no tags of their own.
# Synthesize operationId + summary for endpoints that don't ship one.
# docusaurus-plugin-openapi-docs needs both: operationId becomes the
# slug for the generated MDX file, summary becomes the sidebar label.
# flask-smorest emits neither by default, so endpoints without an
# explicit @blp.doc(summary=...) decoration come through bare.

METHOD_VERB = {
    "get":     "get",
    "post":    "create",
    "put":     "update",
    "patch":   "patch",
    "delete":  "delete",
    "head":    "head",
    "options": "options",
}

def humanize_path(path):
    parts = [p for p in path.split("/") if p and not p.startswith("{") and p != "api"]
    if parts and parts[0] in ("v2", "v3", "v4"):
        parts = parts[1:]
    return " ".join(p.replace("_", " ").replace("-", " ") for p in parts).strip()

def slug_path(path):
    parts = [p for p in path.split("/") if p and not p.startswith("{") and p != "api"]
    return "_".join(p.replace("-", "_") for p in parts) or "root"

for path, ops in spec.get("paths", {}).items():
    for method, op in ops.items():
        if method.startswith("x-") or method == "parameters": continue
        if not isinstance(op, dict): continue
        if not op.get("operationId"):
            op["operationId"] = f"{method}_{slug_path(path)}"
        if not op.get("summary"):
            verb = METHOD_VERB.get(method, method).capitalize()
            thing = humanize_path(path)
            op["summary"] = f"{verb} {thing}".strip() if thing else verb

DESCRIPTIONS = {}  # tag-name → description (filled as we observe)
tag_usage = set()

for path, ops in spec.get("paths", {}).items():
    derived_name, derived_desc = tag_for(path)
    DESCRIPTIONS.setdefault(derived_name, derived_desc)
    for method, op in ops.items():
        if method.startswith("x-") or method == "parameters": continue
        if not isinstance(op, dict): continue
        existing = [t for t in (op.get("tags") or []) if t]
        if not existing:
            op["tags"] = [derived_name]
            tag_usage.add(derived_name)
        else:
            for t in existing: tag_usage.add(t)

# Preserve any pre-existing top-level tag descriptions.
for tag in spec.get("tags") or []:
    if isinstance(tag, dict) and tag.get("name"):
        if tag.get("description"):
            DESCRIPTIONS.setdefault(tag["name"], tag["description"])

spec["tags"] = [
    {"name": name, "description": DESCRIPTIONS.get(name, f"{name} endpoints.")}
    for name in sorted(tag_usage)
]

with open(dst, "w") as fh:
    json.dump(spec, fh, sort_keys=True, indent=2)

print(f"INFO: injected {len(spec['tags'])} synthetic tags: " + ", ".join(t['name'] for t in spec['tags']), file=sys.stderr)
PYEOF

mv "$TAGGED" "$OUTPUT"

PATHS=$(jq -r '.paths | length' "$OUTPUT")
VERSION=$(jq -r '.info.version' "$OUTPUT")
echo "OK: wrote $OUTPUT (version=$VERSION, $PATHS paths)"
