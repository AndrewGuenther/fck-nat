# fck-nat Configuration

## Configuration file

Upon starting, fck-nat evaluates a configuration file describing how the instance should behave as well as what features
shall be enabled. To configure fck-nat, ensure a file `/etc/fck-nat.conf` exists with your configuration. fck-nat
requires the service to be restarted by running `service fck-nat-resart`. In most implementations this configuration is
passed only once via EC2's user data.

The following describes available options:
| name                      | default        | description |
| ------------------------- | -------------- | ----------- |
| `eni_id`                  | n/a            | The ID of the Elastic Network Interface to attach to the instance and use as a consistent endpoint to send traffic to fck nat. This is required when using high-availability mode. |
| `eip_id`                  | n/a            | The ID of an Elastic IP to be attached to the public network interface. This ensures the NAT gateway public traffic is always routed through the same public IP address. |
| `cwagent_enabled`         | n/a            | If set, enables Cloudwatch agent and forward instance metrics to Cloudwatch. Requires `cwagent_cfg_param_name` to be set. |
| `cwagent_cfg_param_name`  | n/a            | The name of the SSM Parameter holding the Cloudwatch agent configuration and which the agent shall pull from. Requires `cwagent_enabled` to be set. |
