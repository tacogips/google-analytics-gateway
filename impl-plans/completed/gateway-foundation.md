# Gateway Foundation: Tiered Package, GraphQL Engine, OAuth, Transport

**Status**: Complete; adversarial review pass finished 2026-08-24
**Design Reference**: `design-docs/specs/architecture.md`, `design-docs/specs/auth.md`, `design-docs/specs/graphql-schema.md`
**Created**: 2026-08-24

## Purpose

Stand up the project skeleton and shared machinery so GA4/GTM capability
registries (separate plans) plug into a working GraphQL runtime: tiered SwiftPM
targets with link-boundary capability separation, the ported wrike-gateway
GraphQL engine, the ported marketing-gateway OAuth/secure-file/profile/transport
stack, error taxonomy, and the shared CLI runner.

## Deliverables

- [ ] Package.swift with Core/Read/Write/Admin libraries + three role
      executables + TestSupport + test target (template AppCore/AppCLI removed)
- [ ] Core/GraphQL: lexer, constrained AST, parser, runtime, SDL printer,
      selection projection (wrike-gateway subset, adapted names)
- [ ] Core capability framework: CapabilityDefinition, ArgumentDefinition/
      ArgumentBinding, registry with invariant validation, name-only
      CapabilityCatalog, generic RequestBuilder, PageInput/PageInfo
- [ ] Core auth: OAuth PKCE + loopback, token store, credential profiles,
      SecureLocalFiles, credential resolver
- [ ] Core transport: HTTPTransport, URLSessionTransport with redirect
      rejection, provider error sanitization, GatewayError taxonomy
- [ ] Shared CLI runner (pure, returns exitCode/stdout/stderr): graphql
      query/query-file/schema, auth login/logout/status, doctor, config
      validate, version, help
- [ ] Tests: engine parsing/rejection suite, registry invariants, transport
      redirect rejection, OAuth lifecycle, CLI dispatch with recording doubles
- [ ] mise build/test/lint green

## Tasks

### TASK-001: Package restructure and target scaffolding

**Parallelizable**: No
**Completion Criteria**:
- [ ] New target layout builds with placeholder sources; old template targets removed; smoke `swift build` passes

### TASK-002: Port GraphQL engine into Core

**Parallelizable**: Yes (after TASK-001)
**Completion Criteria**:
- [ ] Six engine files adapted (GoogleAnalyticsGateway naming), compile clean
- [ ] Rejection matrix tests (fragments/aliases/directives/multi-op/depth/size) pass

### TASK-003: Port capability framework

**Parallelizable**: Yes (after TASK-002 interfaces)
**Completion Criteria**:
- [ ] CapabilityDefinition/registry/catalog/RequestBuilder compile with a sample
      definition; invariant violations throw INTERNAL_ERROR; SDL printer output
      matches sample

### TASK-004: Port OAuth + secure files + profiles

**Parallelizable**: Yes (after TASK-001)
**Completion Criteria**:
- [ ] SecureLocalFiles, OAuth client/loopback/support, CredentialProfiles,
      credential resolver adapted for products {analytics, tagmanager} and
      capabilities {reader, writer, admin} with exact scope bundles
- [ ] OAuth lifecycle tests (refresh, expiry, scope mismatch) pass offline

### TASK-005: Transport + error taxonomy

**Parallelizable**: Yes (after TASK-001)
**Completion Criteria**:
- [ ] URLSessionTransport rejects 307/308 (URLProtocol test); GatewayError codes
      + exit codes; provider error sanitization tests pass

### TASK-006: Shared CLI runner + role shims

**Parallelizable**: No (integrates 002-005)
**Completion Criteria**:
- [ ] Three binaries run graphql schema/query against an injected transport;
      forbiddenFlags rejected; doctor reports without printing secrets
- [ ] Linked-symbol tier boundary test passes

### TASK-007: Adversarial review + full verification

**Parallelizable**: No
**Completion Criteria**:
- [ ] mise run build/test/lint green; review findings resolved or logged

## Progress Log

- 2026-08-24: Plan created after reference exploration (see design-docs/references/).
- 2026-08-24: TASK-001 done (tiered Package.swift, template targets removed).
  TASK-002/003 done: GraphQL engine + capability framework ported; Google
  adaptations: GoogleAPIService origin resolution (no credential baseURL),
  .resourceName patterns with traversal rejection, .bodyRoot, .confirm
  bindings, per-method collection keys, deletedName deletion payload, JSON
  passthrough scalar for open trees, 409 -> validationError.
  TASK-004 done: marketing-gateway OAuth/PKCE/loopback/SecureLocalFiles/
  profiles ported; products analytics/tag-manager/combined; admin bundle =
  reader ∪ writer ∪ admin extras. TASK-005 done (transport + error taxonomy).
  TASK-006 done: CommandFrame/GatewayComposition with --config/--profile,
  synthesized env-token fallback profile, doctor; three role binaries build
  and run (help/doctor/schema verified). CapabilityCatalog name tables filled
  from field-catalog.json. Remaining: TASK-007 (test suite in flight with the
  test-suite agent; adversarial review pending).
- 2026-08-24: TASK-007 complete. Test suite landed (261 swift-testing tests in
  24 suites incl. link-boundary/nm assertions and end-to-end CLI checks).
  /code-review over Core produced 18 confirmed findings; all correctness and
  security items fixed in commit aaa0283 (dot-segment rejection, intValue
  trap, parser recursion caps + byte-measured size cap, /private-stripping
  path resolution, pre-flight token-store validation, query "+" encoding,
  requestId unification, cooperative-pool hop, env-token shape check, EINTR +
  split-read loopback hardening, hex-escape sign rejection, random jitter,
  page-binding coherence rule). Earlier fixes: confirm-echo defect, 409
  mapping. Deferred cleanup: duplicated OAuth scope table
  (CapabilityIdentity vs CredentialProfiles), intentionally unused
  ResponseSinkDelivery download path. Plan closed.
