# GraphQL Surface Design

## Status

Accepted design (2026-08-24), pending implementation.

## Contract

wrike-gateway's one-shot contract: `graphql query '<inline>' [--variables '<json>']`,
`graphql query-file <path> [--variables-file <path>]`, `graphql schema` (SDL
rendered locally from the registry), `--pretty`. Response envelope:

- success: `{"data": {...}, "extensions": {"requestId"}}`
- failure: `{"data": null, "errors": [{"message", "extensions": {"code", "exitCode"}}], "extensions": {"requestId"}}`

Engine: ported wrike-gateway subset (lexer, constrained AST, recursive-descent
parser with 64KB/10-field/depth-8 caps, runtime, SDL printer, selection
projection). Supported: named+shorthand operations, JSON variables, scalars,
enums, lists, input objects, nested selections. Rejected: fragments, aliases,
directives, subscriptions, introspection, unions, interfaces, variable defaults,
multiple operations, multi-field mutations. Unsupported syntax fails before
credential resolution or network access; widening the syntax must never widen
capability access.

## Field naming

Deterministic mapping from Google API method ids
(design-docs/references/*-methods.txt is the authoritative list):

- Namespace: `ga` for analyticsadmin + analyticsdata, `gtm` for tagmanager.
- `get` methods -> singular resource query: `analyticsadmin.properties.dataStreams.get`
  -> `gaDataStream(name: "properties/1/dataStreams/2")`.
- `list` methods -> plural resource query: `gaDataStreams(parent: "properties/1", pageSize: Int, pageToken: String)`.
- CRUD mutations -> verb + singular resource: `gaCreateDataStream(parent:, dataStream: {...})`,
  `gaUpdateDataStream(name:, dataStream: {...}, updateMask:)`, `gaDeleteDataStream(name:)`.
- Custom verbs keep their verb: `gaRunReport`, `gaRunRealtimeReport`,
  `gaCheckCompatibility`, `gaSearchChangeHistoryEvents`, `gaProvisionAccountTicket`,
  `gaAcknowledgeUserDataCollection`, `gtmPublishVersion`, `gtmSyncWorkspace`,
  `gtmQuickPreview`, `gtmCreateVersion`, `gtmRevertTag`, `gtmLookupContainer`,
  `gtmContainerSnippet`, `gtmMoveTagId`, `gtmCombineContainers`, `gtmLinkDestination`.
- Resource-path arguments mirror REST (`name`, `parent`, `path`) as strings in the
  Google resource-name format; request bodies are input objects passed through to
  the REST body after key validation.
- GTM resource paths use the API's `path` convention
  (`accounts/{a}/containers/{c}/workspaces/{w}/tags/{t}`).

Disambiguation notes:

- analyticsadmin and analyticsdata share the `ga` prefix; ids never collide
  (data methods are all custom verbs or audienceExports).
- `accounts` exists in both `ga` and `gtm` namespaces: `gaAccounts` vs `gtmAccounts`.

## Capability split (role executables)

- reader: all `get`/`list`/report/metadata/compatibility/snippet/status fields.
- writer: reader + create/update/patch/archive mutations, GTM workspace mutations,
  version create/publish/set_latest, gtag config CRUD, built-in variables.
- admin: writer + deletes, user_permissions, accessBindings (v1alpha),
  account provisioning, destinations link, combine/move_tag_id.

The reader executable rejects mutation root fields by dispatch-time capability
check (same UX as gmail-gateway's reader rejecting `sendMessage`).

## Implementation: capability registry (wrike-gateway model)

With 172 methods, per-field bespoke resolvers do not scale. Each root field is
one CapabilityDefinition value — no resolver closures:

```
CapabilityDefinition(
  id: CapabilityID("ga.dataStreams.create"),
  field: "gaCreateDataStream",
  tier: .writer, operationClass: .mutation,
  method: .post,
  service: .analyticsAdminV1Beta,
  pathTemplate: "/v1beta/{parent}/dataStreams",
  arguments: [
    ArgumentDefinition("parent", .resourceName("properties/{id}"), .path),
    ArgumentDefinition("dataStream", .inputObject("DataStreamInput"), .bodyJSON)
  ],
  result: .object(dataStream),
  scopes: .analyticsEdit
)
```

ArgumentBinding is data (.path, .query, .queryList, .bodyJSON, .page, .confirm),
interpreted by a generic RequestBuilder. The SDL printer and the request planner
read the same value, so the printed schema and executable routes cannot drift.
Registry construction validates invariants (unique fields, tier consistency,
path-template/argument agreement) and refuses above-tier definitions per target.
A test cross-checks every catalog row against the discovery dumps in
design-docs/references/.

Pagination: {nodes, pageInfo{resultCount, nextPageToken}} + page: PageInput
(wrike shape); over-limit page sizes rejected, not clamped.

Destructive/administrative mutations take a confirm argument that must
exactly echo the target resource path (e.g.
`gtmDeleteContainer(path:, confirmPath:)`); missing or mismatched confirmation
is an INVALID_ARGUMENT error before any network call.

## Swift library usage

Library products mirror the tiers: `GoogleAnalyticsGatewayRead` /
`...Write` / `...Admin`. Each exposes a runtime entry point
`GatewayRuntime.execute(document:variables:) async throws -> GraphQLResponse`
(the same path the CLIs use, constructed with that tier's registry), plus the
capability registry values, `HTTPTransport`, and the generic RequestBuilder for
direct Swift calls without GraphQL.
