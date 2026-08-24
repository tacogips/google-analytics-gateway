#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/homebrew-release-common.sh"

usage() {
  cat <<EOF
Usage:
  scripts/render-homebrew-cask.sh <version> [output-file]

Renders one cask that installs every executable from a single DMG:
  $(homebrew_product_list)

Reads archive checksums from:
  dist/homebrew-cask/$homebrew_cask_name-<version>-<target>.dmg.sha256

Environment:
  CASK_RELEASE_DIR       Directory containing archives and .sha256 files.
  CASK_RELEASE_BASE_URL  Release URL base. Defaults to GitHub v<version>.

Example:
  scripts/build-homebrew-cask-release.sh darwin-arm64 darwin-x64
  scripts/render-homebrew-cask.sh 0.1.0 ../homebrew-tap/Casks/$homebrew_cask_name.rb

This renderer expects signed, notarized, and stapled macOS .dmg artifacts.
EOF
}

sha_for_target() {
  local version target release_dir sha_file sha
  version="$1"
  target="$2"
  release_dir="$3"
  sha_file="$release_dir/$homebrew_cask_name-$version-$target.dmg.sha256"

  if [[ ! -f "$sha_file" ]]; then
    printf 'missing checksum file: %s\n' "$sha_file" >&2
    return 1
  fi

  sha="$(awk 'NR == 1 { print $1 }' "$sha_file")"
  if [[ ! "$sha" =~ ^[0-9a-fA-F]{64}$ ]]; then
    printf 'invalid sha256 in %s: %s\n' "$sha_file" "$sha" >&2
    return 1
  fi
  printf '%s\n' "$sha"
}

binary_stanzas() {
  local product
  for product in "${homebrew_products[@]}"; do
    printf '  binary "%s"\n' "$product"
  done
}

caveat_binary_lines() {
  local product
  for product in "${homebrew_products[@]}"; do
    printf '        %s\n' "$product"
  done
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    return
  fi
  if [[ "${1:-}" == "" ]]; then
    usage
    return 2
  fi

  local version output release_dir release_base_url
  version="$1"
  output="${2:-$repo_root/Casks/$homebrew_cask_name.rb}"
  release_dir="${CASK_RELEASE_DIR:-$repo_root/dist/homebrew-cask}"
  release_base_url="${CASK_RELEASE_BASE_URL:-https://github.com/$homebrew_github_repository/releases/download/v$version}"
  validate_homebrew_version "$version"

  local darwin_arm64_sha darwin_x64_sha
  darwin_arm64_sha="$(sha_for_target "$version" darwin-arm64 "$release_dir")"
  darwin_x64_sha="$(sha_for_target "$version" darwin-x64 "$release_dir")"

  mkdir -p "$(dirname "$output")"
  cat > "$output" <<EOF
cask "$homebrew_cask_name" do
  version "$version"
  arch arm: "darwin-arm64", intel: "darwin-x64"

  sha256 arm: "$darwin_arm64_sha",
         intel: "$darwin_x64_sha"

  url "$release_base_url/$homebrew_cask_name-#{version}-#{arch}.dmg",
      verified: "github.com/$homebrew_github_repository/releases/download/"
  name "$homebrew_cask_name"
  desc "$homebrew_cask_desc"
  homepage "$homebrew_homepage"

  livecheck do
    url :url
    strategy :github_latest
  end

$(binary_stanzas)

  caveats do
    <<~EOS
      This cask installs the signed and notarized macOS command line tools.
      Homebrew links every capability tier into the native Homebrew prefix for
      this Mac:

$(caveat_binary_lines)

      Install a single tier instead with the matching Homebrew formula.
    EOS
  end
end
EOF

  printf 'rendered %s\n' "$output"
}

main "$@"
