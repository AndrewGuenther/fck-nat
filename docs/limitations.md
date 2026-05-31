# Limitations

## Availability

fck-nat has some fundamental limitations when it comes to availability. If the instance requires replacement, downtime
for the ASG (when using HA mode) to bring up a new instance is ~5 minutes, but is automatic. However, due to
replacement nodes effectively taking over the configured internal ENI, you can significantly reduce disruption if you
launch a second instance before the first is terminated. Existing connections will be cut, but downtime will only be
a few seconds.

## Security groups and quota limitations

Using security groups to firewall your NAT instances (only allowing connections from inside your VPC) are subject to
conntrack limitations. You can read more about the details of those limitations here:
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-connection-tracking.html

If you're running fck-nat with [additional CloudWatch monitoring enabled](features.md#metrics) we report the
`conntrack_allowance_exceeded` and `conntrack_allowance_available` metrics which would enable you to observe if these
conntrack limits are being hit. If you're hitting these limits, it is recommended that you allow all traffic in
security groups and use `nftables` in order to drop inbound connections from outside your VPC.
