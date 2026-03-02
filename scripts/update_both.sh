#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible wrapper.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update_packages.sh"
