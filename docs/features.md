# fck-nat Features

!!! info "Heads up!"
    The easiest way to get all of the features below is to use the official [CDK](deploying.md#cdk) or
    [Terraform](deploying.md#terraform) modules!

## High-availability Mode

fck-nat can operate on a single instance, or within an autoscaling group for improved availability. When running in an
autoscaling group, fck-nat can be configured to always attach a specific ENI at start-up, allowing fck-nat to maintain
a static internal-facing IP address. (For information on static external IPs, see: [Static IP](#static-ip))

This feature is controlled via the `eni_id` directive in the [configuration file](configuration.md#configuration-file)
and also requires additional IAM permissions to function, see: [IAM Requirements](configuration.md#iam-requirements)

## Static IP

If you wish for your NAT instance to maintain a consistent external facing IP, fck-nat supports automatically
association of an Elastic IP (EIP) addresss at launch.

This feature is controlled via the `eip_id` directive in the [configuration file](configuration.md#configuration-file)
and also requires additional IAM permissions to function, see: [IAM Requirements](configuration.md#iam-requirements)

## SSM Agent

The Amazon SSM Agent is installed in the fck-nat AMI by default to allow SSH-less access to instances as well as
automated patching capabilities if you so choose (The fck-nat AMI also has kernel live patching modules enabled). To
enable access via SSM, you just need to make sure that your fck-nat instance has the requisite
[IAM permissions attached](configuration.md#iam-requirements)

## Metrics

One of the objectives of fck-nat is to offer as close as possible metric parity with Managed NAT Gateway. While the
project supports various metrics similar to the managed NAT Gateway via Cloudwatch agent, each provider is responsible
for passing their configuration to the agent via fck-nat's `cwagent_enabled`, and `cwagent_cfg_param_name` directives
within its configuration file.

As an example, you might use the following configuration file which have Cloudwatch agent report most of metrics
provided in the managed NAT Gateway:

``` json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root",
    "usage_data": false
  },
  "metrics": {
    "namespace": "fck-nat",
    "metrics_collected": {
      "net": {
        "resources": ["ens5", "ens6"],
        "measurement": [
          { "name": "bytes_recv", "rename": "BytesIn",  "unit": "Bytes" },
          { "name": "bytes_sent", "rename": "BytesOut",  "unit": "Bytes" },
          { "name": "packets_sent", "rename": "PacketsOutCount",  "unit": "Count" },
          { "name": "packets_recv", "rename": "PacketsInCount",  "unit": "Count" },
          { "name": "drop_in", "rename": "PacketsDropInCount",  "unit": "Count" },
          { "name": "drop_out", "rename": "PacketsDropOutCount",  "unit": "Count" }
        ]
      },
      "netstat": {
        "measurement": [
          { "name": "tcp_syn_sent", "rename": "ConnectionAttemptOutCount",  "unit": "Count" },
          { "name": "tcp_syn_recv", "rename": "ConnectionAttemptInCount",  "unit": "Count" },
          { "name": "tcp_established", "rename": "ConnectionEstablishedCount",  "unit": "Count" }
        ]
      },
      "ethtool": {
        "interface_include": ["ens5", "ens6"],
        "metrics_include": [
          "bw_in_allowance_exceeded",
          "bw_out_allowance_exceeded",
          "conntrack_allowance_exceeded",
          "pps_allowance_exceeded"
        ]
      },
      "mem": {
        "measurement": [
          { "name": "used_percent", "rename": "MemoryUsed",  "unit": "Percent" }
        ]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  }
}
```

Ensure you are aware of Cloudwatch metrics costs before enabling Cloudwatch agent. The above configuration would
cost you about $17/monthly, excluding free tier.  

**IAM requirements**: `ssm:GetParameter` on the SSM Parameter ARN, and `cloudwatch:PutMetricData` on `*`.
