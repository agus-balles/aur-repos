#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_OWNER="AlexsJones"
UPSTREAM_REPO="llmfit"

# Always operate relative to the git repo root
ROOT="$(git rev-parse --show-toplevel)"

latest_tag="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases/latest" | jq -r '.tag_name')"
latest="${latest_tag#v}"

if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "Could not detect latest release tag"
  exit 1
fi

echo "Latest upstream version: $latest"

bump_pkgver() {
  local dir="$1"
  local file="${dir}/PKGBUILD"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: PKGBUILD not found at: $file"
    echo "Repo root: $ROOT"
    echo "Contents of $dir:"
    ls -la "$dir" || true
    exit 1
  fi

  echo "==> Updating $dir"
  sed -i "s/^pkgver=.*/pkgver=${latest}/" "$file"
  if grep -q '^pkgrel=' "$file"; then
    sed -i "s/^pkgrel=.*/pkgrel=1/" "$file"
  fi
}

# llmfit (source build)
bump_pkgver "${ROOT}/llmfit"
( cd "${ROOT}/llmfit" && makepkg --printsrcinfo > .SRCINFO )

# llmfit-bin (prebuilt)
bump_pkgver "${ROOT}/llmfit-bin"
( cd "${ROOT}/llmfit-bin" && updpkgsums && makepkg --printsrcinfo > .SRCINFO )

echo "Done."
