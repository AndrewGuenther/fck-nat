import * as cdk from '@aws-cdk/core';
import { GenericLinuxImage, InstanceType, Peer, Port, SecurityGroup, SubnetConfiguration, SubnetType, Vpc } from '@aws-cdk/aws-ec2';
import { AutoScalingGroup } from '@aws-cdk/aws-autoscaling'
import { Role, ServicePrincipal, ManagedPolicy } from '@aws-cdk/aws-iam'

export class FckNatPerfStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props: cdk.StackProps) {
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

    const sg = new SecurityGroup(this, 'perf-sg', {
        vpc,
    })
    // TODO: Can change this to get the public IP of the NAT instance from the other VPC
    sg.addIngressRule(Peer.anyIpv4(), Port.tcpRange(5001, 5001))

    const role = new Role(this, 'ssm-role', {
        assumedBy: new ServicePrincipal('ec2.amazonaws.com')
    });
    role.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'));

    const asg = new AutoScalingGroup(this, 'asg', {
        instanceType: new InstanceType('t4g.small'),
        machineImage: new GenericLinuxImage({
            'us-west-2': 'ami-0bd804c6ae66f0dcd',
        }),
        desiredCapacity: 1,
        vpc,
        role,
    })
    asg.addSecurityGroup(sg)
    asg.addUserData(
        "sudo amazon-linux-extras install epel -y",
        "sudo yum install -y iperf"
    )
  }
}
