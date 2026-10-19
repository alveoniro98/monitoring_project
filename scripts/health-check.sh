#!/usr/bin/env bash
set -Eeuo pipefail

HOST="${1:-http://127.0.0.1}"
printf 'Checking OpsPulse at %s\n' "$HOST"
curl --fail --silent --show-error --max-time 5 "$HOST/health"
printf '\n'
curl --fail --silent --show-error --max-time 5 "$HOST/api/metrics" >/dev/null
printf 'API metrics endpoint is responding.\n'
