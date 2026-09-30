# google-analytics-gateway

An access token in the profile's `accessTokenEnvironmentVariable` overrides its
OAuth token file, even with an explicit configuration. Login now reports the
written file and the exact variable to unset before using it. Auth status follows
the effective token source, and credential errors identify the selected source
without printing token values. The synthesized environment-only profile remains
available for queries; OAuth login requires a profile with a client and token file.

A GraphQL gateway for Google Analytics (GA4), Google Tag Manager, and Google
tag (gtag) management, usable as role-split CLI executables and as a Swift
library. It wraps the GA4 Admin API v1beta, GA4 Data API v1beta, and Tag
Manager API v2 (including `gtag_config` and destinations, which is how the
Google tag is managed programmatically) behind one capability registry that
drives GraphQL execution, schema printing, and request planning from the same
declarations.

`GoogleAnalyticsGatewayCore` has one neutral dependency, `GatewaySDKKit`, for
the reusable SDK catalog and document-builder contract. Google authentication,
transport, and capability definitions remain self-contained Swift on Foundation.
The package pins the public `tacogips/gateway-sdk-kit` GitHub release.

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

# Search this tier's local schema without credentials or network access
swift run google-analytics-gateway-reader graphql search 'DataStream' \
  --kinds query,object --include-referenced-types --limit 10

# Build and execute a catalog-defined operation
swift run google-analytics-gateway-writer graphql operation gaCreateDataStream \
  --variables '{"parent":"properties/123","dataStream":{"displayName":"Web","type":"WEB_DATA_STREAM"}}' \
  --select dataStream.name,dataStream.displayName
swift run google-analytics-gateway-writer graphql operation gaCreateDataStream \
  --variables-file variables.json --select dataStream.name,dataStream.displayName

# Environment and credential readiness (never prints secret values)
swift run google-analytics-gateway-reader doctor

# OAuth bootstrap for a configured profile (opens a browser, loopback redirect)
swift run google-analytics-gateway-reader auth oauth2 --config profiles.json --profile analytics-reader
swift run google-analytics-gateway-reader auth status --config profiles.json
```

GraphQL execution commands (`query`, `query-file`, and `operation`) write a
GraphQL envelope to stdout (`{"data": ...}` /
`{"data": null, "errors": [...]}`). `graphql search` instead writes a local
`{"count": N, "matches": [...]}` result, while `graphql schema` writes SDL.
Exit codes are 0 success, 2 usage, 3 credential, 4 rejected, 5 transient
upstream, 6 local file, and 70 internal.

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

## Swift SDK library

Import the neutral kit and exactly the tier module you need. Constructors are
tier-safe and cumulative: writer includes reader capabilities; admin includes
writer and reader capabilities. Selecting a constructor never grants a higher
tier.

```swift
import GatewaySDKKit
import GoogleAnalyticsGatewayRead

let sdk = try GoogleAnalyticsGatewaySDK.reader()
precondition(sdk.catalog.validate().isEmpty)
let sdl = sdk.schemaSDL() // Local; no credential is read.
let matches = try sdk.searchSchema(
  "DataStream",
  options: .init(kinds: [.query, .object], includeReferencedTypes: true, limit: 10)
)
```

Use the matching module for cumulative tiers:

```swift
import GatewaySDKKit
import GoogleAnalyticsGatewayWrite
let writer = try GoogleAnalyticsGatewaySDK.writer()

