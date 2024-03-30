#!/usr/bin/env /bin/bash
jq -s '.[0] * .[1]' instance-pricing.json instance-networking.json \
    | jq 'with_entries(select(.value | has("baseline") and has("price") and .price > 0.0))' \
    | jq 'to_entries | map(.value |= . + {max_egress: (if .vcpus < 32 then ([.baseline, 5.0] | min) else .baseline / 2 end) }) | map(.value |= . + {ratio: (.max_egress / (.price | tonumber)), price_monthly: (.price * 730)}) | sort_by(.value.ratio) | from_entries' > instance-merged.json
