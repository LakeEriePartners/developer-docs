#!/usr/bin/env bash
# Clone TPAStream/stream-connect-js-sdk at the latest git tag, copy
# its docs/ tree into docs/sdk/, and generate docs/sdk/sidebar.ts so
# the SDK section renders in the Docusaurus build.
#
# Runs at Docker build time (see Dockerfile sdk-docs stage), and can
# be run locally before `npm run start` to preview the SDK section.
#
# Env:
#   SDK_REPO         Default: https://github.com/TPAStream/stream-connect-js-sdk
#   SDK_REF          Default: latest git tag (resolved via ls-remote --tags --sort=-v:refname)
#                    Override to a branch ("0.8.0-react19-tailwind") or commit sha.
#   SDK_DOCS_SUBDIR  Default: docs (the path inside the SDK repo)
set -euo pipefail

SDK_REPO="${SDK_REPO:-https://github.com/TPAStream/stream-connect-js-sdk}"
SDK_DOCS_SUBDIR="${SDK_DOCS_SUBDIR:-docs}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_DEST="$ROOT/docs/sdk"

resolve_ref() {
  if [ -n "${SDK_REF:-}" ]; then
    echo "$SDK_REF"
    return
  fi
  # Latest semver tag; falls back to "master" if no tags exist.
  local tag
  tag=$(git ls-remote --tags --sort=-v:refname "$SDK_REPO" 2>/dev/null \
        | awk -F/ '!/\^\{\}$/ {print $NF}' \
        | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' \
        | head -n1 || true)
  echo "${tag:-master}"
}

mkdir -p "$SDK_DEST"

write_fallback() {
  local reason="$1"
  echo "WARN: $reason; writing fallback stub to $SDK_DEST" >&2
  cat > "$SDK_DEST/index.md" <<'EOF'
---
title: Connect SDK Reference
sidebar_label: Overview
slug: /sdk/
---

# Connect SDK Reference

This page is normally populated at build time from
[`stream-connect-js-sdk`](https://github.com/TPAStream/stream-connect-js-sdk).
The build-time clone did not run or failed; once it runs successfully
this content is replaced with the SDK's own docs tree at the pinned
release.
EOF
  cat > "$SDK_DEST/sidebar.ts" <<'EOF'
// Fallback stub. Re-run scripts/clone-sdk-docs.sh to populate.
const sidebar = ["sdk/index"];
module.exports = sidebar;
EOF
}

REF="$(resolve_ref || true)"
if [ -z "$REF" ]; then
  write_fallback "could not resolve a ref for $SDK_REPO"
  exit 0
fi
echo "Cloning $SDK_REPO at $REF"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! git clone --depth=1 --branch "$REF" "$SDK_REPO" "$TMP/sdk" 2>&1 | tail -5; then
  write_fallback "git clone failed for $SDK_REPO@$REF"
  exit 0
fi

SRC="$TMP/sdk/$SDK_DOCS_SUBDIR"
if [ ! -d "$SRC" ]; then
  echo "ERROR: $SDK_DOCS_SUBDIR/ not found in cloned SDK repo" >&2
  exit 1
fi

# Wipe previously-cloned SDK content (the whole subtree is gitignored).
rm -rf "$SDK_DEST"
mkdir -p "$SDK_DEST"

# Copy everything from the SDK docs/ tree (markdown + screenshot subdirs).
cp -R "$SRC/." "$SDK_DEST/"

# Rewrite markdown links of the form `../something-outside-docs/...`
# to absolute GitHub blob URLs at the cloned ref. The SDK docs link
# to sibling source files (../assets/sdk/types.ts) and to the
# sibling sdk-hook package (../sdk-hook/docs/README.md) — those work
# on github.com but resolve to /assets/... / /sdk-hook/... inside
# our build, which 404s. Intra-docs links (./foo.md,
# ./screenshots/x.png) are left alone.
SDK_REPO_PATH="$(echo "$SDK_REPO" | sed -E 's|^https?://github.com/||; s|\.git$||')"
GH_BLOB_BASE="https://github.com/${SDK_REPO_PATH}/blob/${REF}"
python3 - "$SDK_DEST" "$GH_BLOB_BASE" <<'PYEOF'
import os, re, sys

dest, gh_base = sys.argv[1], sys.argv[2]
# Match Markdown links: [text](../path/to/thing[#anchor]).
# Skip ./… (intra-docs), absolute URLs, anchors-only.
link_re = re.compile(r'(\[[^\]]*\]\()(\.\./[^)\s#]+)((?:#[^)\s]+)?\))')

rewrites = 0
for root, _, files in os.walk(dest):
    for name in files:
        if not (name.endswith(".md") or name.endswith(".mdx")):
            continue
        path = os.path.join(root, name)
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        def repl(m):
            global rewrites
            target = m.group(2)[3:]  # strip the leading ../
            rewrites += 1
            return f"{m.group(1)}{gh_base}/{target}{m.group(3)}"
        new = link_re.sub(repl, src)
        if new != src:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new)

print(f"rewrote {rewrites} ../ link(s) to {gh_base}")
PYEOF

# README.md (SDK convention) → index.md (Docusaurus convention).
if [ -f "$SDK_DEST/README.md" ]; then
  mv "$SDK_DEST/README.md" "$SDK_DEST/index.md"
fi

# Synthesize an index if the SDK doesn't ship a docs/README.md (older
# SDK releases — the README went into docs/ in the 0.8 cycle).
if [ ! -f "$SDK_DEST/index.md" ]; then
  cat > "$SDK_DEST/index.md" <<EOF
---
title: Connect SDK Reference
sidebar_label: Overview
slug: /sdk/
---

# Connect SDK Reference

Reference for the [Stream Connect JavaScript SDK](https://github.com/TPAStream/stream-connect-js-sdk)
at \`$REF\`. The sidebar on the left lists every topic shipped at this
version. Start with **Quickstart** if you're integrating for the
first time.
EOF
fi

# Inject frontmatter if missing so the SDK's own README renders with
# our canonical title / slug.
if ! head -1 "$SDK_DEST/index.md" | grep -q '^---'; then
  TMP_INDEX="$(mktemp)"
  cat > "$TMP_INDEX" <<'EOF'
---
title: Connect SDK Reference
sidebar_label: Overview
slug: /sdk/
---

EOF
  cat "$SDK_DEST/index.md" >> "$TMP_INDEX"
  mv "$TMP_INDEX" "$SDK_DEST/index.md"
fi

# Generate sidebar.ts. Manifest controls order; missing files are
# skipped so the script works against older SDK tags too.
generate_sidebar() {
  local out="$SDK_DEST/sidebar.ts"
  python3 - "$SDK_DEST" "$out" <<'PYEOF'
import os, sys, re

dest = sys.argv[1]
out = sys.argv[2]

# Desired order. Items prefixed with "+" are headings (categories);
# anything indented under a heading is checked for existence on disk
# and emitted in that order.
spec = [
    ("Getting Started", [
        "quickstart",
        "migration-0.7-to-0.8",
        "client-usage",
    ]),
    ("Feature deep dives", [
        "sdk-flow",
        "theme",
        "two-factor",
        "fix-credentials",
        "interop",
    ]),
    ("Security", [
        "connect-access-token",
    ]),
    ("Reference", [
        "error",
        "faq",
    ]),
]

def exists(slug):
    return os.path.isfile(os.path.join(dest, slug + ".md")) or \
           os.path.isfile(os.path.join(dest, slug + ".mdx"))

def label(slug):
    # Best-effort: prefer the file's first H1 if frontmatter is absent.
    for ext in (".md", ".mdx"):
        p = os.path.join(dest, slug + ext)
        if not os.path.isfile(p): continue
        with open(p, encoding="utf-8") as fh:
            in_fm = False
            for i, line in enumerate(fh):
                if i == 0 and line.strip() == "---":
                    in_fm = True
                    continue
                if in_fm and line.strip() == "---":
                    in_fm = False
                    continue
                if in_fm:
                    m = re.match(r'^(?:sidebar_label|title):\s*"?([^"#\n]+?)"?\s*$', line)
                    if m: return m.group(1).strip()
                else:
                    m = re.match(r'^#\s+(.+?)\s*$', line)
                    if m: return m.group(1).strip()
    # Fallback: humanize slug.
    return slug.replace("-", " ").replace("_", " ").title()

items = ['  "sdk/index",']
for cat, slugs in spec:
    children = [s for s in slugs if exists(s)]
    if not children: continue
    items.append('  {')
    items.append(f'    type: "category",')
    items.append(f'    label: "{cat}",')
    items.append( '    collapsed: false,')
    items.append( '    items: [')
    for slug in children:
        items.append(f'      {{ type: "doc", id: "sdk/{slug}", label: "{label(slug)}" }},')
    items.append( '    ],')
    items.append('  },')

# Catch-all for any markdown files the manifest doesn't enumerate.
known = {s for _, slugs in spec for s in slugs} | {"index"}
extras = []
for name in sorted(os.listdir(dest)):
    base, ext = os.path.splitext(name)
    if ext not in (".md", ".mdx"): continue
    if base in known: continue
    extras.append(base)
if extras:
    items.append('  {')
    items.append('    type: "category",')
    items.append('    label: "Other",')
    items.append('    collapsed: true,')
    items.append('    items: [')
    for slug in extras:
        items.append(f'      {{ type: "doc", id: "sdk/{slug}", label: "{label(slug)}" }},')
    items.append('    ],')
    items.append('  },')

with open(out, "w", encoding="utf-8") as fh:
    fh.write('// Generated by scripts/clone-sdk-docs.sh from the SDK repository.\n')
    fh.write('// Do not edit by hand; re-run the script to refresh.\n')
    fh.write('import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";\n\n')
    fh.write('const sidebar: SidebarsConfig["sdkSidebar"] = [\n')
    fh.write('\n'.join(items) + '\n')
    fh.write('];\n\n')
    fh.write('module.exports = sidebar;\n')

print(f"wrote {out}")
PYEOF
}

generate_sidebar
echo "SDK docs synced from $REF"
