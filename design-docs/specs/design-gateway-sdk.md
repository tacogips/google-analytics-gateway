# Design: `GoogleAnalyticsGatewaySDK` facade on `GatewaySDKKit`

## Status and authority

Accepted design for issue-resolution workflow
`codex-design-and-implement-review-loop-session-91`, intake communication
`comm-001040`, on branch `feat/gateway-sdk` at intake HEAD `b287056`.

The package brief at `design-docs/briefs/gateway-sdk-2026-09-04.md` is the
feature contract. Sections 2 and 3.2 of
`/Users/taco/gits/tacogips/riela/docs/briefs/gateway-sdk-2026-09-04.md` define
the cross-gateway architecture. The implemented shared API is documented by
`/Users/taco/gits/tacogips/gateway-sdk-kit/README.md` and its package brief.
`GatewaySDKKit` is a read-only reference for this work package.

This is exactly phase 1b: one tier-safe SDK facade, catalog export, cumulative
tier aggregates, named-operation and raw GraphQL execution, schema search, CLI
integration, tests, and documentation. It does not change capability
definitions, authentication, transport, Google host policy, packaging, or the
existing GraphQL language. It must not modify
`/Users/taco/gits/tacogips/gateway-sdk-kit` or the forbidden main checkout at
`/Users/taco/gits/tacogips/google-analytics-gateway`.

## Package and module boundary

`Package.swift` adds `.package(path: "../../gateway-sdk-kit")` with a comment
that a later operator-owned publication phase replaces the path with a URL and
revision pin. Only `GoogleAnalyticsGatewayCore` directly depends on the
`GatewaySDKKit` product. Tier modules and executables continue to depend on the
same lower-tier modules as today.

The shared kit contains no Google Analytics capability definitions. Linking it
through Core therefore adds catalog and request-building machinery without
adding writer or admin operations to a lower-tier binary. Existing manifest and
linked-symbol boundary checks remain mandatory.

## Cumulative capability composition

Capability deltas remain available under their existing names:

- `ReadCapabilities.all` is the reader set.
- `WriteCapabilities.all` remains the writer-only delta.
- `AdminCapabilities.all` remains the admin-only delta.

The additive aggregates are:

- `WriteCapabilities.cumulative = ReadCapabilities.all + WriteCapabilities.all`.
- `AdminCapabilities.cumulative = WriteCapabilities.cumulative + AdminCapabilities.all`.

The writer and admin executable composition roots use the cumulative values.
Tier-specific SDK constructors use `ReadCapabilities.all`,
`WriteCapabilities.cumulative`, and `AdminCapabilities.cumulative`
respectively. Core never imports a tier module. The reader executable and
reader SDK therefore cannot link writer or admin definitions, and the writer
executable and writer SDK cannot link admin definitions.

## Catalog export

`Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsSchemaCatalogExporter.swift`
provides the Google Analytics adapter from validated `CapabilityDefinition`
values to `GatewaySchemaCatalog`. Export first constructs a
`CapabilityRegistry` for the requested tier and uses the registry's accepted,
sorted definitions. An incoherent, duplicated, or above-tier definition fails
construction; it never produces a partial catalog.

The catalog root uses provider `google-analytics-gateway` and the selected
`reader`, `writer`, or `admin` tier. Each capability maps as follows:

| Capability metadata | Catalog metadata |
| --- | --- |
| `field` | operation name |
| `.read` | query |
| `.create`, `.update`, `.delete` | mutation |
| `tier.rawValue` | minimum operation tier |
| `summary` | operation summary |
| `isDestructive` | destructive marker |
| `ga` / `gtm` field prefix | `ga` / `gtm` domain |

An unexpected field prefix is a catalog-construction failure rather than an
unclassified operation. Operations are sorted by kind and name; arguments and
type fields are sorted by name so catalog JSON, SDL, and search output are
deterministic.

