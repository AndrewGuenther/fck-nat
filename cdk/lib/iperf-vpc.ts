/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { InstanceType, IPeer, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2'
import { IperfAsg } from './iperf-asg'

interface IperfVpcProps extends cdk.StackProps {
  readonly iperfInstanceType: InstanceType
  readonly iperfIncomingPeer?: IPeer
}

export class IperfVpc extends cdk.Construct {
  constructor (scope: cdk.Construct, id: string, props: IperfVpcProps) {
    super(scope, id)

    const publicSubnetCfg: SubnetConfiguration = {
      name: 'public-subnet',
      subnetType: SubnetType.PUBLIC,
      cidrMask: 24,
      reserved: false
    }

    const vpc = new Vpc(this, 'vpc', {
      maxAzs: 1,
      subnetConfiguration: [publicSubnetCfg]
    })

    new IperfAsg(this, 'iperf-asg', {
      vpc,
      instanceType: props.iperfInstanceType,
      incomingPeer: props.iperfIncomingPeer
    })
  }
}
