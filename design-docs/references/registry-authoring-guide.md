# Capability Registry Authoring Guide

Normative for the Read/Write/Admin registry modules (2026-08-24). Read together
with specs/graphql-schema.md and references/field-catalog.json (the
authoritative field list: field name, method id, HTTP verb, path, service,
tier — all 172 must be registered, none renamed).

## Where definitions live

- Sources/GoogleAnalyticsGatewayRead/GA/ — ga* reader fields (GAReadCapabilities)
- Sources/GoogleAnalyticsGatewayRead/GTM/ — gtm* reader fields (GTMReadCapabilities)
- Sources/GoogleAnalyticsGatewayWrite/GA|GTM/ — writer fields (GAWriteCapabilities, GTMWriteCapabilities)
- Sources/GoogleAnalyticsGatewayAdmin/GA|GTM/ — admin fields (GAAdminCapabilities, GTMAdminCapabilities)

The per-namespace enums already exist with empty `all` arrays; replace them.
Group definitions by resource into files under the namespace directory
(e.g. GA/PropertyCapabilities.swift, GTM/TagCapabilities.swift), each exposing
`static let all: [CapabilityDefinition]`, and make the namespace enum's `all`
concatenate them. Aggregators (ReadCapabilities etc.) are owned by the
integrator — do not edit them.

Shared model shapes: reader modules own the resource ModelShapes in
GA/GAModels.swift and GTM/GTMModels.swift (public enums with static ModelShape
values, e.g. `GAModels.property`, `GTMModels.tag`). Writer/admin modules import
GoogleAnalyticsGatewayRead and reuse them; writer-only input shapes live in the
writer module.

## Authoring rules

- CapabilityID: "<namespace>.<resource>.<verb>" derived from the method id
  minus the service prefix, e.g. `ga.properties.get`, `gtm.tags.create`.
- pathTemplate: the discovery `flatPath` with `{parent}`/`{name}`/`{path}`
  placeholders bound by `.path` arguments; template must start with the
  service's prefix (/v1beta, /tagmanager/v2) — registration enforces this.
- Resource-name arguments use `.resourceName(ResourceNamePattern(...))` with the
  documented pattern (e.g. "properties/{property}/dataStreams/{dataStream}").
- list fields: `result: .connection(collection: "<upstreamKey>", shape)`,
  `maximumPageSize` from the discovery doc (default 200 for GA admin, 300 for
  GTM list caps unless documented otherwise; if the doc gives no cap use 1000),
  plus an ArgumentDefinition("page", .page, .page).
- get fields: `.single(shape)`. Custom POST reads (runReport etc.):
  `.single(shape)` or `.payload` per response shape.
- create/update: request body via `.bodyRoot` input object argument named after
  the resource (e.g. `dataStream`), `updateMask` as `.query("updateMask")`
  string argument on PATCH methods that document it.
- deletes (admin): `result: .deletion`, one confirm argument
  ArgumentDefinition("confirmName" or "confirmPath", .resourceName(same pattern), .confirm("name"))
  where .confirm names the path argument it must echo.
- Open-ended structures use the JSON passthrough: model fields
  `ModelField("parameter", .json)`; arguments
  ArgumentDefinition("requestBody", .json, .bodyRoot) is NOT allowed — .json
  arguments must bind to .bodyJSON/.bodyRoot keys per the framework rule, and
  keep top-level well-known scalars typed where practical. For report requests
  (runReport etc.) model the body as an inputObject with typed common fields
  (dateRanges, dimensions, metrics, limit, offset) and .json fields for
  filter expressions and other open trees.
- Model shapes: type every documented top-level field of the resource from the
  discovery JSON (name/upstream identical unless Google uses snake_case);
  use .resourceName for `name`/`path`/`parent` style fields, .dateTime for
  RFC3339 timestamps, .json for recursive/open substructures (GTM parameter,
  report rows, filter expressions). Mark `name`/`path` required where Google
  always returns it.
- scopes: ScopeRequirement presets from CapabilityIdentity (analyticsReadonly,
  analyticsEdit, tagManagerReadonly, tagManagerEditContainers,
  tagManagerEditContainerVersions, tagManagerPublish,
  tagManagerDeleteContainers, tagManagerManageAccounts, tagManagerManageUsers,
  analyticsManageUsers...). Choose the preset matching the discovery doc's
  scopes for that method (the preset's accepted list was derived from the
  discovery docs).
- status: .implemented. summary: one sentence, Google-doc wording.
- Every field name, verb, path, and service MUST match field-catalog.json
  exactly; the coherence test cross-checks the catalog against the registries.

## Verification expected from each registry agent

- `swift build` green.
- A registry construction smoke test in the tests target is owned by the
  test-suite agent; your module must at minimum construct via
  `try CapabilityRegistry(tier:definitions:)` in a small executable check or
  the existing tests. Report any framework limitation you hit instead of
  working around it silently.