Type references are built structurally, never by parsing generated SDL.
`resourceName` is catalogued as `ID`, while the argument description retains
the accepted resource-name patterns. Strings, integer, number, Boolean, JSON,
lists, enums, input objects, and `PageInput` otherwise preserve their GraphQL
shape and requiredness. Nested input objects and enums are collected
recursively. Repeated definitions with the same name and shape are deduplicated;
the same name with a different shape is a construction failure.

Result shapes reproduce the executable schema model: entity objects and their
reachable nested objects, `<Type>Connection` with `nodes` and `PageInfo`,
`<Type>Payload`, lists, `DeletionPayload`, and file-output objects. `PageInfo`
is always emitted to match `GraphQLSchemaPrinter`; `PageInput` and
`DeletionPayload` are conditional under the printer's existing rules. Built-in
scalars are references, not named-type entries.

The catalog SDL is not required to be byte-identical to the gateway's
documentation-rich SDL. For every tier, however, query names, mutation names,
and all named object/input/enum types must match
`GraphQLRuntime.printedSchema()` in both directions, and
`catalog.validate()` must return no problems.

## Runtime composition and environment boundary

`GatewayComposition` exposes a runtime factory in addition to the command-frame
factory. Both paths share one private composition function for registry,
profile selection, credential resolution, planner, production transport, and
executor construction.

The public SDK runtime path uses the default credential selection and the exact
`[String: String]` supplied to the SDK call. It does not read
`ProcessInfo.processInfo.environment` as a fallback. The CLI path continues to
use its parsed `--config` and `--profile` selection and its existing process
environment behavior. This separation preserves CLI authentication while
making SDK calls deterministic and preventing accidental credential reuse
between host calls.

The facade stores a runtime-factory seam. Production construction uses
`GatewayComposition`; an internal initializer exposes only that seam to
`@testable` tests. No mock transport, fixture, alternate host, token, or
test-mode selector enters a production API or executable.

## JSON bridge and response envelope

`JSONValue` and `GatewayJSONValue` are converted case-for-case for null,
Boolean, integer, floating point, string, array, and object values. Conversion
is total and recursive and does not coerce integer and floating-point cases.

`GraphQLResponse` maps to `GatewayEnvelope` as follows:

- data is bridged recursively;
- each error preserves its message and stable `GatewayErrorCode.rawValue`;
  `path` remains absent because the existing `GatewayError` has no structured
  GraphQL-path field;
- `requestID` becomes `requestId`;
- the gateway exit code becomes `Int32`;
- `rawOutput` is the compact rendering of the same GraphQL response that the
  CLI writes before its trailing newline.

Runtime-construction failures become failure envelopes with the corresponding
gateway exit code, or internal-failure exit code 70 for an unexpected error.
They do not throw or crash the host.

## Facade and tier constructors

`Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsGatewaySDK.swift`
defines a public `Sendable` `GoogleAnalyticsGatewaySDK` conforming to
`GatewaySDK`. Its public initializer accepts a `RoleDescriptor` and capability
definitions, validates them through `CapabilityRegistry`, and exports the
catalog from exactly the accepted definitions.

Each call to `execute(document:variables:environment:)` composes a runtime for
that call, bridges variables, executes the existing `GraphQLRuntime`, and maps
the response without an argv or CLI round trip. The existing parser, planner,
tier check, credential resolver, host policy, transport, projection, and error
mapping remain authoritative.

Tier modules add the only convenience constructors:

- `GoogleAnalyticsGatewayRead`: `.reader()`.
- `GoogleAnalyticsGatewayWrite`: `.writer()` using
  `WriteCapabilities.cumulative`.
- `GoogleAnalyticsGatewayAdmin`: `.admin()` using
  `AdminCapabilities.cumulative`.

