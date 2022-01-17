/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { InstanceType, NatInstanceProvider } from '@aws-cdk/aws-ec2'
import { IperfAsg } from './iperf-asg'
import { FckNatVpc } from './fck-nat-vpc'
import { IperfVpc } from './iperf-vpc'

interface FckNatPerfStackProps extends cdk.StackProps {
  readonly natInstanceProvider: NatInstanceProvider
  readonly iperfInstanceType: InstanceType
}

export class FckNatPerfStack extends cdk.Stack {
  constructor (scope: cdk.Construct, id: string, props: FckNatPerfStackProps) {
    super(scope, id, props)

    const fckNatVpc = new FckNatVpc(this, 'fck-nat-vpc', props)

    new IperfVpc(this, 'iperf-vpc', {
      iperfInstanceType: props.iperfInstanceType
    })

    new IperfAsg(this, 'iperf-asg', {
      vpc: fckNatVpc.vpc,
      instanceType: props.iperfInstanceType
    })
  }
}
