import * as cdk from '@aws-cdk/core';
import { InstanceType, LookupMachineImage, NatInstanceProvider, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2';
import { IperfAsg } from './iperf-asg';

interface FckNatPerfStackProps extends cdk.StackProps {
  readonly natInstanceType: InstanceType,
  readonly iperfInstanceType: InstanceType
}

export class FckNatStack extends cdk.Stack {

  constructor(scope: cdk.Construct, id: string, props: FckNatPerfStackProps) {
    super(scope, id, props);

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

    const vpc = new Vpc(this, 'vpc', {
      maxAzs: 1,
      subnetConfiguration: [public_subnet_cfg, private_subnet_cfg],
      natGatewayProvider: new NatInstanceProvider({
        instanceType: props.natInstanceType,
        machineImage: new LookupMachineImage({
          name: 'fck-nat-*-arm64-ebs',
          owners: ['568608671756'],
        })
      }),
    })

    new IperfAsg(this, 'iperf-asg', {
      vpc,
      instanceType: props.iperfInstanceType,
    })
  }
}
