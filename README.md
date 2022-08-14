# fck-nat

Welcome to fck-nat. The (f)easible (c)ost (k)onfigurable NAT!

* Overpaying for AWS Managed NAT Gateways? fck-nat.
* Want to use NAT instances and stay up-to-date with the latest security patches? fck-nat.
* Want to reuse your Bastion hosts as a NAT? fck-nat.

fck-nat offers a ready-to-use ARM and x86 based AMIs built on Amazon Linux 2 which can support up to 5Gbps burst NAT
traffic on a t4g.nano instance. How does that compare to a Managed NAT Gateway?

Hourly rates:

* Managed NAT Gateway hourly: $0.045
* t4g.nano hourly: $0.0042

Per GB rates:

* Managed NAT Gateway per GB: $0.045
* fck-nat per GB: $0.00

Sitting idle, fck-nat costs 10% of a Managed NAT Gateway. In practice, the savings are even greater.

*"But what about AWS' NAT Instance AMI?"*

The official AWS supported NAT Instance AMI hasn't been updates since 2018, is still running Amazon Linux 1 which is
now EOL, and has no ARM support, meaning it can't be deployed on EC2's most cost effective instance types. fck-nat.

*"When would I want to use a Managed NAT Gateway instead of fck-nat?"*

AWS limits outgoing internet bandwidth on EC2 instances to 5Gbps. This means that the highest bandwidth that fck-nat
can support (while remaining cost-effective) is 5Gbps. This is enough to cover a very broad set of use cases, but if
you need additional bandwidth, you should use Managed NAT Gateway. If AWS were to lift the limit on internet egress
bandwidth from EC2, you could cost-effectively operate fck-nat at speeds up to 25Gbps, but you wouldn't need Managed
NAT Gateway then would you? fck-nat.

[Read more about EC2 bandwidth limits here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-network-bandwidth.html)

Additionally, if you have an allergy to non-managed services, fck-nat may not be for you. Although fck-nat supports a
high-availability mode, it is not completely immune to outages (albeit very rare). If your workload requires five 9s of
uptime, then Managed NAT Gateway is likely a better option for you.
