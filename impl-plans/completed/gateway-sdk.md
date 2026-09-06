# GoogleAnalyticsGatewaySDK Facade and Tier-Safe Catalog

**Status**: Complete; reviewed, verified, and ready for the authorized local commit
**Workflow Mode**: `issue-resolution`
**Workflow Execution**: `codex-design-and-implement-review-loop-session-91`
**Issue Reference**: branch `feat/gateway-sdk`, accepted-design HEAD `b287056`, communication `comm-001044`; no issue number or URL supplied
**Created**: 2026-09-04
**Design Reference**: `design-docs/specs/design-gateway-sdk.md#status-and-authority`

## Purpose

Implement phase 1b as one bounded feature: a public, tier-safe
`GoogleAnalyticsGatewaySDK` facade over `GatewaySDKKit`, deterministic catalog
export and schema search, cumulative writer/admin composition, named-operation
and raw GraphQL execution, matching CLI commands, tests, and user documentation.
The accepted design is authoritative; this plan does not reopen its scope or
decisions.

## Source Traceability and Scope Locks

- Package contract: `design-docs/briefs/gateway-sdk-2026-09-04.md`.
- Accepted design section map:
  - package boundary: `design-docs/specs/design-gateway-sdk.md#package-and-module-boundary`;
  - cumulative tiers: `design-docs/specs/design-gateway-sdk.md#cumulative-capability-composition`;
  - catalog: `design-docs/specs/design-gateway-sdk.md#catalog-export`;
  - composition and environment: `design-docs/specs/design-gateway-sdk.md#runtime-composition-and-environment-boundary`;
  - value/envelope mapping: `design-docs/specs/design-gateway-sdk.md#json-bridge-and-response-envelope`;
  - facade: `design-docs/specs/design-gateway-sdk.md#facade-and-tier-constructors`;
  - CLI: `design-docs/specs/design-gateway-sdk.md#cli-behavior`;
  - documentation: `design-docs/specs/design-gateway-sdk.md#readme-contract`;
  - acceptance: `design-docs/specs/design-gateway-sdk.md#validation-and-acceptance-evidence`;
  - divergences and risk: `design-docs/specs/design-gateway-sdk.md#rollout-divergences-and-risks`.
- Supporting accepted updates:
  `design-docs/specs/architecture.md#targets-mirrors-wrike-gateways-link-boundary-tier-model`
  and `design-docs/specs/command.md#cli-contract`.
- Cross-gateway behavior: `/Users/taco/gits/tacogips/riela/docs/briefs/gateway-sdk-2026-09-04.md`, sections 2 and 3.2.
- Shared API contract: `/Users/taco/gits/tacogips/gateway-sdk-kit/README.md` and
  `/Users/taco/gits/tacogips/gateway-sdk-kit/design-docs/briefs/gateway-sdk-kit-2026-09-04.md`.
- Agent instructions: `AGENTS.md`, `.codex/skills/swift-coding-agent/SKILL.md`,
  and `/Users/taco/gits/tacogips/riela/.codex/skills/riela-impl-workflow/SKILL.md`.
- Modify only `/Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk`.
  Do not modify `/Users/taco/gits/tacogips/gateway-sdk-kit` or
  `/Users/taco/gits/tacogips/google-analytics-gateway`.
- Do not change capability definitions, authentication policy, transport,
  Google host policy, packaging, or the GraphQL language.
- Preserve the accepted local path dependency. URL publication and revision
  pinning are operator-owned and out of scope.
- Do not push. A later workflow step may commit the completed one-feature
  implementation on `feat/gateway-sdk`.

Accepted intentional divergences from generic kit behavior:

1. Export resource-name arguments as catalog `ID` while retaining their
   resource-pattern descriptions; catalog/runtime parity is over root
   operations and named types, not byte-identical SDL.
2. Return `CAPABILITY_DENIED` with exit code 2 for a known operation above the
   linked SDK tier, using the Core name-only catalog without linking higher-tier
   capability definitions.
3. Build CLI named-operation documents with `GatewaySDKKit`, then execute them
   through the existing `CommandFrame` runtime so `--config`, `--profile`, and
   process-environment behavior remain unchanged.

## Deliverables

- [x] `Package.swift` adds the worktree-relative `gateway-sdk-kit` package and
      makes `GatewaySDKKit` a direct dependency of `GoogleAnalyticsGatewayCore`
      only among production targets, with the operator-owned URL-pin comment.
