# Brief: `GoogleAnalyticsGatewaySDK` facade on `GatewaySDKKit` (2026-09-04)

Master design: `/Users/taco/gits/tacogips/riela/docs/briefs/gateway-sdk-2026-09-04.md`
(sections 2 and 3.2 are normative). The shared kit is implemented at
`/Users/taco/gits/tacogips/gateway-sdk-kit` (read its `README.md` and
`design-docs/briefs/gateway-sdk-kit-2026-09-04.md` for the exact API). Treat this whole
brief as exactly ONE feature.

## Goal

Give google-analytics-gateway a client SDK so that a caller (riela's add-on engine, or
any Swift host) can run an operation by name with variables and an optional selection,
run raw GraphQL with variables, print the schema, and regex-search it, without writing
GraphQL text and without widening the tier.

## Verified seams (2026-09-04, HEAD c46443a)

- `Sources/GoogleAnalyticsGatewayCore/CLI/GatewayComposition.swift:10-48`
  `GatewayComposition.makeCommandFrame(role:definitions:environment: [String: String])`
  → `CommandFrame`; throws if a definition exceeds the role tier.
- `Sources/GoogleAnalyticsGatewayCore/CLI/CommandFrame.swift:42-59` `run(arguments:) async
  -> CommandOutcome`; `graphql schema` at `:71-76`; `--variables` decoding `:132-135`;
  runtime built per invocation through the injected `makeRuntime` closure (`:13`).
- `Sources/GoogleAnalyticsGatewayCore/GraphQL/GraphQLRuntime.swift:60`
  `execute(document:variables: [String: JSONValue]) async -> GraphQLResponse`;
  `:57-59 printedSchema()`.
- `GraphQL/GraphQLSchemaPrinter.swift:18-25` prints SDL from the `CapabilityRegistry`.
- `Capabilities/CapabilityDefinition.swift` (587 lines): `ArgumentValueType` (:108:
  `resourceName(ResourceNamePattern)`, `string`, `stringList`, `integer`, `number`,
  `boolean`, `page`, `enumeration(String,[String])`, `enumerationList`,
  `inputObject(InputObjectShape)`, `inputObjectList`, open JSON), `CapabilityDefinition`
  (id, field, tier, operationClass, method, service, pathTemplate, arguments, result,
  scopes, summary).
- `Capabilities/CapabilityRegistry.swift:18-47`; tiers cumulative
  (`Capabilities/CapabilityIdentity.swift:30-49`).
- Aggregates are DELTAS: `Sources/GoogleAnalyticsGatewayRead/ReadCapabilities.swift`
  (119), `.../GoogleAnalyticsGatewayWrite/WriteCapabilities.swift` (110),
  `.../GoogleAnalyticsGatewayAdmin/AdminCapabilities.swift` (23). The writer CLI passes
  `ReadCapabilities.all + WriteCapabilities.all` (`Sources/GoogleAnalyticsGatewayWriterCLI/main.swift:7-10`);
  riela currently passes only the delta (`/Users/taco/gits/tacogips/riela/Sources/RielaCLI/ProductionNodeAdapter+GoogleAnalyticsGatewayAddons.swift:46-55`),
  so riela's writer add-on lacks the read fields. Fix that here by exposing cumulative
  aggregates.
- `Capabilities/CapabilityCatalog.swift` is a name-only tier table (`writerMutationFields`
  :23, `adminMutationFields` :139, `adminQueryFields` :205) used for `CAPABILITY_DENIED`.
- Tests: swift-testing; `Tests/GoogleAnalyticsGatewayCoreTests` and
  `Tests/GoogleAnalyticsGatewayCLITests/BinaryBoundaryTests.swift` (link boundaries and
  catalog/registry coherence); helpers in `Tests/GoogleAnalyticsGatewayTestSupport`.
- No typed client exists; do not add one (the facade is the typed-ish surface).

## Deliverables

1. **Dependency.** `Package.swift`: `.package(path: "../../gateway-sdk-kit")` (this
   worktree is `/Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk`)
   and product `GatewaySDKKit` on `GoogleAnalyticsGatewayCore` only. Leave a one-line
   comment that the operator switches it to a URL pin later.
2. **Cumulative aggregates.** `WriteCapabilities.cumulative = ReadCapabilities.all +
   WriteCapabilities.all` in the Write module and `AdminCapabilities.cumulative =
   WriteCapabilities.cumulative + AdminCapabilities.all` in Admin; the writer/admin CLI
   mains use them. Boundary tests updated to assert the cumulative sets.
3. **Catalog export** (`Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsSchemaCatalogExporter.swift`):
   `GatewaySchemaCatalog.googleAnalytics(tier:definitions:)` mapping `CapabilityDefinition`
   → `GatewayOperation` (kind from `operationClass`, tier string `reader|writer|admin`,
   arguments via `ArgumentValueType` → `GatewayTypeRef` (`resourceName` → `ID`, `page` →
   the same `PageInput` the printer emits, open JSON → `JSON`), result object types,
   input objects, enums, `summary`, `isDestructive`, `domain` = `ga` or `gtm` from the
   field prefix). Parity test: root field names and named type names of
   `GraphQLRuntime.printedSchema()` == those of `catalog.sdl()` for every tier;
   `catalog.validate()` empty for every tier.
4. **Runtime access.** `GatewayComposition.makeRuntime(role:definitions:environment:)
   throws -> GraphQLRuntime` shared with `makeCommandFrame`. `JSONValue` ⇄
   `GatewayJSONValue` bridging with round-trip tests.
5. **Facade** `Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsGatewaySDK.swift`:
   ```swift
   public struct GoogleAnalyticsGatewaySDK: GatewaySDK {
     public let provider = "google-analytics-gateway"
     public let tier: String
     public let catalog: GatewaySchemaCatalog
     public init(role: RoleDescriptor, definitions: [CapabilityDefinition]) throws
     public func execute(document:variables:environment:) async -> GatewayEnvelope
   }
   ```
   Per-tier constructors in the tier modules (`.reader()` in Read, `.writer()` in Write
   using the cumulative set, `.admin()` in Admin). `GraphQLResponse` → `GatewayEnvelope`
   mapping as in wrike (data, errors with code, requestId, exitCode, rawOutput).
6. **CLI.** `graphql search <regex> [--kinds ...] [--include-referenced-types] [--limit N]`
   (JSON matches) and `graphql operation <name> [--variables|--variables-file] [--select ...]`
   in all three executables; `graphql query` / `graphql schema` unchanged; `--help` and
   `README.md` updated with an SDK section.
7. **Tests**: exporter parity per tier; validate() empty; `invoke` for one query and one
   mutation per tier through the recording transport (document declares variables; the
   planned HTTP request matches); reader SDK invoking a writer mutation returns a
   `CAPABILITY_DENIED` envelope error; `execute` passthrough equals `graphql query` output;
   `graphql search` CLI; boundary tests green.

## Verification

`arch -arm64 /bin/zsh -lc 'cd /Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk && swift build && swift test && swiftlint'`
green. Commit on `feat/gateway-sdk` in this worktree as work lands; do not push.

## Non-goals

No capability definition changes beyond the cumulative aggregates, no transport/auth
changes, no packaging changes. Do not touch `/Users/taco/gits/tacogips/google-analytics-gateway`
(the main checkout).
