import * as cdk from '@aws-cdk/core';
import { BastionHostLinux, InstanceType, LookupMachineImage, NatInstanceProvider, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2';
import { IperfAsg } from './iperf-asg';

interface FckNatVpcProps extends cdk.StackProps {
  readonly natInstanceProvider: NatInstanceProvider,
}

export class FckNatVpc extends cdk.Construct {

  vpc: Vpc

  constructor(scope: cdk.Construct, id: string, props: FckNatVpcProps) {
    super(scope, id);

    const public_subnet_cfg: SubnetConfiguration = {
      name: 'public-subnet',
      subnetType: SubnetType.PUBLIC,
      cidrMask: 24,
      reserved: false
    }
    const private_subnet_cfg: SubnetConfiguration = {
      name: 'private-subnet',
      subnetType: SubnetType.PRIVATE_WITH_NAT,
      cidrMask: 24,
      reserved: false
    }

    this.vpc = new Vpc(this, 'vpc', {
      maxAzs: 1,
      subnetConfiguration: [public_subnet_cfg, private_subnet_cfg],
      natGatewayProvider: props.natInstanceProvider,
    })

    const host = new BastionHostLinux(this, 'BastionHost', {
      vpc: this.vpc,
    });
  }
}
