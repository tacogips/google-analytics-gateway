# google-analytics-gateway

A GraphQL gateway for Google Analytics (GA4), Google Tag Manager, and Google
tag (gtag) management, usable as role-split CLI executables and as a Swift
library. It wraps the GA4 Admin API v1beta, GA4 Data API v1beta, and Tag
Manager API v2 (including `gtag_config` and destinations, which is how the
Google tag is managed programmatically) behind one capability registry that
drives GraphQL execution, schema printing, and request planning from the same
declarations.

Zero external dependencies: the GraphQL engine, OAuth 2.0 PKCE flow, and HTTP
transport are self-contained Swift on Foundation.

## Executables

Capability tiers are cumulative and separated at link boundaries — the reader
binary physically contains no write or admin code:

| Binary | Tier | Serves |
|---|---|---|
| `google-analytics-gateway-reader` | reader | gets, lists, reports, metadata, compatibility, snippets |
| `google-analytics-gateway-writer` | writer | reader + creates/updates, GTM workspace mutations, versions, publish, gtag configs |
| `google-analytics-gateway-admin` | admin | writer + deletes (confirmation required), user permissions, provisioning, destination links |

## Usage

```bash
# Print the SDL schema this binary serves (rendered locally, never fetched)
swift run google-analytics-gateway-reader graphql schema

# Execute GraphQL (one operation per document; variables as a JSON object)
swift run google-analytics-gateway-reader graphql query \
  'query { gaAccountSummaries { nodes { name displayName } } }'

swift run google-analytics-gateway-reader graphql query-file query.graphql \
  --variables-file variables.json

# Environment and credential readiness (never prints secret values)
swift run google-analytics-gateway-reader doctor

# OAuth bootstrap for a configured profile (opens a browser, loopback redirect)
swift run google-analytics-gateway-reader auth oauth2 --config profiles.json --profile analytics-reader
swift run google-analytics-gateway-reader auth status --config profiles.json
```

Output is a GraphQL envelope on stdout (`{"data": ...}` /
`{"data": null, "errors": [...]}`), exit codes: 0 success, 2 usage,
3 credential, 4 rejected, 5 transient upstream, 6 local file, 70 internal.

## Credentials

Credential profiles are JSON naming environment variables, never secret values
(see `design-docs/specs/auth.md`):

```json
{ "profiles": [ {
  "id": "analytics-reader",
  "product": "combined",
  "capability": "reader",
  "oauthScopes": [
    "https://www.googleapis.com/auth/analytics.readonly",
    "https://www.googleapis.com/auth/tagmanager.readonly"
  ],
  "accessTokenEnvironmentVariable": "GA_GATEWAY_READER_TOKEN",
  "oauthClientJSONPath": "oauth-client.json",
  "tokenStorePath": "token-store.json"
} ] }
```

Pass `--config`, or set `GOOGLE_ANALYTICS_GATEWAY_CONFIG`. With no
configuration at all, a synthesized profile reads an access token from
`GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN` (kinko-friendly for non-interactive
use). Scope bundles are validated exactly per capability; the reader binary
cannot bootstrap writer scopes.

## Swift library

The `GoogleAnalyticsGatewayRead` / `...Write` / `...Admin` library products
expose the same runtime: build a `CapabilityRegistry` from the tier's
definitions, wire a `CapabilityExecutor` with your `CredentialProvider`, and
call `GraphQLRuntime.execute(document:variables:)` — or call the
`CapabilityExecutor` directly with typed invocations, bypassing GraphQL.

## Development

```bash
mise install
mise run build
mise run test
mise run lint
swift run google-analytics-gateway-reader --help
```

Design documents live under `design-docs/` (specs, references including the
authoritative `field-catalog.json` of all 172 wrapped API methods, user-qa),
implementation plans under `impl-plans/`.

## Homebrew Formula

Build local formula archives:

```bash
mise run build:homebrew -- darwin-arm64 darwin-x64
```

Render a formula after both platform archives exist:

```bash
mise run homebrew:formula -- 0.1.0
```

Render directly into the default sibling tap checkout:

```bash
mise run homebrew:tap-formula -- 0.1.0
```

Install from the tap after the formula is published:

```bash
brew tap user/tap
brew install google-analytics-gateway
```

## Homebrew Cask

The Cask workflow builds signed, notarized, and stapled macOS DMG artifacts.
Apple signing credentials must stay local and must not be committed.

Check the build plan:

```bash
mise run build:homebrew-cask -- --dry-run darwin-arm64 darwin-x64
```

Build with local signing credentials:

```bash
kinko exec --env APPLE_SIGNING_IDENTITY,APPLE_ID,APPLE_PASSWORD,APPLE_TEAM_ID -- \
  mise run build:homebrew-cask -- darwin-arm64 darwin-x64
```

Render a Cask:

```bash
mise run homebrew:cask -- 0.1.0
```

For a tagged release, build, upload, and render the tap Cask:

```bash
kinko exec --env APPLE_SIGNING_IDENTITY,APPLE_ID,APPLE_PASSWORD,APPLE_TEAM_ID -- \
  mise run release:homebrew-cask-local -- v0.1.0
```

See `packaging/homebrew/README.md` and `.agents/skills/` for release workflows.
