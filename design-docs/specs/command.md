# Command

## Status

Implemented SDK command extension (2026-09-04).

## CLI contract

```bash
google-analytics-gateway-{reader|writer|admin} [--pretty] [--config <path>] [--profile <id>] <command>

graphql query '<document>' [--variables '<json-object>']
graphql query-file <path> [--variables-file <path>]
graphql schema
graphql search <regex> [--kinds <csv>] [--include-referenced-types] [--limit <positive-int>]
graphql operation <name> [--variables <json> | --variables-file <path>] [--select <csv-dot-paths>]
auth oauth2 [--no-browser] [--timeout-seconds <n>]
auth status
auth logout
doctor
```

`graphql query`, `graphql query-file`, and `graphql schema` retain their current
behavior. Search is local and credential-free and returns stable JSON matches
from the executable's tier catalog. Operation mode uses the shared SDK document
builder and then the existing command-frame runtime, preserving profile,
environment, envelope, and exit-code behavior. Known operations above the
linked tier fail with `CAPABILITY_DENIED` before credential or network access.

The complete grammar, output contract, validation rules, and compatibility
boundary are specified in `specs/design-gateway-sdk.md`.
