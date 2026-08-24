# End-to-End Verification via Konjac Page Tag

**Status**: Pending (blocked on capability-registries)
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
