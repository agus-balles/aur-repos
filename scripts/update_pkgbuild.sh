#!/usr/bin/env bash
set -euo pipefail

PKGNAME="llmfit"
UPSTREAM_OWNER="AlexsJones"     
UPSTREAM_REPO="llmfit"      # <-- change

latest_tag="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases/latest" | jq -r '.tag_name')"
latest="${latest_tag#v}"

current="$(awk -F= '$1=="pkgver"{print $2}' PKGBUILD)"

echo "Current: $current"
echo "Latest:  $latest"

if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "Could not detect latest release tag"
  exit 1
fi

if [[ "$latest" == "$current" ]]; then
  echo "Already up to date."
  exit 0
fi

sed -i "s/^pkgver=.*/pkgver=${latest}/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD

updpkgsums
makepkg --printsrcinfo > .SRCINFO
