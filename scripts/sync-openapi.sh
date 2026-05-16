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

METHOD_VERB_COLLECTION = {  # path ends in resource (no trailing param)
    "get":     ("list",   "List"),
    "post":    ("create", "Create"),
    "put":     ("update", "Update"),
    "patch":   ("patch",  "Patch"),
    "delete":  ("delete", "Delete"),
    "head":    ("head",   "Head"),
    "options": ("options","Options"),
}
METHOD_VERB_ITEM = {        # path ends in {param}
    "get":     ("get",    "Get one"),
    "post":    ("create", "Create on"),
    "put":     ("update", "Update"),
    "patch":   ("patch",  "Patch"),
    "delete":  ("delete", "Delete"),
    "head":    ("head",   "Head"),
    "options": ("options","Options"),
}

def path_segments(path, drop_params=True):
    out = []
    for p in path.split("/"):
        if not p: continue
        if p == "api": continue
        if drop_params and p.startswith("{"): continue
        out.append(p)
    return out

def is_item_path(path):
    """A path like /api/foo/{id} is item-scoped; /api/foo is collection-scoped."""
    tail = path.rstrip("/").rsplit("/", 1)[-1]
    return tail.startswith("{") and tail.endswith("}")

def humanize_path(path):
    segs = path_segments(path, drop_params=True)
    if segs and segs[0] in ("v2", "v3", "v4"):
        segs = segs[1:]
    return " ".join(p.replace("_", " ").replace("-", " ") for p in segs).strip()

def slug_for_op(path, method):
    """
    Disambiguate list vs item endpoints by encoding all path params
    into the slug. /api/invoice → get_invoice; /api/invoice/{invoice_id} →
    get_invoice_by_invoice_id. Nested params chain naturally:
    /api/employer/{employer_id}/invoice/{invoice_id} → get_employer_invoice_by_employer_id_and_invoice_id.
    """
    fixed = []
    params = []
    for p in path.split("/"):
        if not p or p == "api": continue
        if p.startswith("{") and p.endswith("}"):
            params.append(p[1:-1].replace("-", "_"))
        else:
            fixed.append(p.replace("-", "_"))
    base = f"{method}_{'_'.join(fixed) or 'root'}"
    if params:
        base += "_by_" + "_and_".join(params)
    return base

for path, ops in spec.get("paths", {}).items():
    item_scoped = is_item_path(path)
    for method, op in ops.items():
        if method.startswith("x-") or method == "parameters": continue
        if not isinstance(op, dict): continue
        if not op.get("operationId"):
            op["operationId"] = slug_for_op(path, method)
        if not op.get("summary"):
            verbs = METHOD_VERB_ITEM if item_scoped else METHOD_VERB_COLLECTION
            _, label_verb = verbs.get(method, (method, method.capitalize()))
            thing = humanize_path(path)
            op["summary"] = f"{label_verb} {thing}".strip() if thing else label_verb

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
