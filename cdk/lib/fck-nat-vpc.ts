/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { BastionHostLinux, Peer, Port, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2'
import { Tags } from '@aws-cdk/core'
import { FckNatInstanceProvider } from './fck-nat-ha-nat-provider'

interface FckNatVpcProps extends cdk.StackProps {
  readonly natInstanceProvider: FckNatInstanceProvider
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

    props.natInstanceProvider.connections.allowFrom(Peer.ipv4(this.vpc.vpcCidrBlock), Port.allTraffic())

    const bastion = new BastionHostLinux(this, 'BastionHost', {
      vpc: this.vpc
    })

    Tags.of(bastion).add('connectivity-test-target', 'true')
  }
}
