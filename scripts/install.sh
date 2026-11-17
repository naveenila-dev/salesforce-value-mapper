#!/usr/bin/env bash
# Run from any directory. Never uses the CLI's default org.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bash scripts/install.sh --target-org ALIAS_OR_USERNAME [options]

  --with-examples         Also deploy the four fictional demo mappings
  --dry-run               Validate deployment and tests without saving changes
  --test-level LEVEL      RunSpecifiedTests (default) or RunLocalTests
  --wait MINUTES          Wait for deployment completion (default: 30)
  --help                  Show this help

Authorize your org first with sf org login web. A completed installation runs
the configuration-independent smoke check; --with-examples also runs the demo.
If the CLI times out, use the deployment ID to check its final status before
running the smoke scripts manually. No smoke scripts run after an error/timeout.
USAGE
}

target_org=''
with_examples=false
dry_run=false
test_level=RunSpecifiedTests
wait_minutes=30
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org|--test-level|--wait)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "Missing value for $1" >&2
        exit 2
      fi
      case "$1" in
        --target-org) target_org="$2" ;;
        --test-level) test_level="$2" ;;
        --wait) wait_minutes="$2" ;;
      esac
      shift 2
      ;;
    --with-examples) with_examples=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$target_org" || "$target_org" == -* ]]; then
  echo 'An explicit --target-org ALIAS_OR_USERNAME is required.' >&2
  exit 2
fi
if [[ "$test_level" != RunSpecifiedTests && "$test_level" != RunLocalTests ]]; then
  echo '--test-level must be RunSpecifiedTests or RunLocalTests.' >&2
  exit 2
fi
if [[ ! "$wait_minutes" =~ ^[1-9][0-9]*$ ]]; then
  echo '--wait must be a positive whole number of minutes.' >&2
  exit 2
fi
command -v sf >/dev/null || { echo 'Install Salesforce CLI (sf) first.' >&2; exit 1; }

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
deploy_args=(project deploy start --source-dir force-app --target-org "$target_org"
  --test-level "$test_level" --wait "$wait_minutes")
if [[ "$test_level" == RunSpecifiedTests ]]; then
  deploy_args+=(--tests MappingResolverTest --tests MappingFlowActionTest)
fi
if [[ "$with_examples" == true ]]; then
  deploy_args+=(--source-dir examples)
fi
if [[ "$dry_run" == true ]]; then
  deploy_args+=(--dry-run)
fi

echo "Deploying Salesforce Value Mapper to: $target_org"
sf "${deploy_args[@]}"
if [[ "$dry_run" == true ]]; then
  echo 'Validation succeeded. No changes were saved; smoke checks were skipped.'
  exit 0
fi
sf apex run --file scripts/apex/value-mapper-smoke.apex --target-org "$target_org"
if [[ "$with_examples" == true ]]; then
  sf apex run --file scripts/apex/value-mapper-demo.apex --target-org "$target_org"
fi
echo 'Salesforce Value Mapper installation and smoke checks passed.'
