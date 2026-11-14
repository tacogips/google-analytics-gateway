# Authentication and Credentials

## Status

Accepted design (2026-08-24), pending implementation.

## Model

Ported from google-marketing-gateway's OAuth stack: OAuth2 authorization-code +
PKCE (S256) against a Google desktop (`installed`) OAuth client, loopback
receiver on 127.0.0.1 (ephemeral port) with strict request validation (exact
{state, code} query, size caps, invalid-connection limit), hard-pinned
authorization/token endpoints that the client JSON must match, and token
exchange requiring `token_type == Bearer`, bounded `expires_in`, and an exact
returned-scope-set match. Non-interactive callers may instead inject a ready
access token via a profile-named environment variable (kinko-friendly, no files
on disk).

## Credential profiles

JSON profile config (marketing-gateway `CredentialProfiles` pattern; strict
unknown-field rejection). Profiles declare env var NAMES, never values:

```json
{ "profiles": [ {
  "id": "analytics-reader",
  "product": "analytics",
  "capability": "reader",
  "oauthScopes": ["https://www.googleapis.com/auth/analytics.readonly",
                   "https://www.googleapis.com/auth/tagmanager.readonly"],
  "accessTokenEnvironmentVariable": "GOOGLE_ANALYTICS_GATEWAY_ACCESS_TOKEN",
  "oauthClientJSONPath": "oauth-client.json",
  "tokenStorePath": "token-store.json"
} ] }
```

Capability -> exact scope bundle validation at load time (bundles in
references/google-api-surfaces.md). Config path via `--config` or
`GOOGLE_ANALYTICS_GATEWAY_CONFIG`. Relative paths resolve against the config
file directory; path collisions rejected.

## Token store

JSON with schemaVersion, profileId, product, accessToken, refreshToken,
tokenType, expiresAt, updatedAt, scopes, at the profile-named path only (no
default location). Reads verify profile id, product, and scope set. All token
I/O goes through SecureLocalFiles (openat/O_NOFOLLOW traversal, TOCTOU-stable
reads, 0600 atomic writes, private-parent checks). Credential resolution order:
access-token env var, then token store; lazy refresh at 60s expiry under a
per-path lock.

## Capability enforcement layers

1. Link boundary: role binaries link only their tier's library targets
   (asserted by a linked-symbol test).
2. Registry construction refuses above-tier definitions; GraphQL dispatch
   answers `CAPABILITY_DENIED` with `requiredTier` via the name-only catalog.
3. Credential profile capability + exact scope-bundle validation at load and
   login; the planner re-checks before building requests.
4. Google enforces scopes server-side (defense in depth).

## Commands

`auth login|logout|status --profile <id>` (auth lives in every binary but only
bootstraps that binary's scope bundle) and `doctor` follow the reference UX:
JSON output, no secret values printed (presence flags only), config errors and
auth errors distinguished by exit code and error code.
