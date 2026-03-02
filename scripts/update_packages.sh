#!/usr/bin/env bash
set -euo pipefail

# Auto-discover package directories at repository root.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for cmd in makepkg updpkgsums curl jq sed awk find sort; do
  command -v "$cmd" >/dev/null || {
    echo "Missing required command: $cmd"
    exit 1
  }
done

mapfile -t package_dirs < <(
  find "$ROOT" -mindepth 2 -maxdepth 2 -name PKGBUILD -printf '%h\n' | sort
)

if [[ "${#package_dirs[@]}" -eq 0 ]]; then
  echo "No PKGBUILD files found."
  exit 0
fi

get_var() {
  local file="$1"
  local var_name="$2"
  awk -v k="$var_name" -F= '$1==k {sub(/^[[:space:]]+/, "", $2); print $2; exit}' "$file"
}

strip_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  echo "$value"
}

extract_github_repo() {
  local pkgbuild="$1"
  local override
  local url
  local repo

  override="$(strip_quotes "$(get_var "$pkgbuild" "_update_upstream_repo")")"
  if [[ -n "$override" ]]; then
    echo "${override%.git}"
    return 0
  fi

  url="$(strip_quotes "$(get_var "$pkgbuild" "url")")"
  repo="$(sed -nE 's#^https?://github.com/([^/]+/[^/]+)(/.*)?$#\1#p' <<<"$url")"
  if [[ -n "$repo" ]]; then
    echo "${repo%.git}"
    return 0
  fi

  return 1
}

latest_version_for_repo() {
  local repo="$1"
  local response
  local latest_tag

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    response="$(curl -fsSL \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${repo}/releases/latest")"
  else
    response="$(curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${repo}/releases/latest")"
  fi

  latest_tag="$(jq -r '.tag_name // empty' <<<"$response")"
  latest_tag="${latest_tag#v}"
  echo "$latest_tag"
}

bump_pkgbuild_version() {
  local file="$1"
  local latest="$2"
  sed -i -E "s/^pkgver=.*/pkgver=${latest}/" "$file"
  if grep -q '^pkgrel=' "$file"; then
    sed -i -E "s/^pkgrel=.*/pkgrel=1/" "$file"
  fi
}

needs_checksums_update() {
  local file="$1"
  if grep -q "SKIP" "$file"; then
    return 1
  fi
  return 0
}

echo "Discovered packages:"
for dir in "${package_dirs[@]}"; do
  echo "  - ${dir#$ROOT/}"
done

for dir in "${package_dirs[@]}"; do
  pkgbuild="${dir}/PKGBUILD"
  pkgname="${dir#$ROOT/}"
  current="$(get_var "$pkgbuild" "pkgver")"

  if ! repo="$(extract_github_repo "$pkgbuild")"; then
    echo "==> ${pkgname}: no GitHub upstream detected (url/_update_upstream_repo). Skipping."
    continue
  fi

  latest="$(latest_version_for_repo "$repo")"
  if [[ -z "$latest" || "$latest" == "null" ]]; then
    echo "==> ${pkgname}: could not detect latest release for ${repo}. Skipping."
    continue
  fi

  if [[ "$latest" == "$current" ]]; then
    echo "==> ${pkgname}: already up to date (${current})."
    continue
  fi

  echo "==> ${pkgname}: ${current} -> ${latest}"
  bump_pkgbuild_version "$pkgbuild" "$latest"

  if needs_checksums_update "$pkgbuild"; then
    (cd "$dir" && updpkgsums)
  fi

  (cd "$dir" && makepkg --printsrcinfo > .SRCINFO)
done

echo "Done."
