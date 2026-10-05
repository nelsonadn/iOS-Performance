#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/ruby "$repo_root/benchmark-runner/compare.rb" "$@"
