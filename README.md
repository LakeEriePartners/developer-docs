# TPA Stream Developer Documentation

Source for [developers.tpastream.com](https://developers.tpastream.com).

Built with [Docusaurus](https://docusaurus.io) and
[`docusaurus-plugin-openapi-docs`](https://github.com/PaloAltoNetworks/docusaurus-openapi-docs).
Served from a single nginx pod in the `developer-docs` namespace on
the prod GKE cluster (see
`stream-infrastructure/modules/k8s-infrastructure/modules/developer-docs/`).

## What goes into the site

Three sources feed the build:

| Source | Mechanism |
|---|---|
| Narrative docs in `docs/` | Authored here in MDX. |
| REST API reference | `scripts/sync-openapi.sh` fetches the live `https://app.tpastream.com/openapi.json` at every build → post-processes (synthesizes `operationId`/`summary`/`tags` for the parts of the spec flask-smorest emits bare) → `docusaurus-plugin-openapi-docs` renders per-endpoint pages with try-it-out. The live spec is itself the merged Flask + FastAPI spec, baked into stream's image at its own build time. |
| Connect SDK reference | `scripts/clone-sdk-docs.sh` clones `TPAStream/stream-connect-js-sdk` at the latest git tag and copies its `docs/` tree into `docs/sdk/` at build time. |

## Local development

```bash
npm install
npm run start        # http://localhost:3000
```

`npm run start` and `npm run build` both run a `prebuild` step that:

1. Fetches the live OpenAPI spec (graceful no-op if you've fetched once before and the network is now unreachable).
2. Clones the latest SDK tag and regenerates `docs/sdk/`.
3. Runs `docusaurus gen-api-docs all` to materialize the API reference pages.

To preview an unreleased SDK branch:

```bash
SDK_REF=0.8.0-react19-tailwind npm run sync-sdk-docs
npm run start
```

To preview against a non-prod OpenAPI source (a staging webapp, a `kubectl port-forward`, etc.):

```bash
OPENAPI_BASE_URL=https://staging.example.com npm run start
```

## Docker

```bash
docker build -t developer-docs .
docker run --rm -p 8080:8080 developer-docs
# → http://localhost:8080
```

Build args:

- `SDK_REF=<git-ref>` — pin a specific SDK ref instead of the latest
  tag (useful for testing an unreleased branch in CI).
- `OPENAPI_URL=https://staging-host` — point the spec fetch at a
  non-prod host. Defaults to `https://app.tpastream.com`.

## Production

Pushes to `master` trigger
`google_cloudbuild_trigger.developer_docs_master` in
`stream-infrastructure/modules/build/`, which builds the image,
pushes to Artifact Registry, and rolls the `developer-docs`
Deployment in the GKE `developer-docs` namespace.