- [x] `Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsSchemaCatalogExporter.swift`
      validates definitions through `CapabilityRegistry` and deterministically
      exports operations, arguments, input/enumeration/object/result types, and
      metadata into `GatewaySchemaCatalog`.
- [x] `Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsJSONBridge.swift`
      provides total case-preserving value conversion and response-envelope
      mapping without integer/double coercion.
- [x] `Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsGatewaySDK.swift`
      implements the public `Sendable` `GatewaySDK` facade, per-call runtime
      composition, raw execution, and known-above-tier named invocation denial.
- [x] Tier modules expose `.reader()`, `.writer()`, and `.admin()` constructors;
      writer/admin definitions and executable composition use explicit
      cumulative aggregates without widening link boundaries.
- [x] `Sources/GoogleAnalyticsGatewayCore/CLI/CommandArguments.swift`,
      `Sources/GoogleAnalyticsGatewayCore/CLI/CommandFrame.swift`, and focused
      CLI support under `Sources/GoogleAnalyticsGatewayCore/CLI/` implement
      `graphql search` and `graphql operation` with the accepted grammar,
      deterministic output, local-only search, and existing command-envelope
      semantics.
- [x] Core SDK/exporter/bridge tests and CLI/binary-boundary tests cover every
      accepted behavior and regression requirement.
- [x] `README.md` documents the Core-only dependency, all tier constructors,
      the catalog/search/invoke/raw-execute flow, both new CLI commands, and the
      unchanged query/query-file/schema paths without credential examples.

## Task Breakdown

### TASK-001: Add the shared-kit dependency boundary

**Dependencies**: Accepted design; clean `gateway-sdk-kit` reference checkout.
**Write Scope**: `Package.swift` only.
**Parallelizable**: No; it establishes the compile boundary used by later tasks.

**Actions**:

- Add `.package(url: "https://github.com/tacogips/gateway-sdk-kit.git", exact: "0.1.0")` with the accepted publication
  follow-up comment.
- Add `.product(name: "GatewaySDKKit", package: "gateway-sdk-kit")` to
  `GoogleAnalyticsGatewayCore`; do not add it to tier modules or executables.
- Preserve all current product and target tier dependencies.

**Completion Criteria**:

- [x] SwiftPM resolves and builds the local package.
- [x] Manifest inspection proves Core is the only production target with a
      direct `GatewaySDKKit` product dependency.
- [x] Reader and writer target dependency lists still exclude forbidden tiers.

### TASK-002: Add cumulative capability composition

**Dependencies**: TASK-001.
**Write Scope**: `Sources/GoogleAnalyticsGatewayWrite/WriteCapabilities.swift`,
`Sources/GoogleAnalyticsGatewayAdmin/AdminCapabilities.swift`,
`Sources/GoogleAnalyticsGatewayWriterCLI/main.swift`, and
`Sources/GoogleAnalyticsGatewayAdminCLI/main.swift`.
**Parallelizable**: Yes, alongside TASK-003; scopes are disjoint.

**Actions**:

- Keep `WriteCapabilities.all` and `AdminCapabilities.all` as deltas.
- Add `WriteCapabilities.cumulative` as reader plus writer, and
  `AdminCapabilities.cumulative` as writer cumulative plus admin.
- Switch writer/admin executable composition roots to those named aggregates;
  keep the reader on `ReadCapabilities.all`.

**Completion Criteria**:

- [x] Aggregate sets equal the exact union expected for each tier, with no
      duplicates or above-tier definitions.
- [x] Existing CLI schemas retain cumulative reader/writer/admin behavior.
- [x] Reader excludes writer/admin symbols and writer excludes admin symbols.

### TASK-003: Export validated capability registries to deterministic catalogs

**Dependencies**: TASK-001.
**Write Scope**:
`Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsSchemaCatalogExporter.swift`
only.
**Parallelizable**: Yes, alongside TASK-002; scopes are disjoint.

**Actions**:

- Build a `CapabilityRegistry` first and export exactly its accepted, sorted
  definitions; fail atomically on duplicate, incoherent, or above-tier input.
- Map operation kind, minimum tier, summary, destructive marker, and strict
  `ga`/`gtm` domain from capability metadata.
- Convert argument types structurally, including resource `ID`, lists,
  requiredness, `PageInput`, JSON, nested input objects, and enumerations.
