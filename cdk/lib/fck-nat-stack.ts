import * as cdk from '@aws-cdk/core';
import { BastionHostLinux, GenericLinuxImage, InstanceType, LookupMachineImage, NatInstanceProvider, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2';

export class FckNatStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
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
        instanceType: new InstanceType('t4g.micro'), // Gravitron 2 instance
        machineImage: new LookupMachineImage({
          name: 'fck-nat'
        })
      }),
    })

    new BastionHostLinux(this, 'bastion', {
      vpc
    })
  }
}
