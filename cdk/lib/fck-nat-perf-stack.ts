import * as cdk from '@aws-cdk/core';
import { InstanceType, IPeer, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2';
import { IperfAsg } from './iperf-asg';

interface FckNatPerfStackProps extends cdk.StackProps {
  readonly iperfInstanceType: InstanceType,
  readonly iperfIncomingPeer?: IPeer
}

export class FckNatPerfStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props: FckNatPerfStackProps) {
    super(scope, id, props);

    const public_subnet_cfg: SubnetConfiguration = {
      name: 'public-subnet',
      subnetType: SubnetType.PUBLIC,
      cidrMask: 24,
      reserved: false
    }

    const vpc = new Vpc(this, 'vpc', {
      maxAzs: 1,
      subnetConfiguration: [public_subnet_cfg],
    })

    new IperfAsg(this, 'iperf-asg', {
      vpc,
      instanceType: props.iperfInstanceType,
      incomingPeer: props.iperfIncomingPeer
    })
  }
}