- Recursively collect result objects, nested objects, connections, payloads,
  deletion payloads, file-output shapes, and conditional shared types.
- Deduplicate identical named types and fail on same-name/different-shape
  collisions. Sort operations, arguments, fields, enum values where required,
  and named types deterministically.

**Completion Criteria**:

- [x] Reader, writer, and admin catalogs return no `validate()` problems.
- [x] Catalog query, mutation, and named-type sets match
      `GraphQLRuntime.printedSchema()` in both directions for every tier.
- [x] Unexpected operation prefixes and named-type shape collisions fail
      construction without a partial catalog.
- [x] Repeated exports produce identical catalog JSON, SDL, and search order.

### TASK-004: Expose runtime composition and implement the JSON/envelope bridge

**Dependencies**: TASK-001.
**Write Scope**:
`Sources/GoogleAnalyticsGatewayCore/CLI/GatewayComposition.swift` and
`Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsJSONBridge.swift`.
**Parallelizable**: Yes, alongside TASK-003 after TASK-001; scopes are disjoint
from TASK-003, but no parallel task may also edit `GatewayComposition.swift`.

**Actions**:

- Extract one private production composition path shared by command-frame and
  runtime factories so registry, profile selection, credential resolution,
  planner, transport, and executor setup cannot drift.
- Add a public runtime factory whose supplied `[String: String]` is the only
  environment it observes; retain the CLI factory's current process-environment
  default and parsed credential selection.
- Bridge `JSONValue` and `GatewayJSONValue` recursively and case-for-case.
- Map `GraphQLResponse` to `GatewayEnvelope`, preserving error messages/codes,
  request ID, `Int32` exit code, and compact CLI-equivalent raw output; do not
  invent a GraphQL path.
- Map a known `GatewayError` thrown during runtime construction to a failure
  envelope using that error's corresponding gateway exit code. Map every
  unexpected construction error to an internal-failure envelope with exit code
  70; neither case may throw or crash the SDK host.

**Completion Criteria**:

- [x] `GatewayComposition.makeRuntime(role:definitions:environment:)` is public
      and observes only its supplied SDK environment.
- [x] SDK runtime construction never falls back to
      `ProcessInfo.processInfo.environment`.
- [x] CLI auth/profile/environment behavior remains unchanged.
- [x] Nested JSON round trips preserve null, Boolean, integer, double, string,
      array, and object identity.
- [x] Envelope data, codes, request ID, exit code, and compact raw output match
      the underlying `GraphQLResponse`.
- [x] A known runtime-construction `GatewayError` retains its exact gateway
      exit code, while a non-gateway construction error returns exit code 70.

### TASK-005: Implement the facade and tier constructors

**Dependencies**: TASK-002, TASK-003, TASK-004.
**Write Scope**:
`Sources/GoogleAnalyticsGatewayCore/SDK/GoogleAnalyticsGatewaySDK.swift` and new
tier-specific SDK extension files under `Sources/GoogleAnalyticsGatewayRead/`,
`Sources/GoogleAnalyticsGatewayWrite/`, and
`Sources/GoogleAnalyticsGatewayAdmin/`.
**Parallelizable**: No; it integrates the exporter, runtime, bridge, and
cumulative aggregates.

**Actions**:

- Implement the public `Sendable` facade with provider, tier, catalog,
  validating initializer, and an internal runtime-factory seam limited to
  `@testable` use.
- Compose and execute a fresh runtime for every raw call with only the caller's
  environment; convert runtime-construction failures to stable envelopes.
- Override `invoke` only for the name-only known-above-tier denial before the
  kit document builder; leave truly unknown operations to kit behavior.
- Add `.reader()`, `.writer()`, and `.admin()` convenience constructors in the
  corresponding tier modules, using the exact accepted aggregate for each.

**Completion Criteria**:

- [x] Constructor catalogs expose exact cumulative operation sets per tier.
- [x] Named authorized query/mutation calls use the kit builder and existing
      runtime without argv translation.
- [x] Reader invocation/raw execution of a known writer mutation returns
      `CAPABILITY_DENIED`, exit code 2, with zero credential resolutions and
      zero transport requests.
- [x] Unknown operation behavior remains the shared kit default.
- [x] No production API exposes transport, host, token, fixture, or test-mode
      overrides.
- [x] Each documented `GatewaySDKKit` plus tier-module import pair exposes the
      facade and compiles in an isolated consumer-style test target.

