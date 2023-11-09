# fck-nat Features

## High-availability Mode

fck-nat can operate on a single instance, or withing an autoscaling group for improved availability. When running in an
autoscaling group, fck-nat can be configured to always attach a specific ENI at start-up, allowing fck-nat to maintain
a consistent internal-facing IP address. Additionally, it is also possible to configure an already allocated EIP address
that would be carried through instance refreshs.

To enable these features, you'll need to create a config file at `/etc/fck-nat.conf` like this:

```
eni_id=<YOUR_ENI_ID>
eip_id=<YOUR_EIP_ALLOCATION_ID>
```

Once the fck-nat configuration is created, be sure to restart the service by running `service fck-nat restart`.

In the official fck-nat CDK construct, we configure this via UserData on the autoscaling group.

## Metrics

One of the objectives of fck-nat is to offer as close as possible metric parity with Managed NAT Gateway. If this
feature is important to you, help us prioritize it by +1'ing the following issue: [Report additional metrics from
fck-nat](https://github.com/AndrewGuenther/fck-nat/issues/16)
