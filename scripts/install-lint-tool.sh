#!/usr/bin/env bash
# Build and install ansible-lint-but-fast at the commit pinned in .ansible-lint-but-fast-rev.
# The installed binary is called ansible-rust-lint. CI and contributors both use this script.
# Usage: scripts/install-lint-tool.sh [cargo install --root DIR]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rev="$(tr -d '[:space:]' < "${repo_root}/.ansible-lint-but-fast-rev")"

if ! command -v cargo > /dev/null; then
  echo "cargo is required to build the linter; install a Rust toolchain first" >&2
  exit 1
fi

exec cargo install --locked \
  --git https://github.com/gruentee/ansible-lint-but-fast \
  --rev "${rev}" \
  "$@" \
  ansible-lint