### TASK-006: Add catalog-driven CLI search and operation modes

**Dependencies**: TASK-003, TASK-004; TASK-002 supplies the final cumulative
definitions used by writer/admin executables.
**Write Scope**: `Sources/GoogleAnalyticsGatewayCore/CLI/CommandArguments.swift`,
`Sources/GoogleAnalyticsGatewayCore/CLI/CommandFrame.swift`, and one focused new
support file such as
`Sources/GoogleAnalyticsGatewayCore/CLI/GraphQLCatalogCommands.swift`.
**Parallelizable**: Yes, alongside TASK-005 only if TASK-005 does not edit CLI
files or shared SDK bridge files.

**Actions**:

- Extend typed command parsing for search pattern, kind CSV, referenced types,
  positive limit, operation name, mutually exclusive variable sources, and
  comma-separated dot-path selections.
- Reject duplicate/unknown options, invalid kind values/regex/limits/JSON/
  selections, mutually supplied variable sources, and unknown operations as
  usage errors with exit code 2.
- Export the current tier catalog for both commands. Search must remain local,
  credential-free, network-free, stable, and sorted-key JSON; `--pretty`
  changes formatting only.
- Build named-operation documents with `GatewayDocumentBuilder`, then execute
  through the existing command-frame runtime with unchanged variables and
  credential selection.
- Deny known above-tier names before credential resolution and preserve current
  query, query-file, schema, auth, doctor, help, pretty, and forbidden-flag
  behavior.

**Completion Criteria**:

- [x] All accepted search and operation examples parse and execute in each
      binary tier.
- [x] Invalid input has deterministic usage diagnostics and no credential or
      network activity.
- [x] Search never constructs a runtime.
- [x] Help advertises both commands and preserves every existing command.

### TASK-007: Add SDK, exporter, bridge, and tier tests

**Dependencies**: TASK-003, TASK-004, TASK-005.
**Write Scope**: focused new files under
`Tests/GoogleAnalyticsGatewayCoreTests/SDK/` and only necessary reusable seams
under `Tests/GoogleAnalyticsGatewayTestSupport/`.
**Parallelizable**: Yes, alongside TASK-008 and TASK-009; scopes are disjoint.

**Actions**:

- Add exporter mapping, collision, deterministic ordering, catalog validation,
  and bidirectional schema parity coverage for all tiers.
- Add exhaustive JSON bridge and response-envelope tests, including integer
  versus double identity and runtime-construction failures.
- Inject both a representative `GatewayError` and an unexpected test error from
  the facade's runtime-construction seam; assert that the first preserves its
  gateway exit code and the second returns internal-failure exit code 70, with
  stable failure envelopes and no thrown error or transport request.
- Exercise representative named queries and mutations at every authorized tier
  through recording credentials/transport; assert declared variables, method,
  URL/path/query/body, selection, request ID, and exit code.
- Compare raw SDK execution with `graphql query` under identical fixed seams.
- Prove known-above-tier named and raw paths deny before credentials/network.

**Completion Criteria**:

- [x] Every validation bullet in the accepted design has a deterministic
      offline assertion or an explicitly named CLI/boundary assertion in
      TASK-008.
- [x] Test seams remain absent from all production public APIs and binaries.
- [x] Construction-failure tests explicitly distinguish preserved gateway exit
      codes from unexpected-error exit code 70.

### TASK-008: Extend CLI and binary-boundary regression coverage

**Dependencies**: TASK-002, TASK-006.
**Write Scope**:
`Tests/GoogleAnalyticsGatewayCoreTests/CLI/CommandParsingTests.swift`,
`Tests/GoogleAnalyticsGatewayCoreTests/CLI/CommandFrameTests.swift`,
`Tests/GoogleAnalyticsGatewayCLITests/BinaryBoundaryTests.swift`, and a focused
new CLI test file if splitting keeps responsibilities clear.
**Parallelizable**: Yes, alongside TASK-007 and TASK-009; scopes are disjoint.

**Actions**:

- Cover exact cumulative aggregate sets, manifest dependency boundaries, and
  linked-symbol reader/writer/admin isolation.
- Cover search output/filter/reference/limit/pretty behavior and invalid regex,
  kind, and limit errors.
- Cover operation default/custom selection, inline/file variables, known
  above-tier/unknown operations, duplicate/mutually exclusive options, invalid
  JSON, and help.
