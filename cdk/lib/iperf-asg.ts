import * as cdk from '@aws-cdk/core';
import { AmazonLinuxCpuType, AmazonLinuxGeneration, InstanceType, IPeer, MachineImage, Peer, Port, SecurityGroup, Vpc } from '@aws-cdk/aws-ec2';
import { AutoScalingGroup } from '@aws-cdk/aws-autoscaling'
import { Role, ServicePrincipal, ManagedPolicy } from '@aws-cdk/aws-iam'

interface IperfAsgProps {
  readonly vpc: Vpc
  readonly instanceType: InstanceType,
  readonly incomingPeer?: IPeer,
  readonly desiredCapacity?: number
}

export class IperfAsg extends cdk.Construct {
  constructor(scope: cdk.Construct, id: string, props: IperfAsgProps) {
    super(scope, id);

    const sg = new SecurityGroup(this, 'perf-sg', {
        vpc: props.vpc,
    })

    const incomingPeer = props.incomingPeer ? props.incomingPeer : Peer.anyIpv4()
    sg.addIngressRule(incomingPeer, Port.tcpRange(5001, 5001))

    const role = new Role(this, 'ssm-role', {
        assumedBy: new ServicePrincipal('ec2.amazonaws.com')
    });
    role.addManagedPolicy(ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'));

    const asg = new AutoScalingGroup(this, 'asg', {
        instanceType: props.instanceType,
        machineImage: MachineImage.latestAmazonLinux({
          generation: AmazonLinuxGeneration.AMAZON_LINUX_2,
          cpuType: AmazonLinuxCpuType.ARM_64,
        }),
        desiredCapacity: props.desiredCapacity ? props.desiredCapacity : 1,
        vpc: props.vpc,
        role,
    })
    asg.addSecurityGroup(sg)
    asg.addUserData(
        "sudo amazon-linux-extras install epel -y",
        "sudo yum install -y iperf"
    )
  }
}