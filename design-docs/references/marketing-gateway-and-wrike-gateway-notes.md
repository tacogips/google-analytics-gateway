# google-marketing-gateway + wrike-gateway Notes (reference for this project)

Distilled from repo exploration on 2026-08-24. Headline: google-marketing-gateway
has NO GraphQL layer (typed flag CLI only; GraphQL is its stated future). The
working GraphQL reference in this project family is
../wrike-gateway (zero-dependency hand-written engine).
Synthesis rule for google-analytics-gateway: GraphQL engine and capability model
from wrike-gateway; Google OAuth/secure-file/profile plumbing from
google-marketing-gateway.

## Take from wrike-gateway (Sources/WrikeGatewayCore/GraphQL/, 1140 lines)

- Six files: GraphQLLexer (197), GraphQLDocument (124, constrained AST),
  GraphQLParser (289, recursive descent; 64KB doc cap, 10 top-level fields,
  depth 8), GraphQLRuntime (182, envelope + parse->prepare->run),
  GraphQLSchemaPrinter (196, SDL rendered from the registry),
  GraphQLSelectionProjection (152, validate pre-transport, project post-execution).
- Deliberate subset: named/shorthand ops, variables from JSON, scalars/enums/
  lists/input objects, nested selections. Rejected: fragments, aliases,
  directives, subscriptions, introspection, unions, interfaces, variable
  defaults, multiple operations, multi-field mutations. "Widening the syntax
  must never widen capability access."
- Schema = Swift values, no SDL source, no resolver closures: one
  CapabilityDefinition per operation (field, tier, HTTP method, path template,
  scope variants, ArgumentDefinition list with ArgumentBinding data
  (.path/.query/.queryList/.queryJSON/.bodyJSON/.bodyForm/.scope/.page),
  result shape, OAuth scopes, page limit). SDL printer and request planner read
  the same value so schema and routes cannot drift. Registry construction
  validates invariants and throws INTERNAL_ERROR.
- Tier enforcement, four layers: separate SPM library targets per tier (link
  boundary, asserted by a linked-symbol test on built binaries), registry
  refuses definitions above its tier, dispatch consults a name-only
  CapabilityCatalog to answer CAPABILITY_DENIED + requiredTier instead of
  "unknown field", planner re-checks.
- CLI: one-shot `graphql query '<inline>' [--variables '<json>']`,
  `graphql query-file/--variables-file`, `graphql schema`, `--pretty`; no
  `mutate` subcommand; hard-coded forbiddenFlags rejects --base-url/--token/
  --mock-transport/--insecure.
- Errors: GraphQL envelope {data, errors[{message, extensions}],
  extensions.requestId}; stable codes mapped to exit codes; upstream error text
  discarded. Pagination: NOT Relay — {nodes, pageInfo{resultCount,
  nextPageToken}} + page: PageInput; over-limit page size rejected, not clamped.
- Governing doc: wrike-gateway/design-docs/specs/design-graphql-contract.md.
  Known gap there: nested relationship fields with planner batching is specified
  but unimplemented; each top-level field = one upstream request.
- Also take: E2EScenarioCatalog loopback-replay test pattern.

## Take from google-marketing-gateway

- SecureLocalFiles.swift (240 lines) verbatim: openat/fstatat component-wise
  traversal with O_NOFOLLOW|O_DIRECTORY, readStableRegularFile TOCTOU re-stat,
  writePrivateFile (0600 temp + fsync + renameat/linkat + dir fsync),
  requireCurrentUser/requirePrivateMode/requirePrivateParent for token stores.
- OAuth stack (OAuthSupport 204, OAuthClient 128, OAuthLoopback 183,
  ReaderAuthService 64, ReaderCredentials 123): installed-desktop PKCE S256,
  loopback receiver hand-parsing HTTP with strict caps (8K/16K/32K, 32 invalid
  connections max, exact {state, code} query), hard-pinned auth/token endpoints
  (client JSON must match), token exchange requires token_type Bearer,
  expires_in 1...31_536_000, and returned scope set == requested exactly.
  Token store JSON (schemaVersion, profileId, product, tokens, expiresAt,
  scopes) at profile-named path only (no default), reads verify profile/product/
  scopes. Lazy refresh at 60s expiry under per-path NSLock. Browser via
  NSWorkspace (injectable) or --no-browser.
- CredentialProfiles.swift: profiles declare env var NAMES, never values;
  strict unknown-field rejection via AnyCodingKey allowlist decoders;
  per-capability exact scope-bundle validation.
- HTTPTransport protocol + URLSessionTransport (.ephemeral) +
  RejectingRedirectDelegate (redirects completed with nil so 307/308 can never
  replay a POST elsewhere; tested via URLProtocol stubs).
- Request builders: public enum of static factories returning URLRequest,
  validate inputs, never do I/O, origins are internal constants. Responses
  mostly passed through raw (UTF-8 checked); decode only when chaining.
- validate-before-credentials: build request with placeholder token to run
  validators before touching the token store (tested with credential spy).
- Plan/validate/apply mutation ladder: plan = zero-network echo of the exact
  request; validate = provider validateOnly where available; apply requires
  exact-match --confirm-* flags echoing the target. Confirmation on plan is an
  error.
- Error philosophy: closed GatewayError code enum, structural sanitization of
  provider errors (extract only status/errorCode matching ^[A-Z][A-Z0-9_]{0,79}$).
- Already-built GA groundwork: AnalyticsDataRequests.swift (metadata, runReport,
  checkCompatibility, v1beta) portable nearly as-is; OperationCatalog already
  pins analyticsAdmin v1beta and tagManager v2 origins/scopes as planned
  inventory; design doc section 6.2 has the scope tables.
- Tests: swift-testing, transport/credential/auth seams injected, recording
  doubles, "every route dispatches the exact recorded request" pattern,
  fixture tokens spelled fixture-token-not-a-secret. CLI is pure
  (returns GatewayCommandResult, never writes/exits itself).
- CLI grammar note: triple-switch route/flags/request duplication in
  GatewayCLI.swift is the acknowledged weakness the capability registry solves —
  do not replicate.
- mise: swift 6.3.3 pin, kinko enter/leave hooks, homebrew + cask release tasks
  rendering into ../homebrew-tap; CI = gitleaks + SHA-pinned Linux build only.
- impl-plans convention: heavyweight plans (see
  impl-plans/completed/search-console-reader.md, ~700 lines) with typed front
  matter, Write scope per task (parallel-agent collision avoidance), adversarial
  review as the final task, absolute dates, active/ -> completed/ lifecycle.