- Retain regression assertions for query, query-file, schema, auth, transport,
  packaging-facing manifest structure, and forbidden flags.

**Completion Criteria**:

- [x] Real binaries demonstrate tier-correct catalogs and link boundaries.
- [x] Existing command behavior remains green without weakened assertions.
- [x] The reader/writer/admin named-operation matrices match SDK constructor
      catalogs exactly.

### TASK-009: Publish user-facing SDK and CLI documentation

**Dependencies**: Accepted design; finalize examples after TASK-005 and
TASK-006 APIs stabilize.
**Write Scope**: `README.md` only.
**Parallelizable**: Yes, alongside TASK-007 and TASK-008 once public spellings
are stable; scopes are disjoint.

**Actions**:

- Replace the obsolete zero-dependency statement with the Core-only neutral-kit
  dependency boundary while stating that Google auth, transport, and
  capability code remain local.
- Name and show the required imports: `GatewaySDKKit` plus the matching
  `GoogleAnalyticsGatewayRead`, `GoogleAnalyticsGatewayWrite`, or
  `GoogleAnalyticsGatewayAdmin` tier module used for construction.
- Add copyable `.reader()`, `.writer()`, and `.admin()` construction examples,
  explaining cumulative tier limits, then demonstrate catalog validation, SDL,
  and regex search without credentials.
- Demonstrate `GatewayOperationRequest` with operation variables and both
  `selection: .default` and explicit `selection: .fields([...])`, followed by
  `invoke` using an explicit environment dictionary.
- Demonstrate raw `execute(document:variables:environment:)` with
  `GatewayJSONValue` variables and the same explicit per-call environment.
- State the exact environment contract: the dictionary passed to each SDK
  `invoke` or `execute` call is the only environment observed by that call; SDK
  execution never falls back to `ProcessInfo.processInfo.environment`.
- Add runnable CLI search and operation examples for kind filters, referenced
  types, positive limits, inline/file variables, and dot-path selections.
- Preserve current query, query-file, schema, auth, development, and packaging
  guidance. Never embed, print, or persist a credential value.

**Completion Criteria**:

- [x] README review finds all three constructors, catalog `validate()`, SDL,
      search, invoke, execute, both new CLI commands, and the Core-only
      dependency statement.
- [x] README examples contain the required kit and tier-module imports,
      `GatewayOperationRequest` variables, explicit `.default` and `.fields`
      selections, `GatewayJSONValue` raw variables, and an environment argument
      on both named and raw calls.
- [x] README prose explicitly states that each supplied per-call environment is
      the only SDK environment and that there is no process-environment
      fallback.
- [x] Existing query/query-file/schema guidance remains present and accurate.

### TASK-010: Adversarial review, verification, and clean handoff

**Dependencies**: TASK-001 through TASK-009.
**Write Scope**: fixes only within the preceding task scopes; this plan's
progress log.
**Parallelizable**: No.

**Actions**:

- Review tier widening, catalog drift/collisions, default-selection validity,
  environment leakage, pre-credential denial, output determinism, CLI option
  ambiguity, and regression risk.
- Resolve every high- and mid-severity review finding before acceptance; record
  any accepted low finding or verification gap in the progress log and workflow
  handoff.
- Run focused gates, then the exact full verification commands below.
- Confirm all non-generated Swift files remain under 1000 lines, external
  reference repositories remain clean, no push occurred, and the eventual
  local commit leaves this worktree clean.

**Completion Criteria**:

- [x] No unresolved high- or mid-severity finding remains.
- [x] Full build, test, lint, whitespace, file-length, README, and boundary
      gates pass.
- [x] The final commit contains only this feature's implementation, accepted
      design/docs, tests, and plan/progress updates; branch is
      `feat/gateway-sdk`, and nothing is pushed. The commit is created
      immediately after this plan update, after which the worktree is clean.

## Dependency Graph

```text
accepted design
    |
TASK-001 dependency boundary
    |-------------------------|----------------------|
TASK-002 cumulative tiers   TASK-003 exporter      TASK-004 runtime/bridge
    |                         |----------------------|
    |                         |                 TASK-005 facade/constructors
    |-------------------------|----------------------|
                              TASK-006 CLI
                     |------------|-------------|
                  TASK-007     TASK-008      TASK-009
                       \           |           /
                        TASK-010 review/verification
```

Parallel execution is permitted only for tasks explicitly marked above and
only while their listed write scopes remain disjoint. Any newly discovered
shared-file edit serializes the affected tasks.