import GoogleAnalyticsGatewayAdmin
let admin = try GoogleAnalyticsGatewaySDK.admin()
```

Named operations use catalog-validated variables and either the bounded default
selection or explicit dot paths. Raw GraphQL retains the same response envelope.
Supply the environment at the host boundary rather than embedding credential
values in source.

```swift
func fetchDataStream(
  with sdk: GoogleAnalyticsGatewaySDK,
  environment: [String: String]
) async -> [GatewayEnvelope] {
  let named = await sdk.invoke(
    GatewayOperationRequest(
      operation: "gaDataStream",
      variables: ["name": .string("properties/123/dataStreams/456")],
      selection: .default
    ),
    environment: environment
  )
  let selected = await sdk.invoke(
    GatewayOperationRequest(
      operation: "gaDataStream",
      variables: ["name": .string("properties/123/dataStreams/456")],
      selection: .fields(["name", "displayName"])
    ),
    environment: environment
  )
  let raw = await sdk.execute(
    document: "query Get($name: ID!) { gaDataStream(name: $name) { name } }",
    variables: ["name": GatewayJSONValue.string("properties/123/dataStreams/456")],
    environment: environment
  )
  return [named, selected, raw]
}
```

Each call returns a `GatewayEnvelope`; inspect its `data`, `errors`,
`requestId`, and `exitCode`. After runtime execution, `rawOutput` contains the
compact GraphQL envelope equivalent to CLI output. Supply only JSON-compatible
finite `Double` values: raw execution does not currently preflight nested
non-finite values before runtime handling.

The per-call environment dictionary is the only environment observed by SDK
`invoke` and `execute` calls. SDK execution never falls back to
`ProcessInfo.processInfo.environment`; hosts should supply credential references
through their own environment dictionary and never print or persist secret values.

## Development

```bash
mise install
mise run build
mise run test
mise run lint
swift run google-analytics-gateway-reader --help
```

Design documents live under `design-docs/` (specs, references including the
authoritative `field-catalog.json` and `field-catalog-v1alpha-extras.json` of
all 283 wrapped API methods, user-qa), implementation plans under
`impl-plans/`.

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

`auth login` opens the browser OAuth flow. `auth oauth2` remains an alias; both
accept `--no-browser` and `--timeout-seconds` and use the selected profile.

### Consistent external credential inputs

Externally obtained credentials remain usable without `auth login`. Product
variables use the `GOOGLE_ANALYTICS_GATEWAY_` prefix and these suffixes:
`ACCESS_TOKEN` (token string), `TOKEN_STORE_JSON` (token JSON contents),
`TOKEN_STORE_PATH` (file path), `OAUTH_CLIENT_JSON` (application JSON contents),
and `OAUTH_CLIENT_PATH` (application client file).
Profile variables use `CREDENTIAL_<NORMALIZED_ID>_<SUFFIX>` under the same prefix;
uppercase IDs and replace hyphens with underscores. Profile variables override
product defaults. Existing configured token variable names remain aliases.

Conflicting aliases and ambiguous token sources are rejected without printing
values. Fresh token JSON/files need no OAuth application. JSON/file tokens still
must match the selected profile/product and exact scope bundle; expired inline
JSON must be replaced. Direct tokens have no local grant metadata, so Google
enforces their granted permissions. Reader/writer/admin command boundaries remain
enforced independently of the token source.

Status recognizes canonical token sources and selected file paths. Login/logout
use canonical path overrides; configuration/token/client path collisions remain
rejected. A supplied application path and token-store path can also configure
login on the synthesized default profile. The shared application client needed
for browser login with no user setup is still pending.

OAuth application JSON supplied through `OAUTH_CLIENT_JSON` stays in memory and
uses the same desktop-client validation as `OAUTH_CLIENT_PATH`. Login and refresh
accept either source. Supplying both for the selected profile is an error.
Application JSON is excluded from serialized profile configuration.

### Default login credential storage

A configuration file and explicit token-store path are optional for login.
The synthesized profile keeps ID `default-env` and exactly the executable's
scope bundle. Credentials default to
`$XDG_STATE_HOME/google-analytics-gateway/credentials/<role>/default-env.json`,
or `~/.local/state/google-analytics-gateway/credentials/<role>/default-env.json`.
Reader, writer, and admin use separate stores. Login and ordinary requests use
the same selected path. A registered application is still required until the
distribution application is configured.

Profile token inputs replace product token defaults as a group. Profile
application inputs follow the same rule: profile application JSON replaces a
product application path. Client/token/config path collision checks still apply.

## gcloud authentication provider

CLI executables support `auth login --provider gcloud`. Gcloud performs browser
login and stores its credentials in a private gateway role/profile directory.
Subsequent commands retrieve fresh tokens from that selected provider without
printing tokens or requiring token environment variables. `auth status`,
`auth refresh`, and `auth revoke` use the selected provider; revocation requires explicit credential/profile selection and preserves the gateway’s confirmation requirements; revocation does not
modify the user's normal gcloud credentials. Explicit external token/JSON/file
inputs still override the stored provider selection.

Gcloud must be installed. `GOOGLE_ANALYTICS_GATEWAY_GCLOUD_PATH` optionally selects an
absolute gcloud executable path, using the same product prefix as credential
inputs. Workspace APIs require a registered Desktop OAuth client even when
using gcloud's application-default login. Service and OCR can use gcloud's
built-in Cloud client. Role permissions, account access, and API-specific
requirements continue to apply.

Provider-free `auth login` uses the native OAuth flow. A maintainer-installed
private `$XDG_CONFIG_HOME/google-analytics-gateway/oauth-client.json` (default:
`~/.config/google-analytics-gateway/oauth-client.json`) supplies its default Desktop
client, preserving explicit OAuth client environment overrides. A successful
native login clears a previous gcloud provider selection. Client registration
is separate from project creation and API enablement. This change does not
claim that client registration or real authorization is complete.

## Callback configuration and Web OAuth

Use the product prefix (`GOOGLE_ANALYTICS_GATEWAY_`) with the same suffixes:

| Suffix | Value |
| --- | --- |
| `OAUTH_REDIRECT_URI` | Public HTTPS callback URL, or HTTP loopback URL |
| `OAUTH_LISTEN_HOST` | Local listener address; defaults to `127.0.0.1` |
| `OAUTH_LISTEN_PORT` | Local listener port; `0` chooses an available port |

Desktop clients require HTTP loopback redirects. Web clients support public
HTTPS redirects and require an exact match to a registered URI in their client
JSON. Put an HTTPS reverse proxy in front of the HTTP listener, forwarding the
callback path unchanged. The listener stops when the login flow ends.

Service gateway's `clients register --file /absolute/client.json --product
PRODUCT [--redirect-uri URI] [--listen-host ADDRESS] [--listen-port PORT]
[--replace]` imports an existing registered Google client and callback settings
for the selected product. This is local configuration, not Google-side OAuth
client creation. Environment values override stored callback settings.
External access tokens and token JSON/path inputs remain supported.
