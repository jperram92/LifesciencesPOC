#!/usr/bin/env bash

set -euo pipefail

ORG_ALIAS="${1:-LifesciencesPOC}"

if ! command -v sf >/dev/null 2>&1 && ! command -v cmd.exe >/dev/null 2>&1; then
  echo "sf CLI is required but was not found on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but was not found on PATH." >&2
  exit 1
fi

run_sf_display() {
  if command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c sf org display --verbose --target-org "$ORG_ALIAS" --json
  else
    sf org display --verbose --target-org "$ORG_ALIAS" --json
  fi
}

ORG_JSON="$(run_sf_display | tr -d '\r')"

INSTANCE_URL="$(printf '%s' "$ORG_JSON" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("result", {}).get("instanceUrl", ""), end="")')"
ACCESS_TOKEN="$(printf '%s' "$ORG_JSON" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("result", {}).get("accessToken", ""), end="")')"

if [[ -z "$INSTANCE_URL" || -z "$ACCESS_TOKEN" ]]; then
  echo "Unable to resolve SF_INSTANCE_URL or SF_ACCESS_TOKEN for org alias '$ORG_ALIAS'." >&2
  exit 1
fi

printf 'export SF_INSTANCE_URL=%q\n' "$INSTANCE_URL"
printf 'export SF_ACCESS_TOKEN=%q\n' "$ACCESS_TOKEN"
printf 'export SF_ORG_ALIAS=%q\n' "$ORG_ALIAS"