## Verification Commands

Run from
`/Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk`
unless a command supplies `-C`:

```bash
git branch --show-current
git rev-parse --short HEAD
git status --short

arch -arm64 /bin/zsh -lc 'cd /Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk && swift test --filter GoogleAnalyticsGatewaySDKTests'
arch -arm64 /bin/zsh -lc 'cd /Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk && swift test --filter "CommandParsingTests|CommandFrameTests|ExecutableLinkBoundaryTests|CrossTierSchemaTests"'
arch -arm64 /bin/zsh -lc 'cd /Users/taco/gits/tacogips/google-analytics-gateway-worktrees/gateway-sdk && swift build && swift test && swiftlint'

find Sources Tests -name '*.swift' -print0 | xargs -0 wc -l | awk '$2 != "total" && $1 > 1000 { print; failed = 1 } END { exit failed }'
for module in GatewaySDKKit GoogleAnalyticsGatewayRead GoogleAnalyticsGatewayWrite GoogleAnalyticsGatewayAdmin; do rg -n "^import ${module}$" README.md >/dev/null || exit 1; done
for text in 'GoogleAnalyticsGatewaySDK' '.reader()' '.writer()' '.admin()' 'catalog.validate()' 'schemaSDL()' 'searchSchema(' 'GatewayOperationRequest' 'variables:' 'selection: .default' 'selection: .fields' 'GatewayJSONValue' 'invoke(' 'execute(' 'environment:'; do rg -n -F -- "$text" README.md >/dev/null || exit 1; done
for text in 'only environment' 'ProcessInfo.processInfo.environment' 'per-call environment'; do rg -n -F -- "$text" README.md >/dev/null || exit 1; done
for text in 'graphql search' '--kinds' '--include-referenced-types' '--limit' 'graphql operation' '--variables' '--variables-file' '--select' 'graphql query' 'graphql query-file' 'graphql schema' 'GatewaySDKKit'; do rg -n -F -- "$text" README.md >/dev/null || exit 1; done
git diff --check
git status --short
git -C /Users/taco/gits/tacogips/gateway-sdk-kit status --short
git -C /Users/taco/gits/tacogips/google-analytics-gateway status --short
```

The implementation-step handoff must record each command's exact status and
output summary. If a command cannot run, record the reason and residual risk;
do not silently omit it.

## Progress Log Expectations

Add one dated entry whenever a task starts, completes, is revised after review,
or is blocked. Each entry must name:

- task ID and affected paths;
- behavior delivered or decision applied;
- focused verification commands and results;
- review findings resolved or intentionally retained;
- deviations from this plan and their accepted-design justification.

Do not mark the plan complete until TASK-010 passes, the implementation is
locally committed by the authorized workflow step, the worktree is clean, and
no push has occurred. When complete, change the status and move the plan to
`impl-plans/completed/` in the same finalizing commit if the workflow permits.

## Progress Log

- 2026-09-04: Final handoff verification passed after the built-in commit node
  was policy-blocked: `swift build`, all 289 tests in 29 suites, and SwiftLint
  with the Xcode toolchain library paths completed successfully. The one
  `control_statement` warning in `CommandArguments.swift` was corrected and
  the lint rerun reported zero violations. `git diff --check` passed. TASK-010
  is complete; this plan is archived in the same authorized local commit. No
  push was performed. The accepted low-severity non-finite raw-variable gap
  remains documented for follow-up.

- 2026-09-04: Step 7 ordinary review `comm-001076`, test-integrity review
  `comm-001075`, and adversarial review `comm-001077` accepted the
  implementation with no high- or mid-severity finding. Step 7b evidence
  `comm-001078` correctly skipped browser E2E because the Swift package has no
  browser-facing surface or declared Playwright/Cypress suite. Step 8 refreshed
  `README.md` to distinguish GraphQL, catalog-search, and SDL output; disclose
  the worktree-relative `GatewaySDKKit` dependency; use a host-supplied
  credential environment in SDK examples; document `GatewayEnvelope`
  consumption; and make the accepted nested non-finite-double limitation
  explicit. The README contract gate and `git diff --check` pass. Remaining low
  risks are the raw-execute non-finite-number preflight gap, environment-blocked
  SwiftLint, worktree-relative kit dependency, skipped browser E2E, and pending
  authorized commit handoff; TASK-010 stays open.

