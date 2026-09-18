#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo >&2 "usage: $0 BANDWIDTH [LIMIT]"
    echo >&2
    echo >&2 "Find the best LIMIT instance type(s) for fck-nat with max_egress bandwidth >= BANDWIDTH (Gbps)"
    exit 1
fi

bandwidth="$1"
limit="${2-1}"

jq --argjson egress "$bandwidth" --argjson limit "$limit" \
    "to_entries | map(select(.value.max_egress >= \$egress)) | map(.value.price_monthly_per_gbps = ((.value.price_monthly / .value.max_egress * 100 | round) / 100)) | sort_by(.value.price) | .[:\$limit] | from_entries" "$(dirname "$0")"/instance-merged.json
