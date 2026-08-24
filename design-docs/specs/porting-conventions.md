# Porting Conventions (wrike-gateway / google-marketing-gateway -> this repo)

## Status

Normative for the foundation port (2026-08-24).

## Sources

- GraphQL engine, capability framework, transport shape, CLI composition:
  ../wrike-gateway/Sources/WrikeGatewayCore
- Google OAuth (PKCE desktop + loopback), SecureLocalFiles, credential
  profiles: ../google-marketing-gateway/Sources/GoogleMarketingGatewayCore

## Renames

- Module `WrikeGatewayCore` -> `GoogleAnalyticsGatewayCore`; Read/Write/Admin and
  CLI targets follow the Package.swift names already in this repo.
- `WrikeValue` -> `JSONValue`; `WrikeValueCoding` -> `JSONValueCoding`.
- `WrikeRequest` -> `UpstreamRequest`; `URLSessionWrikeTransport` ->
  `URLSessionGoogleTransport`; `WrikeHostPolicy` -> `GoogleHostPolicy`;
  transport protocol name: `GoogleTransport` (mirror wrike's protocol shape).
- Drop `WrikeIdentifier` (Google resource names are validated strings bound per
  capability); keep `SecretValue` as is.
- Keep type names `GatewayError`, `GatewayErrorCode`, `GatewayExitCode`,
  `CapabilityID`, `CapabilityTier` (reader/writer/admin), `OperationClass`,
  `CapabilityStatus`, `CapabilityDefinition`, `CapabilityRegistry`,
  `CapabilityCatalog`, `CapabilityPlanner`, `CapabilityExecutor`, `ModelShape`,
  `ArgumentCoercion`, `ResponseProjection`, `GatewayComposition`,
  `CommandFrame`, `CommandArguments`, `AuthCommands`.
- Comment/doc text: replace Wrike references with Google API equivalents;
  do not delete the explanatory comments — adapt them.

## Google specifics

- Services enum `GoogleAPIService`: `analyticsAdminV1Beta`
  (https://analyticsadmin.googleapis.com), `analyticsAdminV1Alpha`,
  `analyticsDataV1Beta` (https://analyticsdata.googleapis.com), `tagManagerV2`
  (https://tagmanager.googleapis.com). Origins are internal constants; a
  CapabilityDefinition names its service; GoogleHostPolicy allows exactly these
  hosts plus https://oauth2.googleapis.com and
  https://accounts.google.com (auth only).
- ScopeRequirement rewritten for Google scopes (see
  references/google-api-surfaces.md): readers accept the readonly scope or any
  broader bundle scope that Google documents as sufficient; recommended is the
  least-privilege scope.
- OAuth: marketing-gateway semantics exactly — hard-pinned
  authorization/token endpoints, desktop client JSON must match them, PKCE
  S256, loopback receiver validation and caps, exact returned-scope-set match,
  bounded expires_in, Bearer only.
- Credential profiles: products {`analytics`, `tag-manager`, `combined`},
  capabilities {reader, writer, admin}, exact scope bundles per
  references/google-api-surfaces.md ("Role-split executables map to scope
  sets"; `combined` carries the union bundle for its capability). Env var names
  declared in profiles; `GOOGLE_ANALYTICS_GATEWAY_CONFIG` fallback for the
  config path.

## Style

- Swift 6 strict concurrency (`Sendable`, no `@unchecked` outside test
  doubles), Foundation-only, no external deps, files under 1000 lines,
  2-space indent matching the reference sources, no emoji.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`), behavior-
  sentence names, fixture secrets spelled `fixture-token-not-a-secret`.
