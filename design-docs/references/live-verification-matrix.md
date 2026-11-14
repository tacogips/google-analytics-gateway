# Live Verification Matrix

> Concrete resource identifiers live outside git in
> `design-docs/references/live-verification.private.md`.


Live API verification against Google, 2026-08-24, using the production
binaries with the `analytics-writer` profile (writer scopes; admin binary used
where a field is admin-tier — GA deletes accept the `analytics.edit` scope the
writer credential carries). Assets: GA account `accounts/<ACCOUNT_ID>`, property
`properties/<PROPERTY_ID>` (konjac-note), stream `dataStreams/<STREAM_ID>`
(G-<MEASUREMENT_ID>).

## Static coverage

- Discovery method dumps vs registered fields vs printed schema: **283/283**,
  zero missing, zero extra (`field-catalog.json` +
  `field-catalog-v1alpha-extras.json` against the admin binary's SDL).

## GA4 Data API v1beta — 11/11 methods live-verified

| Field | Result |
|---|---|
| gaRunReport | OK (empty rows on new property — valid) |
| gaBatchRunReports | OK |
| gaRunPivotReport | OK |
| gaBatchRunPivotReports | OK |
| gaRunRealtimeReport | OK — detected the real konjac-note.com visit (activeUsers 1, screenPageViews 1, unifiedScreenName "Konjac") |
| gaCheckCompatibility | OK (COMPATIBLE verdicts) |
| gaMetadata | OK (full dimension/metric catalog) |
| gaCreateAudienceExport | OK (operation returned; export reached ACTIVE) |
| gaAudienceExport | OK (state ACTIVE) |
| gaAudienceExports | OK |
| gaQueryAudienceExport | OK (rowCount 0 on fresh property) |

## GA4 Admin API — representative live CRUD

| Field | Result |
|---|---|
| gaAccountSummaries / gaAccounts / gaProperty | OK |
| gaCreateProperty | OK (created properties/<PROPERTY_ID>) |
| gaUpdateProperty (updateMask) | OK |
| gaCreateDataStream (WEB) | OK (measurement id G-<MEASUREMENT_ID>) |
| gaCreateCustomDimension / gaCustomDimensions / gaArchiveCustomDimension | OK |
| gaCreateKeyEvent / gaKeyEvents / gaDeleteKeyEvent (confirmName) | OK |
| gaAcknowledgeUserDataCollection | OK — discovered prerequisite: measurement protocol secrets cannot be created before this acknowledgement |
| gaCreateMeasurementProtocolSecret / gaDeleteMeasurementProtocolSecret | OK (after acknowledgement) |
| gaDataRetentionSettings get / gaUpdateDataRetentionSettings | OK (TWO_MONTHS -> FOURTEEN_MONTHS) |
| gaSearchChangeHistoryEvents | OK (returned real USER change events) |
| gaDeleteProperty (confirmName) | OK (removed the signup-wizard placeholder properties/<PLACEHOLDER_PROPERTY_ID>) |
| gaAudiences (v1alpha) | OK (default audiences listed) |
| gaAttributionSettings / gaGoogleSignalsSettings (v1alpha) | OK |
| gaRunPropertyAccessReport / gaRunAccountAccessReport | ROUTE VERIFIED — request reaches Google, which answers 400 INVALID_ARGUMENT on this same-day-created account; the gateway surfaces the sanitized error with recovery guidance. Retry after the account accrues access-log history. |

## Google tag (gtag) — end-to-end

- Web stream provisioned by the gateway; measurement id embedded in
  konjac pubpage (first-party bootstrap); deployed to https://konjac-note.com.
- Headless Chromium: gtag.js 200, /g/collect POST 204.
- gateway gaRunRealtimeReport returned the visit. VERIFIED.

## Tag Manager v2 — live cycle verified (2026-08-25)

After the user approved the GTM ToS: gtmAccounts, gtmContainers,
gtmCreateContainer (new container via API), gtmWorkspaces,
gtmContainerSnippet, gtmCreateVariable (constant measurement id),
gtmCreateTrigger (pageview), gtmCreateTag (googtag referencing the variable,
firing trigger bound), gtmWorkspaceStatus (3 added changes),
gtmCreateVersion, gtmPublishVersion, gtmLiveVersion, gtmLatestVersionHeader,
gtmVersionHeaders, gtmVersion — all OK against Google. A headless Chromium
page carrying the container snippet then fired gtm.js (200) -> the published
GA4 tag loaded gtag.js (200) -> /g/collect (204). Live-flow fix: entities
embedded in a ContainerVersion are returned without their path, so the
required marker was relaxed across GTM entity shapes.

## GA4 Data API v1alpha — 13/13 registered, spot-verified live (2026-08-25)

runFunnelReport returned real funnel step data (the verification visits),
propertyQuotasSnapshot returned live token quota (after relaxing the name
requiredness Google omits), reportTasks and recurringAudienceLists lists OK.
Coverage after this addition: 296/296 fields against the discovery documents.
