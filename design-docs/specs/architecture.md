# Architecture

## Status

Accepted design (2026-08-24), pending implementation.

## Overview

`google-analytics-gateway` wraps Google Analytics (GA4 Admin API v1beta, phased
v1alpha extras), GA4 Data API v1beta, Google Tag Manager API v2, and Google tag
(gtag) management behind a GraphQL execution surface. It is usable two ways:

1. Role-split CLI executables accepting one-shot GraphQL documents and printing
   GraphQL-envelope JSON.
2. A Swift library exposing the same capability registry, runtime, and typed
   request plumbing to Swift callers.

Zero external SwiftPM dependencies. The synthesis rule (see
references/marketing-gateway-and-wrike-gateway-notes.md):

- GraphQL engine, capability registry, and tier model: ported from
  ../wrike-gateway (`WrikeGatewayCore/GraphQL/` and its
  CapabilityDefinition registration model).
- Google OAuth (PKCE desktop + loopback), secure file I/O, credential profiles,
  HTTP transport with redirect rejection, error sanitization: ported from
  ../google-marketing-gateway.
- CLI purity, doctor UX, doc/test conventions: gmail-gateway + marketing-gateway
  (see references/gmail-gateway-architecture-notes.md).

## Targets (mirrors wrike-gateway's link-boundary tier model)

```
products:
  .library  GoogleAnalyticsGatewayCore    [Core]
  .library  GoogleAnalyticsGatewayRead    [Core, Read]
  .library  GoogleAnalyticsGatewayWrite   [Core, Read, Write]
  .library  GoogleAnalyticsGatewayAdmin   [Core, Read, Write, Admin]
  .executable google-analytics-gateway-reader  [ReaderCLI]
  .executable google-analytics-gateway-writer  [WriterCLI]
  .executable google-analytics-gateway-admin   [AdminCLI]
targets:
  Core   — GraphQL engine, capability framework, OAuth, transport, secure files,
           config/profiles, error taxonomy, shared CLI runner, name-only
           CapabilityCatalog (for CAPABILITY_DENIED + requiredTier answers)
  Read   — reader-tier CapabilityDefinitions (GA admin reads, Data API reports,
           GTM reads, snippet/status/metadata)
  Write  — writer-tier definitions (GA admin creates/updates, GTM workspace
           mutations, versions, publish, gtag_config)
  Admin  — admin-tier definitions (deletes, user permissions, account
           provisioning, destinations link, combine/move_tag_id)
  ReaderCLI/WriterCLI/AdminCLI — 9-line shims
  TestSupport (Tests/ path) — recording transport, loopback helpers, seams;
           no executable depends on it
```

Capability enforcement, four layers (wrike model): link boundary (reader binary
physically lacks writer code; asserted by a linked-symbol test), registry
construction refuses above-tier definitions, dispatch answers CAPABILITY_DENIED
with requiredTier via the name-only catalog, planner re-checks. Plus
marketing-gateway's profile validation: credential profiles carry exact
per-capability scope bundles.

The template `AppCore`/`AppCLI` targets are removed.

## GraphQL engine (ported subset)

Lexer / constrained AST / recursive-descent parser (64KB document cap, 10
top-level fields, depth 8) / runtime envelope / SDL printer / selection
projection. Supported: named+shorthand operations, JSON variables, scalars,
enums, lists, input objects, nested selections. Rejected: fragments, aliases,
directives, subscriptions, introspection, unions, interfaces, variable
defaults, multiple operations, multi-field mutations. Unsupported syntax fails
before credential resolution or network access.

Schema is Swift values only: each Google API method is one CapabilityDefinition
(field, tier, HTTP method, path template, argument definitions with data-typed
bindings, result shape, OAuth scopes, page limits). The SDL printer and request
planner read the same values; `graphql schema` renders SDL locally. See
specs/graphql-schema.md for the field naming rules and catalog conventions.

## Google API layer

- HTTPTransport protocol + URLSessionTransport (.ephemeral) +
  RejectingRedirectDelegate. Origins are internal constants
  (analyticsadmin.googleapis.com, analyticsdata.googleapis.com,
  tagmanager.googleapis.com); no route accepts a caller-supplied origin, header,
  or raw body.
- A generic RequestBuilder interprets ArgumentBinding data; responses pass
  through as raw JSON (UTF-8 checked) and are projected against the GraphQL
  selection.
- Provider errors sanitized structurally (status/errorCode matching
  ^[A-Z][A-Z0-9_]{0,79}$ only).
- Pagination: {nodes, pageInfo{resultCount, nextPageToken}} + page: PageInput;
  over-limit page sizes rejected.

## Mutation safety

Destructive/administrative mutations (deletes, publish, user permissions,
account-level changes) require confirmation arguments echoing the target
resource path (marketing-gateway's exact-match confirm pattern, carried into
GraphQL arguments, e.g. `gtmDeleteContainer(path:, confirmPath:)`). Where
Google offers validateOnly (GTM publish has none; GA admin create/update
mostly none) it is exposed as an optional argument.

## Auth

See specs/auth.md. PKCE desktop OAuth with loopback receiver, hard-pinned
endpoints, exact scope-set verification, profile-declared env var names,
kinko-injected secrets, secure token stores via SecureLocalFiles.

## Covered API surfaces

See references/google-api-surfaces.md and the discovery dumps: GA4 Admin v1beta
(55 methods), GA4 Data v1beta (11), Tag Manager v2 (106; includes gtag_config +
destinations + snippet = Google tag), GA4 Admin v1alpha extras phased in after
v1beta parity.

## Release Surfaces

- Homebrew formula archives under `dist/homebrew/`
- Signed and notarized Cask DMGs under `dist/homebrew-cask/`