The facade uses the shared kit defaults for schema SDL and search. It overrides
named `invoke` only to preserve authorization semantics for a known operation
above the linked tier: the name-only `CapabilityCatalog` yields a
`CAPABILITY_DENIED` envelope with exit code 2 before document construction.
This does not import or expose the higher-tier definition. A truly unknown name
retains the kit's unknown-operation failure. Raw GraphQL execution continues to
obtain the same denial from `CapabilityPlanner`.

## CLI behavior

All three executables add:

```text
graphql search <regex> [--kinds <csv>] [--include-referenced-types] [--limit <positive-int>]
graphql operation <name> [--variables <json> | --variables-file <path>] [--select <csv-dot-paths>]
```

`--kinds` accepts the `GatewayDefinitionKind` wire spellings. Unknown kinds,
an invalid regex, zero or negative limits, duplicate options, mutually supplied
variable sources, invalid JSON, invalid selections, and unknown operations are
usage errors with exit code 2. `--select` is a comma-separated set of catalog-
validated dot paths; omitting it uses the kit's bounded default selection.

`graphql search` exports the current executable's tier catalog and performs a
local, credential-free regex search. It prints stable JSON
`{"count": N, "matches": [...]}` with sorted keys; `--pretty` changes only
formatting. Search never creates a runtime or contacts Google.

`graphql operation` uses the same catalog and `GatewayDocumentBuilder` as SDK
`invoke`, then sends the built document and unchanged variables through the
command frame's existing GraphQL execution path. This preserves `--config`,
`--profile`, process-environment authentication, response envelopes, and exit
codes. A known above-tier operation returns `CAPABILITY_DENIED` without loading
credentials. Existing `graphql query`, `graphql query-file`, `graphql schema`,
authentication, doctor, help, pretty output, and forbidden-flag behavior remain
compatible.

CLI-only parsing and result translation remain under
`Sources/GoogleAnalyticsGatewayCore/CLI/`; catalog, bridge, and facade adapters
remain under `Sources/GoogleAnalyticsGatewayCore/SDK/`.

## README contract

`README.md` is part of this feature, not a later documentation refresh. Its
package overview must replace the obsolete zero-external-dependency statement
with the Core-only `GatewaySDKKit` dependency boundary while retaining that
authentication, transport, and Google-specific capability code are local.

The Swift library section becomes a client-SDK walkthrough that names the
required imports and demonstrates this sequence with copyable Swift snippets:

1. construct `.reader()`, `.writer()`, or `.admin()` from the matching tier
   module and explain that writer/admin constructors are cumulative;
2. inspect `catalog`, require an empty `catalog.validate()` result, and render
   `schemaSDL()` without credentials;
3. call `searchSchema` with a regex and optional kind/reference/limit settings;
4. call `invoke` with `GatewayOperationRequest`, variables, default and explicit
   selections, and an explicit per-call environment;
5. call `execute` with raw GraphQL and `GatewayJSONValue` variables and consume
   the returned `GatewayEnvelope`.

Examples must not embed, print, or persist credential values. They explain that
the environment dictionary is the only environment an SDK call observes and
that choosing a tier constructor never grants a higher tier.

The usage section adds runnable examples for `graphql search` with kind,
referenced-type, and limit options and for `graphql operation` with inline
variables, variable-file input, and dot-path selection. Existing examples and
descriptions for `graphql query`, `graphql query-file`, and `graphql schema`
remain present and behaviorally unchanged. The README review gate verifies the
constructor table, SDK catalog/search/invoke/execute sequence, both new CLI
commands, the Core-only dependency statement, and continued query/schema
documentation.

## Behavioral data flow

Named SDK invocation:

1. A tier module constructs the facade with its cumulative authorized set.
2. Registry validation rejects any above-tier or incoherent definition.
3. The exporter creates the searchable catalog from that accepted set.
4. `invoke` checks known higher-tier names, then the kit validates the operation,
   variables, types, and selection and builds a variable-based document.
