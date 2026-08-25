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

## Tag Manager v2 — pending one manual step

- GTM has no API for account creation; the signup requires ToS + GDPR
  acceptance, which the automation policy leaves to a human. Once the account
  exists, the planned live cycle is: gtmCreateContainer -> gtmWorkspaces ->
  gtmCreateVariable/Trigger/Tag (GA4 config tag) -> gtmCreateVersion ->
  gtmPublishVersion -> gtmContainerSnippet -> reads (containers, versions,
  version_headers live/latest) -> cleanup deletes.