- 2026-09-04: Revised TASK-005, TASK-009, and TASK-010 after independent
  review `comm-001072`. Reader, writer, and admin now re-export
  `GoogleAnalyticsGatewayCore`, so the documented `GatewaySDKKit` plus exactly
  one tier-module import pair exposes `GoogleAnalyticsGatewaySDK` and its
  matching constructor. Added separate consumer-style reader/writer/admin test
  targets that import only the documented modules; no consumer test directly
  imports Core. Focused import coverage passed 19 tests across 5 suites and
  full Swift verification passed 289 tests across 29 suites. Build, whitespace,
  file-length, README, and protected-reference-repository gates are rerun after
  this revision. SwiftLint remains environment-blocked because
  SourceKitten cannot load `sourcekitdInProc.framework`. TASK-010 remains open
  pending accepted Step 7 review, explicitly requested adversarial review, lint
  remediation, and commit handoff.

- 2026-09-04: Revised TASK-004, TASK-006, and TASK-010 after independent
  review `comm-001068`. Renamed the public SDK runtime factory to the accepted
  `GatewayComposition.makeRuntime(role:definitions:environment:)` spelling,
  retained one private shared composition helper for CLI credential selection,
  and updated the facade to call the public API. Added a non-`@testable`
  compile-time API test and changed `design-docs/specs/command.md` from pending
  to implemented. Focused verification passed 57 tests across 6 suites and
  full Swift verification passed 286 tests across 26 suites. TASK-004 is now
  accurately checked; TASK-010 remains open pending accepted Step 7 review,
  explicitly requested adversarial review, lint remediation, and commit
  handoff.

- 2026-09-04: Revised TASK-007, TASK-009, and TASK-010 after independent
  review `comm-001064`. The catalog exporter now renders required nested input
  fields as non-null type references and retains runtime `String` signatures
  for nested resource-name input fields, model resource names, and
  `DeletionPayload.deletedName`; `ID` remains limited to catalog resource-name
  arguments. Added exact catalog-versus-
  runtime object/input field-signature assertions for all tiers, updated
  structural exporter assertions, and corrected both documented
  `gaCreateDataStream` examples with `dataStream.type` and payload selections.
  Focused and full Swift verification, build, whitespace, file-length, README,
  and protected-reference-repository gates are rerun after this revision.
  SwiftLint remains environment-blocked by SourceKitten loading
  `sourcekitdInProc.framework`. TASK-010 remains open pending accepted Step 7
  review, required adversarial review, commit handoff, and lint remediation.

- 2026-09-04: Revised TASK-007 and TASK-008 after test-integrity feedback
  `comm-001060` (`test-integrity-001` through `test-integrity-003`). Added
  exact convenience-constructor catalog equality and a manifest assertion that
  `GatewaySDKKit` is a direct production dependency of Core only. Added
  parser/frame/binary coverage for unknown kinds, non-positive limits, mutually
  exclusive variable sources, malformed operation JSON, catalog-invalid
  selection, unknown operation, both new help lines, and exact referenced-type
  expansion. Added table-driven exporter assertions for connection, payload,
  deletion, page/input, enum, object-field, and requiredness mappings; expanded
  representative SDK assertions to cover URL, method, path/query/body,
  capability ID, authorization, selection projection, request ID, exit code,
  credential resolution, and named higher-tier no-runtime/no-credential/no-
  transport denial. Focused SDK/CLI/boundary suites and full `swift test`
  passed 284 tests across 25 suites. TASK-007 and TASK-008 remain checked with
  this current evidence; TASK-010 and SwiftLint environment remediation remain
  pending.

- 2026-09-04: Revised TASK-006 through TASK-008 after Step 6 self-review
  communication `comm-001057`. CSV parsing now preserves empty components and
  rejects malformed `--kinds` and `--select` values before credential
  resolution. Added parser and command-frame coverage for malformed CSV,
  referenced-type search, limit, default/custom operation selection, and
  inline/file variables. Expanded SDK coverage to exact tier operation and
  runtime-schema parity; nested JSON and response envelopes; nested inputs,
  enums, file-output requiredness, collisions, and prefix rejection; successful
  reader/writer/admin invocation with recorded request semantics; raw
  pre-credential higher-tier denial; fixed-seam raw-SDK/CLI payload parity;
  and an owned named-operation probe in each real binary. The focused SDK/CLI
  suites passed 40 Core tests and 21 binary-boundary tests; full `swift test`
  passed 280 tests across 25 suites. The corrected direct CLI probes return
  usage exit 2. SwiftLint remains environment-blocked because SourceKitten
  cannot load `sourcekitdInProc.framework`. TASK-007 and TASK-008 completion
  criteria remain checked because this evidence now covers their accepted
  matrix; TASK-010 remains pending.

