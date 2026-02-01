# fck-nat Configuration

## Configuration File

Upon starting, fck-nat evaluates a configuration file describing how the instance should behave as well as what features
shall be enabled. To configure fck-nat, ensure a file `/etc/fck-nat.conf` exists with your configuration. fck-nat
requires the service to be restarted by running `systemctl restart fck-nat.service`. In most implementations this configuration is
passed only once via EC2's user data.

The following describes available options:

| Name                    | Description |
| ----------------------- | ----------- |
| `eni_id`                | The ID of the Elastic Network Interface to attach to the instance and use as a consistent endpoint to send traffic to fck nat. This is required when using high-availability mode. |
| `eip_id`                | The ID of an Elastic IP to be attached to the public network interface. This ensures the NAT gateway public traffic is always routed through the same public IP address. |
| `cwagent_enabled`       | If set, enables Cloudwatch agent and forward instance metrics to Cloudwatch. Requires `cwagent_cfg_param_name` to be set. |
| `cwagent_cfg_param_name` | The name of the SSM Parameter holding the Cloudwatch agent configuration and which the agent shall pull from. Requires `cwagent_enabled` to be set. |
| `ip_local_port_range`   | Overrides Linux's `net.ipv4.ip_local_port_range` sysctl for ephemeral source ports used by SNAT. Provide as two space‑separated integers `low high` (e.g., `1024 65535`). Useful to expand the ephemeral port range and reduce NAT port exhaustion and collisions. |
| `nf_conntrack_max`      | Overrides Linux's `net.netfilter.nf_conntrack_max` sysctl to set the maximum number of concurrently tracked connections. Provide as an integer (e.g., `262144`). Increasing this can help high-connection workloads but consumes more memory; monitor conntrack metrics and AWS security group connection tracking quotas. |
| `gwlb_enabled`          | If set, enables Gateway Load Balancer support. |
| `gwlb_health_check_port` | Overrides default port utilised for Gateway Load Balancer health check endpoint. Default: `8008` Requires `gwlb_enabled` to be set. |

## IAM Requirements

Certain features of fck-nat require the role attached to the instance to have permissions for certain AWS API
operations. The table below details the current permission requirements for various features:

| Feature | Required Permissions |
| ------- | -------------------- |
| HA-mode (`eni_id`) | `ec2:AttachNetworkInterface, ec2:ModifyNetworkInterfaceAttribute` |
| Static IP (`eip_id`) | `ec2:AssociateAddress, ec2:DisassociateAddress` |
| Cloudwatch Agent (`cwagent_enabled`) | Managed Policy: `CloudWatchAgentServerPolicy` *and* `ssm:GetParameter` |
| SSM Agent (installed by default, IAM role required to use) | Managed Policy: `AmazonSSMManagedEC2InstanceDefaultPolicy` |
