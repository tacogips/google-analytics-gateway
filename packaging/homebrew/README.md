# Homebrew Packaging

The package builds three executables, one per capability tier:

| Executable | Formula class | Tier |
|---|---|---|
| `google-analytics-gateway-reader` | `GoogleAnalyticsGatewayReader` | read |
| `google-analytics-gateway-writer` | `GoogleAnalyticsGatewayWriter` | write |
| `google-analytics-gateway-admin` | `GoogleAnalyticsGatewayAdmin` | admin |

`scripts/homebrew-release-common.sh` is the single registry of those product
names, formula class names, and formula descriptions. Every release script
sources it, so adding or renaming an executable is a one-file change.

This project ships two Homebrew release paths:

- Formula: one unsigned tarball and one formula per executable, so a user can
  install only the capability tier they need.
- Cask: one signed, notarized, and stapled macOS DMG per architecture that
  carries all three executables, installed together by a single cask.

Swift formula archives are macOS-only by default. Add Linux archives only after
the project has a reviewed Swift Linux build and runtime contract.

## Formula

Build release archives for every product:

```bash
scripts/build-homebrew-release.sh darwin-arm64 darwin-x64
```

Pass product names to build a subset. Products and targets can be given in any
order:

```bash
scripts/build-homebrew-release.sh google-analytics-gateway-reader darwin-arm64 darwin-x64
```

The command writes an archive and checksum per product and target under
`dist/homebrew/`:

```text
dist/homebrew/google-analytics-gateway-reader-<version>-darwin-arm64.tar.gz
dist/homebrew/google-analytics-gateway-reader-<version>-darwin-arm64.tar.gz.sha256
dist/homebrew/google-analytics-gateway-reader-<version>-darwin-x64.tar.gz
dist/homebrew/google-analytics-gateway-reader-<version>-darwin-x64.tar.gz.sha256
dist/homebrew/google-analytics-gateway-writer-<version>-darwin-arm64.tar.gz
dist/homebrew/google-analytics-gateway-writer-<version>-darwin-arm64.tar.gz.sha256
dist/homebrew/google-analytics-gateway-writer-<version>-darwin-x64.tar.gz
dist/homebrew/google-analytics-gateway-writer-<version>-darwin-x64.tar.gz.sha256
dist/homebrew/google-analytics-gateway-admin-<version>-darwin-arm64.tar.gz
dist/homebrew/google-analytics-gateway-admin-<version>-darwin-arm64.tar.gz.sha256
dist/homebrew/google-analytics-gateway-admin-<version>-darwin-x64.tar.gz
dist/homebrew/google-analytics-gateway-admin-<version>-darwin-x64.tar.gz.sha256
```

Publish those assets to the GitHub release named `v<version>`, then render the
formulae into a tap checkout. The renderer takes an output *directory* and
writes `<product>.rb` into it:

```bash
scripts/render-homebrew-formula.sh <version> ../homebrew-tap/Formula
```

Render a single product's formula by naming it before the output directory:

```bash
scripts/render-homebrew-formula.sh <version> google-analytics-gateway-reader ../homebrew-tap/Formula
```

## Cask

The cask ships every executable in one DMG, so the cask builder has no product
argument. Build signed and notarized DMGs on macOS:

```bash
kinko exec --env APPLE_SIGNING_IDENTITY,APPLE_ID,APPLE_PASSWORD,APPLE_TEAM_ID -- \
  scripts/build-homebrew-cask-release.sh darwin-arm64 darwin-x64
```

Each DMG contains all three signed binaries. This writes:

```text
dist/homebrew-cask/google-analytics-gateway-<version>-darwin-arm64.dmg
dist/homebrew-cask/google-analytics-gateway-<version>-darwin-arm64.dmg.sha256
dist/homebrew-cask/google-analytics-gateway-<version>-darwin-x64.dmg
dist/homebrew-cask/google-analytics-gateway-<version>-darwin-x64.dmg.sha256
```

Render the Cask, which declares one `binary` stanza per executable:

```bash
scripts/render-homebrew-cask.sh <version> ../homebrew-tap/Casks/google-analytics-gateway.rb
```

For a tagged release, the local wrapper verifies the tag, builds DMGs, uploads
release assets, and renders the tap Cask:

```bash
kinko exec --env APPLE_SIGNING_IDENTITY,APPLE_ID,APPLE_PASSWORD,APPLE_TEAM_ID -- \
  scripts/release-homebrew-cask-local.sh v<version>
```

## Verification

From the tap checkout:

```bash
for product in google-analytics-gateway-reader google-analytics-gateway-writer google-analytics-gateway-admin; do
  ruby -c "Formula/$product.rb"
  brew audit --strict "$product" || brew audit --strict --formula "$product"
done

ruby -c Casks/google-analytics-gateway.rb
brew fetch --cask tacogips/tap/google-analytics-gateway
HOMEBREW_NO_GITHUB_API=1 brew audit --cask tacogips/tap/google-analytics-gateway
```

If online audit fails due local GitHub credentials or rate limits, run the
non-online audit and record the limitation.