- 2026-09-04: Revised TASK-003 through TASK-008 after Step 6 self-review
  communication `comm-001055`. The exporter now validates `ga`/`gtm` prefixes,
  preserves resource-pattern descriptions and file-output requiredness, and
  uses deterministic kind/name ordering. Runtime composition is shared by SDK
  and CLI; the internal SDK factory seam proves exact per-call environment
  isolation and safe known/unexpected construction envelopes. CLI parsing now
  rejects unowned and duplicate options; SDKKit validation errors are usage
  errors; both query and mutation names receive pre-credential above-tier
  denial. Added SDK/exporter/bridge and command-frame/parser regressions,
  including collision, prefix, ordering, integer/double, invalid-regex,
  document-builder, and admin-query denial paths. `swift test` passed (272
  tests/25 suites); direct reader validation, above-tier denial, and schema
  option-ownership probes returned exit 2. `swift build`, `git diff --check`,
  README gates, boundary tests, and corrected fail-fast Swift-length gate
  passed. SwiftLint remains environment-blocked because SourceKitten cannot
  load `sourcekitdInProc.framework`; TASK-010 and Step 7 remain pending.

- 2026-09-04: TASK-001 through TASK-009 implemented in
  `Package.swift`, Core SDK/CLI adapters, tier modules, executable roots,
  `README.md`, and `Tests/GoogleAnalyticsGatewayCoreTests/SDK/GoogleAnalyticsGatewaySDKTests.swift`.
  Added the Core-only local `GatewaySDKKit` dependency, deterministic registry
  catalog exporter, case-preserving JSON/envelope bridge, per-call SDK runtime,
  tier constructors, catalog search and named operation CLI paths, cumulative
  tier aggregates, and SDK documentation. This initial implementation entry is
  superseded by the subsequent `comm-001055` revision evidence.

- 2026-09-04: Plan created after Step 3 accepted
  `design-docs/specs/design-gateway-sdk.md`; no Step 5 feedback exists on this
  first planning pass. Baseline branch `feat/gateway-sdk`, HEAD `b287056`.
  Accepted design changes remain limited to
  `design-docs/specs/architecture.md`, `design-docs/specs/command.md`, and new
  `design-docs/specs/design-gateway-sdk.md`. No implementation code was written.
- 2026-09-04: Revised after Step 5 review communication `comm-001048`.
  Addressed both mid findings by making construction-error exit-code behavior
  explicit in TASK-004/TASK-007 and expanding TASK-009 plus README gates for
  imports, variables, default/explicit selections, and exact per-call
  environment semantics. Addressed the low finding by adding accepted-design
  section anchors. No design revision or implementation code was required.
- 2026-09-04: Revised after self-review communication `comm-001050`.
  Replaced permissive alternation-based README searches with fail-fast loops
  that independently require every import, SDK example element, environment
  contract phrase, new CLI option, and retained GraphQL command. No design
  revision or implementation code was required.

## Risks

- **Tier widening**: cumulative arrays could be used below their owning tier.
  Control with tier-owned constructors, registry validation, name-only denial,
  manifest checks, symbol inspection, and exact-set tests.
- **Catalog/runtime drift**: structural result/input mapping may omit or
  conflict on a reachable type. Control with fail-atomic collection,
  deterministic deduplication, empty validation, and bidirectional parity for
  every tier.
- **Environment leakage**: SDK composition could accidentally reuse CLI process
  environment defaults. Control with separate public runtime semantics, one
  shared private composition function, and sentinel-environment tests.
- **CLI regression**: new global options could leak into old subcommands or
  change profile behavior. Control with typed command cases, option ownership
  tests, and unchanged full CLI/auth/forbidden-flag coverage.
- **Local dependency portability**: the relative kit path works only in the
  current workspace layout. This is accepted low risk; URL publication/pinning
  remains operator-owned and out of scope.
- **Traceability**: no issue number or URL was supplied. Preserve workflow
  `codex-design-and-implement-review-loop-session-91` and communications
  `comm-001044`/`comm-001045` in every later handoff.
