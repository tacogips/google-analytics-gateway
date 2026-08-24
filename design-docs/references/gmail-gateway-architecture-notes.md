# gmail-gateway Architecture Notes (reference for this project)

Distilled from repo exploration on 2026-08-24
(../gmail-gateway, v0.1.8). Patterns to replicate here,
plus deviations we intentionally make.

## Package shape

- swift-tools-version 6.0, swiftLanguageModes [.v6], macOS 14+, zero external deps.
- One core library holding all logic; executables are ~22-line shims calling
  `GatewayCLI(mode:).run(arguments:environment:)` and writing stdout/stderr/exit.
- Products hyphenated lowercase; targets PascalCase.
- A smoke-test executable target (not a test target) drives the CLI boundary with
  real config files + env vars; `mise run test` runs both suites.

## GraphQL execution (gmail-gateway approach)

- No engine, no schema file at runtime; SDL lives in design docs. One-shot
  `graphql --query/--query-file` subcommand (exactly one; `--variables` rejected).
- `prepareGraphQLQuery`: strip comments (string-aware), reject fragments/spreads
  and multiple root fields. Dispatch via `rootFieldSource(_:in:)` (brace-depth-1
  field finder, alias-aware), typed argument extractors, `selectionBody`/
  `directFieldExists` for hydration control and response projection.
- Responses: `[String: Any]` + JSONSerialization `.sortedKeys` (+ `.prettyPrinted`
  with `--pretty`); errors `{"data": null, "errors": [{message, extensions:
  {code, exitCode, requestId}}]}`.
- Their own QA docs flag the 1,200-line scanner as debt (no variables/fragments/
  aliases). For this project we keep the zero-dependency one-shot contract but
  drive dispatch from an operation catalog (see specs/graphql-schema.md) instead
  of bespoke per-field resolvers.

## Capability model (4 layers)

1. Role-split binaries select mode at compile time; disallowed root fields
   rejected at dispatch (e.g. SEND_DISABLED_IN_READER).
2. Credential config declares access mode; write service re-validates.
3. OAuth scopes granted at login differ per access mode.
4. Identity check binds token to configured account before writes.

## Auth

- OAuth2 authorization-code + PKCE (S256), desktop client JSON (`installed` key),
  loopback receiver on 127.0.0.1 ephemeral port via raw BSD socket, state +
  SecRandomCopyBytes, browser via /usr/bin/open with `--open-browser false` escape.
- Token store Codable JSON (accessMode, accessToken, refreshToken, tokenType,
  scope, expiresAt ISO8601, identity), dir 0700 / file 0600, atomic write.
- Single entry point `validAccessToken(credential:use:)`: 60s freshness leeway,
  refresh-token POST, persistence policy per use (.bestEffort for reads,
  .required for writes); rejects token whose accessMode mismatches credential.
- Env vars per credential id (uppercased, non-alnum -> `_`; collision-checked):
  `<PREFIX>_CREDENTIAL_<ID>_OAUTH_CLIENT_SECRET_PATH` / `_OAUTH_CLIENT_SECRET_JSON`
  / `_TOKEN_STORE_PATH` / `_TOKEN_STORE_JSON`; `_JSON` wins over `_PATH`, env wins
  over config; injected `_JSON` token stores skip refresh persistence. kinko holds
  the `_JSON` values; injection via mise enter/leave hooks running
  `kinko hook enter`.
- `doctor` reports config source, env var set/selected (containsSecret flag, never
  values), OAuth client readiness, token state; exit 3 config vs 4 auth.

## HTTP / API layer

- URLSession.shared, sync-over-async via DispatchSemaphore + locked result box.
- Central URL builder (single host constant, `/` excluded from path encoding).
- Retry: GET 3 attempts, non-GET 1; retryable = 429/5xx; linear 0.05s*attempt.
- One error type (message, code, exitCode, details) + two enums: exit codes
  (0 ok, 1 general, 2 cli, 3 config, 4 auth, 5 graphql, 6 provider) and
  SCREAMING_SNAKE error codes. Provider bodies flattened into details with
  truncation caps (500/1000 chars).
- Relay-style connections over provider page tokens (first->maxResults,
  after->pageToken, nextPageToken->endCursor/hasNextPage).
- Large payloads never inline in GraphQL: downloadKey indirection + `file download`.

## CLI

- Hand-rolled parsing (~70 lines): positionals + `--key value`/`--key=value`,
  boolean flag set, repeated flags; typed accessors throwing invalidCliUsage.
- Commands: doctor, graphql, config validate, auth login/revoke/status,
  cache prune, file download, version/help. JSON on stdout; JSON errors on stderr.

## Tests

- swift-testing (no XCTest), behavior-sentence test names. Wire-level harness:
  URLProtocol subclass gated on the Google host, canned responses by path,
  status-code queue for retry tests, assert-in-stub returning 500 diagnostics.
  Fake auth by injecting `tokenStoreJSON` with year-2999 expiry.

## mise / packaging

- mise pins swift/swiftlint/gitleaks/gh/pre-commit; tasks build/test/lint/run/
  build:homebrew/homebrew:formula; releases local via scripts/ into dist/,
  rendered into ../homebrew-tap. CI: gitleaks + Linux compile smoke only.
- VERSION file read at runtime with hardcoded fallback constant — known footgun;
  in this project derive the version from a single source.

## Doc conventions

- specs normative (`## Status` first), user-qa pending-/qa- files with README
  index, impl-plans active/->completed/ from templates/plan-template.md with
  TASK-NNN blocks, per-file intended signatures, Module Status table, Progress
  Log sessions, and machine-readable impl-plans/PROGRESS.json.

## Do-not-copy

- Stale legacy `Mail*` targets in gmail-gateway Sources are unreferenced leftovers.
- VERSION double-source footgun (above).
