#!/usr/bin/env /bin/bash
aws ec2 describe-instance-types \
    --output json \
    | jq '.InstanceTypes[] | { (.InstanceType): { vcpus: .VCpuInfo.DefaultVCpus, baseline: .NetworkInfo.NetworkCards[0].BaselineBandwidthInGbps, burst: .NetworkInfo.NetworkPerformance}}' \
    | jq -s add > instance-networking.json
