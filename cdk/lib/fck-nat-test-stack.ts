import * as cdk from '@aws-cdk/core';
import { InstanceType, NatInstanceProvider } from '@aws-cdk/aws-ec2';
import { IperfAsg } from './iperf-asg';
import { FckNatVpc } from './fck-nat-vpc'
import { IperfVpc } from './iperf-vpc';

interface FckNatTestStackProps extends cdk.StackProps {
  readonly natInstanceProviders: Array<NatInstanceProvider>,
}

export class FckNatTestStack extends cdk.Stack {

  constructor(scope: cdk.Construct, id: string, props: FckNatTestStackProps) {
    super(scope, id, props);

    for (const natInstanceProvider of props.natInstanceProviders) {
      new FckNatVpc(this, 'fck-nat-vpc', { natInstanceProvider });
    }
  }
}
