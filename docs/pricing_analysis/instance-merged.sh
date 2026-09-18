#!/usr/bin/env bash
# Merge pricing info from instance-pricing.json with networking info from
# instance-networking.json.
#
# Exclude hpc* instance families because they have special high-performance EFA
# networking for within the VPC and limited bandwidth outside the VPC.
# https://aws.amazon.com/ec2/instance-types/hpc-optimized/
# "500 Mbps network bandwidth outside of the virtual private cloud (VPC)"
#
# * Instances < 32 vCPU get 5 Gbps max bandwidth for IGW traffic.
# * Instances >= 32 vCPU get 50% of baseline bandwidth for IGW traffic
# * Certain special instances like c8in.* are excluded from this and get 100%
#
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-network-bandwidth.html
#
jq -s '.[0] * .[1]' instance-pricing.json instance-networking.json \
    | jq 'with_entries(select(.value | has("baseline") and has("price") and .price > 0.0))' \
    | jq 'with_entries(select(.key | test("^hpc") | not))' \
    | jq 'to_entries | map(. as $entry | .value |= . + {max_egress: (if ($entry.key | test("^(c8in|c8ine|m8in|m8ine|m8idn|r8in|r8idn)\\.")) then .baseline elif .vcpus < 32 then ([.baseline, 5.0] | min) else .baseline / 2 end) }) | map(.value |= . + {ratio: (.max_egress / (.price | tonumber)), price_monthly: (.price * 730)}) | sort_by(.value.ratio) | from_entries' > instance-merged.json
