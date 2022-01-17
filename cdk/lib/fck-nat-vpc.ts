/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { BastionHostLinux, NatInstanceProvider, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2'

interface FckNatVpcProps extends cdk.StackProps {
  readonly natInstanceProvider: NatInstanceProvider
}

export class FckNatVpc extends cdk.Construct {
  vpc: Vpc

  constructor (scope: cdk.Construct, id: string, props: FckNatVpcProps) {
    super(scope, id)

    const publicSubnetCfg: SubnetConfiguration = {
      name: 'public-subnet',
      subnetType: SubnetType.PUBLIC,
      cidrMask: 24,
      reserved: false
    }
    const privateSubnetCfg: SubnetConfiguration = {
      name: 'private-subnet',
      subnetType: SubnetType.PRIVATE_WITH_NAT,
      cidrMask: 24,
      reserved: false
    }

    this.vpc = new Vpc(this, 'vpc', {
      maxAzs: 1,
      subnetConfiguration: [publicSubnetCfg, privateSubnetCfg],
      natGatewayProvider: props.natInstanceProvider
    })

    new BastionHostLinux(this, 'BastionHost', {
      vpc: this.vpc
    })
  }
}