5. `execute` composes the existing gateway runtime from the call's environment.
6. The runtime validates and authorizes again, resolves credentials, plans the
   request, uses the production transport, and projects the response.
7. The facade bridges the runtime result into a stable `GatewayEnvelope`.

Raw SDK execution starts at step 5. CLI operation mode shares steps 3 and 4 but
continues through the already-composed command-frame runtime to preserve CLI
profile behavior. Schema search stops after step 3 and has no credential or
network path.

## Validation and acceptance evidence

Tests must establish:

- package-manifest and linked-symbol reader/writer/admin boundaries;
- exact cumulative operation sets for reader, writer, and admin constructors
  and executables;
- empty catalog validation plus bidirectional query, mutation, and named-type
  parity with `GraphQLRuntime.printedSchema()` for every tier;
- structural exporter behavior for arguments, nested inputs, enums, connections,
  payloads, deletion, file output, domain, and deterministic ordering;
- exhaustive nested JSON bridging and integer-versus-double identity;
- named `invoke` for representative queries and mutations at every authorized
  tier through a recording transport, including declared variables, method,
  URL/path/query/body, and selection;
- reader named invocation and raw execution of a known writer mutation both
  return `CAPABILITY_DENIED` without a credential or network request;
- raw SDK execution and `graphql query` have equivalent compact payload,
  request ID, and exit code under identical fixed seams;
- CLI search output, filters, referenced types, limits, invalid regex, operation
  default/custom selection, inline/file variables, help, and error cases;
- `README.md` documents the Core-only kit dependency, tier constructors,
  catalog/search/invoke/raw-execute SDK flow, and both new CLI commands while
  retaining the existing query/query-file/schema guidance;
- unchanged regression coverage for `graphql query`, `graphql query-file`,
  `graphql schema`, auth, transport, packaging, and forbidden flags.

Required final verification:

```bash
arch -arm64 /bin/zsh -lc 'cd /Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk && swift build && swift test && swiftlint'
git diff --check
git status --short
```

All non-generated Swift files must remain below 1000 lines. The implementation
is committed locally on `feat/gateway-sdk`, the worktree is left clean, and no
push occurs.

## Rollout, divergences, and risks

The feature is additive. The local dependency is intentionally worktree-
specific until the operator creates and publishes `tacogips/gateway-sdk-kit`;
switching to a URL pin is outside this phase.

There is no Cursor runtime, configuration, command protocol, or repository in
scope. No Cursor compatibility adapter is needed. The only adapters are the
Google Analytics SDK/catalog/value bridge and the CLI translation layer named
above. Codex workflow and repository instructions remain the execution
contract.

Intentional differences from generic shared-kit behavior are limited to:

- resource-name arguments use the semantic catalog scalar `ID` even though the
  existing gateway SDL documents them as `String`; parity is therefore defined
  over operations and named types rather than byte-identical SDL;
- named invocation maps known above-tier names to `CAPABILITY_DENIED` instead
  of the kit's generic unknown-operation envelope, preserving this gateway's
  existing fail-closed tier UX without linking higher-tier definitions;
- the CLI calls the shared document builder but executes through its existing
  command-frame runtime so profile and environment resolution do not change.

Primary risks and controls:

- Tier widening: tier-owned cumulative constructors, registry validation,
  name-only denial, and binary boundary tests.
- Catalog drift across the full capability set: one registry source plus
  bidirectional operation and named-type parity for every tier.
- Invalid catalog references or unstable output: structural type construction,
  deterministic sorting, and mandatory empty `validate()` results.
- Credential or environment leakage: exact per-call SDK environment, existing
  closed credential policy, local-only search, and no production test selector.
- CLI regression: operation mode reuses the existing execution path; query,
  query-file, schema, auth, pretty, variable-file, profile, and help regressions
  remain in the full suite.
- Shared-kit or main-checkout contamination: both repositories are read-only
  constraints verified by status/diff evidence before handoff.
