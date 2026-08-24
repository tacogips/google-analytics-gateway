# shellcheck shell=bash

homebrew_products=(
  "google-analytics-gateway-reader"
  "google-analytics-gateway-writer"
  "google-analytics-gateway-admin"
)

# The cask ships every executable in one DMG, so it needs a bundle-level name
# that is not any single product name.
# shellcheck disable=SC2034 # consumed by the scripts that source this file
homebrew_cask_name="google-analytics-gateway"
# shellcheck disable=SC2034
homebrew_cask_desc="Swift GraphQL gateway CLIs for Google Analytics and Tag Manager"
# shellcheck disable=SC2034
homebrew_github_repository="tacogips/google-analytics-gateway"
# shellcheck disable=SC2034
homebrew_homepage="https://github.com/tacogips/google-analytics-gateway"

homebrew_product_list() {
  local product separator
  separator=""
  for product in "${homebrew_products[@]}"; do
    printf '%s%s' "$separator" "$product"
    separator="  "
  done
  printf '\n'
}

is_homebrew_product() {
  local candidate product
  candidate="$1"
  for product in "${homebrew_products[@]}"; do
    if [[ "$candidate" == "$product" ]]; then
      return 0
    fi
  done
  return 1
}

validate_homebrew_product() {
  if ! is_homebrew_product "$1"; then
    printf 'unsupported Swift Homebrew product: %s\n' "$1" >&2
    printf 'supported products: %s\n' "$(homebrew_product_list)" >&2
    return 1
  fi
}

homebrew_formula_class() {
  case "$1" in
    google-analytics-gateway-reader) printf '%s\n' "GoogleAnalyticsGatewayReader" ;;
    google-analytics-gateway-writer) printf '%s\n' "GoogleAnalyticsGatewayWriter" ;;
    google-analytics-gateway-admin) printf '%s\n' "GoogleAnalyticsGatewayAdmin" ;;
    *)
      validate_homebrew_product "$1"
      ;;
  esac
}

homebrew_formula_desc() {
  case "$1" in
    google-analytics-gateway-reader)
      printf '%s\n' "Read-only GraphQL gateway for Google Analytics and Tag Manager"
      ;;
    google-analytics-gateway-writer)
      printf '%s\n' "GraphQL gateway for Google Analytics and Tag Manager with write access"
      ;;
    google-analytics-gateway-admin)
      printf '%s\n' "GraphQL gateway for Google Analytics and Tag Manager with admin access"
      ;;
    *)
      validate_homebrew_product "$1"
      ;;
  esac
}

validate_homebrew_version() {
  local version
  version="$1"

  if [[ "$version" == *..* || ! "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z][0-9A-Za-z.+-]*)?$ ]]; then
    printf 'unsafe release version: %s\n' "$version" >&2
    printf 'expected archive-safe semver-like value without path separators or parent traversal\n' >&2
    return 1
  fi
}
