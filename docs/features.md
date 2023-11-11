# fck-nat Features

## High-availability Mode

fck-nat can operate on a single instance, or withing an autoscaling group for improved availability. When running in an
autoscaling group, fck-nat can be configured to always attach a specific ENI at start-up, allowing fck-nat to maintain
a consistent internal-facing IP address. Additionally, it is also possible to configure an already allocated EIP address
that would be carried through instance refreshs.

Those features are controlled by `eni_id` and `eip_id` directive in the configuration file.

## Metrics

One of the objectives of fck-nat is to offer as close as possible metric parity with Managed NAT Gateway. While the
project supports various metrics similar to the managed NAT Gateway via Cloudwatch agent, each provider is responsible
for passing their configuration to the agent via fck-nat's `cwagent_enabled`, and `cwagent_cfg_param_arn` directives
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
        "resources": ["eth0", "eth1"],
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
      "mem": {
        "measurement": [
          { "name": "used_percent", "rename": "MemoryUsed",  "unit": "Percent" }
        ]
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    }
  }
}
```

If this feature is important to you, help us prioritize it by +1'ing the following issue: [Report additional metrics
from fck-nat](https://github.com/AndrewGuenther/fck-nat/issues/16)
