# fck-nat

**Note: fck-nat does not yet support a high availability mode. It is not recommended at this time to run critical
production workloads with fck-nat. See [this issue](https://github.com/AndrewGuenther/fck-nat/issues/8) for more
information regarding release of HA mode.**

Welcome to fck-nat. The (f)easible (c)ost (k)onfigurable NAT!

* Overpaying for AWS Managed NAT Gateways? fck-nat.
* Want to use NAT instances and stay up-to-date with the latest security patches? fck-nat.
* Want to reuse your Bastion hosts as a NAT? fck-nat.

fck-nat offers a ready-to-use ARM and x86 based AMIs built on Amazon Linux 2 which can support up to 5Gbps NAT traffic
on a t4g.nano instance. How does that compare to a Managed NAT Gateway?

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
can support is 5Gbps. This is enough to cover a very broad set of use cases, but if you need additional bandwidth,
you'll have to use Managed NAT Gateway. If AWS were to lift the limit on internet egress bandwidth from EC2, you could
cost-effectively operate fck-nat at speeds up to 25Gbps, but you wouldn't need Managed NAT Gateway then would you?
fck-nat.

## Using fck-nat

The primary objective of fck-nat is to make deploying your own NAT instances as easy, secure, and configurable as
possible. While fck-nat strives to provide out-of-the-box options and guides that work for most people, everyone's
requirements are different. Where fck-nat can't provide a ready-to-use solution, we try to offer you all the toggles
you need to get up and running yourself with as little headache as possible. We follow the "batteries included, but
swappable" philosophy as much as possible.

### Getting a fck-nat AMI

fck-nat provides public AMIs in both arm64 and x86_64 flavors built on top of Amazon Linux 2. If you would rather use a
different base image or host the AMI yourself, you can build your own AMI.

#### The public fck-nat AMIs

fck-nat currently provides public AMIs in most regions. You can see the full list in
`packer/fck-nat-public-all-regions.pkrvars.hcl`. While arm64 images are the most cost effective, x86_64 images are also
available. You can get view the available fck-nat AMIs with the following query:

```
# Amazon Linux 2 based AMIs
aws ec2 describe-images --owners 568608671756 --filters 'Name=name,Values=fck-nat-amzn2-*'

# Ubuntu based AMIs
aws ec2 describe-images --owners 568608671756 --filters 'Name=name,Values=fck-nat-ubuntu-*'
```

#### Building your own fck-nat AMI

fck-nat images are built using [Packer](https://www.packer.io/). You can find the Packer files we use to build the
public images inside the `packer` folder. Our Packer configuration uses variables extensively, allowing you to
customize your base image, build region, architecture, etc. If the publicly available AMIs don't suit your needs, or
you would prefer to host the AMIs yourself, you can create your own `pkrvars.hcl` file and build your own AMI.

```shell
packer build -var-file="your-var-file.pkrvars.hcl" ./packer/fck-nat.pkr.hcl
```

#### Installing fck-nat on an existing AMI

If you have an existing AMI and you want to install fck-nat on it, you can get the `.deb` or `.rpm` build of fck-nat
from the [Releases](https://github.com/AndrewGuenther/fck-nat/releases) page

### Using your fck-nat AMI

An AMI isn't the only thing you'll need to get up and running with fck-nat. There's a few options which need to be
configured in order to route traffic to your NAT. Namely, you must:

1. Configure a security group for your fck-nat instance
1. Disable source/destination checks
1. Update your VPC route table

Some tools can accomplish this for you, others cannot. The following sections provide instructions for how to perform
this configuration using various common deployment tools.

#### CDK

Using CDK, you can launch and configure a fck-nat instance quite easily. Here's an example VPC definition which uses
the public fck-nat AMI:

```typescript
const vpc = new Vpc(this, 'vpc', {
    natGatewayProvider: new NatInstanceProvider({
        instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.MICRO),
        machineImage: new LookupMachineImage({
            name: 'fck-nat-amzn2-*-arm64-ebs',
            owners: ['568608671756'],
        })
    }),
});
```

That's it! CDK will automatically handle creating a security group for your fck-nat instance as well as other necessary
network configurations. [Read more about the `NatInstanceProvider` construct](https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.NatInstanceProvider.html)

#### Cloudformation

*Coming soon!*

#### Terraform

*Coming soon!*

#### AWS CLI

*Coming soon!*
