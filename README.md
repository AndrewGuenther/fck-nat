# fck-nat

Welcome to fck-nat. The (f)easible (c)ost (k)onfigurable NAT!

* Overpaying for AWS Managed NAT Gateways? fck-nat.
* Want to use NAT instances and stay up-to-date with the latest security patches? fck-nat.
* Want to reuse your Bastion hosts as a NAT? fck-nat.

fck-nat offers a ready-to-use ARM-based AMI based on Amazon Linux 2 which can support up to 5Gbps NAT traffic on a t4g.nano instance. How does that compare to a Managed NAT Gateway?

Hourly rates:
* Managed NAT Gateway hourly: $0.045
* t4g.nano hourly: $0.0042

Per GB rates:
* Managed NAT Gateway per GB: $0.045
* fck-nat per GB: $0.00

Sitting idle, fck-nat costs 10% of a Managed NAT Gateway. In practice, the savings are even greater.

*"But what about AWS' NAT Instance AMI?"*

The official AWS supported NAT Instance AMI hasn't been updates since 2018, is still running Amazon Linux 1 which is now EOL, and has no ARM support, meaning it can't be deployed on EC2's most cost effective instance types. fck-nat.