# Google API Surfaces Covered by google-analytics-gateway

Source of truth: the discovery documents in this directory, fetched 2026-08-24 from the
service discovery endpoints (`https://<service>.googleapis.com/$discovery/rest?version=<v>`).
Per-method dumps live in the sibling `*-methods.txt` files (method id, HTTP verb, path).

## APIs

| API | Service | Version | Methods | Discovery file |
|-----|---------|---------|---------|----------------|
| GA4 Admin API | analyticsadmin.googleapis.com | v1beta | 55 | analyticsadmin-v1beta-discovery.json |
| GA4 Admin API (alpha extras) | analyticsadmin.googleapis.com | v1alpha | 166 | analyticsadmin-v1alpha-discovery.json |
| GA4 Data API | analyticsdata.googleapis.com | v1beta | 11 | analyticsdata-v1beta-discovery.json |
| Tag Manager API | tagmanager.googleapis.com | v2 | 106 | tagmanager-v2-discovery.json |

"Google Tag" (gtag) management has no standalone API; it is exposed through Tag Manager
API v2 resources `accounts.containers.workspaces.gtag_config` (Google tag configs) and
`accounts.containers.destinations` (Google tag destinations), plus
`accounts.containers:snippet` for retrieving the install snippet. GA4 web data streams
(Admin API `properties.dataStreams`, type WEB_DATA_STREAM) carry the `G-XXXX`
measurement id used by a direct gtag.js install.

## GA4 Admin API v1beta — resource groups

- accounts: list/get/delete/patch, provisionAccountTicket, searchChangeHistoryEvents, runAccessReport, dataSharingSettings
- accountSummaries: list
- properties: CRUD, acknowledgeUserDataCollection, runAccessReport, dataRetentionSettings
- properties.dataStreams: CRUD + measurementProtocolSecrets CRUD
- properties.customDimensions / customMetrics: CRUD + archive
- properties.conversionEvents (deprecated in favor of keyEvents) and properties.keyEvents: CRUD
- properties.firebaseLinks, properties.googleAdsLinks: CRUD

## GA4 Admin API v1alpha — notable extras beyond v1beta

audiences, audienceLists (via Data API too), accessBindings (user management),
adSenseLinks, bigQueryLinks, calculatedMetrics, channelGroups, dataRedactionSettings,
displayVideo360AdvertiserLinks(+Proposals), eventCreateRules, eventEditRules,
expandedDataSets, rollupProperties, searchAds360Links, sKAdNetworkConversionValueSchema,
subpropertyEventFilters, subpropertySyncConfigs, reportingDataAnnotations,
attributionSettings, googleSignalsSettings. See analyticsadmin-v1alpha-methods.txt.

## GA4 Data API v1beta — methods

runReport, batchRunReports, runPivotReport, batchRunPivotReports, runRealtimeReport,
checkCompatibility, getMetadata, audienceExports (create/get/list/query).

## Tag Manager API v2 — resource groups

- accounts: list/get/update, user_permissions CRUD
- accounts.containers: CRUD, combine, lookup, move_tag_id, snippet, destinations (get/list/link)
- containers.environments: CRUD + reauthorize
- containers.versions: get/live/delete/undelete/update/publish/set_latest, version_headers (list/latest)
- containers.workspaces: CRUD, create_version, quick_preview, resolve_conflict, sync, status, bulk_update, getStatus
- workspaces.tags / triggers / variables / clients / folders / templates / transformations / zones: CRUD + revert (folders also entities, move_entities_to_folder)
- workspaces.built_in_variables: create/delete/list/revert
- workspaces.gtag_config: CRUD (Google tag configurations)

## OAuth scopes

GA4 Admin v1beta: analytics.edit, analytics.readonly
GA4 Admin v1alpha adds: analytics.manage.users, analytics.manage.users.readonly
GA4 Data v1beta: analytics, analytics.readonly
Tag Manager v2: tagmanager.readonly, tagmanager.edit.containers, tagmanager.delete.containers,
tagmanager.edit.containerversions, tagmanager.publish, tagmanager.manage.accounts,
tagmanager.manage.users

Role-split executables map to scope sets:

- reader: analytics.readonly, tagmanager.readonly
- writer: analytics.edit, analytics, tagmanager.edit.containers, tagmanager.edit.containerversions, tagmanager.publish
- admin: all of the above + analytics.manage.users(.readonly), tagmanager.manage.accounts, tagmanager.manage.users, tagmanager.delete.containers
