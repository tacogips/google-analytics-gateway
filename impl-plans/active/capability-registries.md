# Capability Registries: GA4 Admin, GA4 Data, Tag Manager, Google Tag

**Status**: Pending (blocked on gateway-foundation)
**Design Reference**: `design-docs/specs/graphql-schema.md`, `design-docs/references/google-api-surfaces.md`
**Created**: 2026-08-24

## Purpose

Cover the full researched API surface as CapabilityDefinitions across the three
tiers: GA4 Admin v1beta (55 methods), GA4 Data v1beta (11), Tag Manager v2
(106, including gtag_config/destinations/snippet = Google tag). GA4 Admin
v1alpha extras follow as a later phase.

## Deliverables

- [ ] Read tier: all get/list/report/metadata/compatibility/snippet/status
      fields for ga + gtm namespaces
- [ ] Write tier: creates/updates/patches/archives, GTM workspace entity
      mutations, create_version/publish/set_latest, gtag_config CRUD,
      built-in variables, measurement protocol secrets
- [ ] Admin tier: deletes (with confirm arguments), user_permissions,
      provisionAccountTicket, destinations link, combine/move_tag_id,
      environments reauthorize
- [ ] SDL schema renders for each tier; catalog cross-check test against the
      discovery method dumps (no missing/extra methods vs the coverage list)
- [ ] Wire-level request tests per resource group (recording transport,
      exact URL/method/body assertions)
- [ ] README usage examples for reader/writer/admin GraphQL invocations

## Tasks

### TASK-001: ga namespace read definitions (admin v1beta reads + data API)
### TASK-002: gtm namespace read definitions
### TASK-003: ga write definitions
### TASK-004: gtm write definitions (workspace entities, versions, publish, gtag_config)
### TASK-005: admin tier definitions (both namespaces, confirm arguments)
### TASK-006: discovery cross-check test + SDL snapshot tests
### TASK-007: adversarial review + full verification

Each task: **Parallelizable**: Yes within its tier once the framework API is
stable; **Write scope**: its tier target's registry files + matching test files.

## Progress Log

- 2026-08-24: Plan created.
- 2026-08-24: All 172 fields registered and verified: reader 70 (GA 34 incl.
  gaSearchChangeHistoryEvents on analyticsEdit per discovery; GTM 36 with
  local-only page bound 300, gtmDestinations as plain list), writer 68 (GA 22
  with required updateMask on all patches, separate create/update inputs,
  audienceExport documented-scope pair; GTM 46 with fingerprint args and
  per-method publish/containerversions scopes), admin 34 (23 deletes with
  required confirm arguments, user-permission reads as admin-tier GETs —
  Core coherence rule relaxed accordingly, adminQueryFields added to
  CapabilityCatalog). Every agent ran scripted cross-checks against
  field-catalog.json: zero mismatches. Build green, 218 tests green.
  Behavioral spot-checks: CAPABILITY_DENIED across tiers,
  validation-before-credentials, confirm-argument enforcement all correct.
  Remaining: TASK-007 adversarial review (with foundation TASK-007).
- 2026-08-24 (second pass): GA4 Admin v1alpha extras registered — 111 fields
  (reader 39, writer 39, admin 33 incl. access bindings with batch operations
  and admin-tier reads). Surface now 283 fields, all cross-checked against
  discovery. Fixed live planner defect: confirmation echo matched only
  .string while confirms are .resourceName-typed (all deletes were
  unexecutable); regression suite ConfirmationEchoTests added. Catalog tables:
  107 writer mutations, 59 admin mutations, 8 admin query fields. 261 tests
  in 24 suites green (incl. link-boundary and end-to-end CLI suites), lint 0.
  Committed as 238aff9.
