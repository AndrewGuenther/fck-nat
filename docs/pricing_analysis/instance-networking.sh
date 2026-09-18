#!/usr/bin/env bash
aws ec2 describe-instance-types \
    --region us-east-1 \
    --output json \
    | jq '.InstanceTypes[] | { (.InstanceType): { vcpus: .VCpuInfo.DefaultVCpus, baseline: .NetworkInfo.NetworkCards[0].BaselineBandwidthInGbps, burst: .NetworkInfo.NetworkPerformance}}' \
    | jq -s add > instance-networking.json
