# End-to-End Verification via Konjac Page Tag

> Concrete resource identifiers live outside git in
> `design-docs/references/live-verification.private.md`.


**Status**: Complete; end-to-end verification passed 2026-08-24
**Design Reference**: `design-docs/references/konjac-pubpage-deploy.md`
**Created**: 2026-08-24

## Purpose

Prove the gateway end-to-end: obtain/create a GA4 property + web data stream
(and optionally a GTM container) through the gateway's GraphQL surface, embed
the resulting tag in the konjac product page, deploy to https://konjac-note.com,
and observe hits via `gaRunRealtimeReport` through the gateway.

## Tasks

### TASK-001: Credentials bootstrap
- Google Cloud project with Analytics Admin/Data + Tag Manager APIs enabled and
  a desktop OAuth client; store secrets in kinko; `auth login` for writer/admin
  profiles. Use Codex computer use for any Google browser-UI steps that have no
  API (e.g. first GA account creation/consent).

### TASK-002: Provision GA4 assets via the gateway
- `gaCreateProperty` (or reuse), `gaCreateDataStream` (WEB) for
  https://konjac-note.com -> measurement id G-XXXX. Optionally GTM container +
  gtag_config + publish for the GTM route.

### TASK-003: Embed tag in konjac pubpage
- Inject gtag bootstrap from `pubpage/src/main.js`; extend CSP script-src/
  connect-src in `pubpage/public/_headers` (preserve validator-required keys);
  keep validate-build.mjs passing; update konjac PRIVACY.md + product-page spec.

### TASK-004: Deploy and verify
- `mise run page:check` then `mise run page:deploy`; generate page views;
  verify via `gaRunRealtimeReport` through google-analytics-gateway-reader;
  record evidence in this plan.

## Progress Log

- 2026-08-24: Plan created.

## Completion Evidence (2026-08-24)

- TASK-001: Desktop OAuth client created in ai-tools-proj (console via Codex
  computer use after user passkey); writer profile authorized with the five
  writer scopes; oauth-client.json + token-store-writer.json live under
  ~/.config/google-analytics-gateway/ and are stored in the kinko vault
  (GOOGLE_ANALYTICS_GATEWAY_OAUTH_CLIENT_JSON /
  GOOGLE_ANALYTICS_GATEWAY_TOKEN_STORE_WRITER_JSON, repo path scope).
- TASK-002: GA account "tacogips" (accounts/<ACCOUNT_ID>) via signup wizard
  (browser, Codex); property konjac-note (properties/<PROPERTY_ID>, Asia/Tokyo,
  JPY) and WEB data stream properties/<PROPERTY_ID>/dataStreams/<STREAM_ID>
  (measurement id G-<MEASUREMENT_ID>, defaultUri https://konjac-note.com) created
  through the gateway: gaCreateProperty + gaCreateDataStream.
- TASK-003: konjac feature/ga4-analytics-tag (a2c96c9 bootstrap + CSP +
  privacy/spec, 0ec99bd measurement id); build + validate-build.mjs pass.
- TASK-004: `mise run page:deploy` -> Worker version
  <WORKER_VERSION> serving konjac-note.com; served bundle
  contains G-<MEASUREMENT_ID> and the CSP allowlists the GA origins. Headless
  Chromium visit: gtag.js 200, /g/collect POST 204, window.gtag function,
  dataLayer length 4. Gateway verification: gaRunRealtimeReport on
  properties/<PROPERTY_ID> returned rowCount 1, unifiedScreenName "Konjac",
  activeUsers 1, screenPageViews 1 (requestId
  <REQUEST_ID>).
- Callback-validator fixes required by the live flow are in commit b716815.
- Observation for konjac (pre-existing, unrelated): Cloudflare Insights'
  beacon.min.js is blocked by the page CSP (script-src lacks
  static.cloudflareinsights.com).

Plan complete.
