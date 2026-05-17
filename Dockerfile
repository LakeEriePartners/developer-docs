# syntax=docker/dockerfile:1.7

# ─── 1. Build stage ────────────────────────────────────────────────────────
FROM node:22-alpine AS build

# git is needed for scripts/clone-sdk-docs.sh at build time;
# python3 is needed for the script's sidebar generator and
# scripts/sync-openapi.sh's spec post-processor;
# curl + jq are needed for scripts/sync-openapi.sh to fetch + validate
# the live OpenAPI spec.
RUN apk add --no-cache git python3 bash curl jq

WORKDIR /app

# Install deps first for layer caching.
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Copy the rest of the source.
COPY . .

# Build args:
#   SDK_REF      pin a non-default git ref for the SDK docs clone
#                (default: latest semver tag of stream-connect-js-sdk)
#   OPENAPI_URL  override the OpenAPI base URL (default: prod)
ARG SDK_REF=""
ARG OPENAPI_URL="https://app.tpastream.com"
ENV SDK_REF=${SDK_REF}

# `npm run build` chains prebuild → sync-openapi.sh +
# clone-sdk-docs.sh + `docusaurus gen-api-docs all`, then runs
# `docusaurus build`. The OpenAPI spec is fetched live every time;
# stream's image bakes the merged Flask + FastAPI spec in at its own
# build time, so what we fetch here is deterministic per stream
# deploy.
RUN OPENAPI_BASE_URL=$OPENAPI_URL npm run build

# ─── 2. Runtime stage ──────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Drop the default site config; we own /etc/nginx/nginx.conf entirely
# so the server block, redirect map, and healthz endpoint stay in one
# file.
RUN rm -f /etc/nginx/conf.d/default.conf

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/build /usr/share/nginx/html

# Run nginx in the foreground; logs already go to stdout/stderr via
# the conf. Listen on 8080 so we can run as a non-privileged user.
EXPOSE 8080

# Permissions: the nginx process drops to user `nginx` (uid 101) for
# workers, but the master needs to read static files. Reset ownership
# so non-root reads work even if a sidecar / GKE PSP rebinds runAsUser.
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    touch /tmp/nginx.pid && chown nginx:nginx /tmp/nginx.pid

USER nginx

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
