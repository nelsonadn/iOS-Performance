#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
scenario="${1:-}"
if [[ -z "$scenario" ]]; then echo "usage: $0 SCENARIO [--config FILE]" >&2; exit 64; fi
shift
config="$repo_root/performance-projects.yml"
if [[ ! -f "$config" ]]; then echo "Missing $config. Copy performance-projects.yml.example and set external repository paths." >&2; exit 66; fi
projects="$(/usr/bin/ruby -ryaml -e 'puts YAML.safe_load_file(ARGV[0], permitted_classes: [], aliases: false)["projects"].keys' "$config")"
if [[ -z "$projects" ]]; then echo "No projects configured in $config" >&2; exit 65; fi
for project in $projects; do
  "$repo_root/scripts/benchmark-project.sh" --config "$config" --project "$project" --scenario "$scenario" "$@"
done
