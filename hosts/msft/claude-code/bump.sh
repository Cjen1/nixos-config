#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$package_dir" rev-parse --show-toplevel)"
exec bash "$repo_root/scripts/bump-npm-package.sh" \
  "$package_dir" "@anthropic-ai/claude-code" "claude-code" "$@"
