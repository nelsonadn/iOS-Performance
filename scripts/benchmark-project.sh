#!/bin/bash
set -euo pipefail
exec /usr/bin/ruby "$(cd "$(dirname "$0")/.." && pwd)/benchmark-runner/benchmark.rb" "$@"
