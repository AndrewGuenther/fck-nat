import * as cdk from '@aws-cdk/core'
import { InstanceType, CfnNetworkInterface, ConfigureNatOptions, Connections, GatewayConfig, IMachineImage, ISecurityGroup, LookupMachineImage, NatInstanceProvider, NatProvider, PrivateSubnet, RouterType, SecurityGroup, UserData, CfnEIP, CfnEIPAssociation, IConnectable } from '@aws-cdk/aws-ec2'
import * as iam from '@aws-cdk/aws-iam'
import { AutoScalingGroup } from '@aws-cdk/aws-autoscaling';
/**
 * Preferential set
 *
 * Picks the value with the given key if available, otherwise distributes
 * evenly among the available options.
 */
 class PrefSet<A> {
    private readonly map: Record<string, A> = {};
    private readonly vals = new Array<[string, A]>();
    private next: number = 0;
  
    public add(pref: string, value: A) {
      this.map[pref] = value;
      this.vals.push([pref, value]);
    }
  
    public pick(pref: string): A {
      if (this.vals.length === 0) {
        throw new Error('Cannot pick, set is empty');
      }
  
      if (pref in this.map) { return this.map[pref]; }
      return this.vals[this.next++ % this.vals.length][1];
    }
  
    public values(): Array<[string, A]> {
      return this.vals;
    }
  }

/**
 * Properties for a NAT instance
 *
 *
 */
 export interface NatInstanceProps {
  /**
   * The machine image (AMI) to use
   *
   * By default, will do an AMI lookup for the latest NAT instance image.
   *
   * If you have a specific AMI ID you want to use, pass a `GenericLinuxImage`. For example:
   *
   * ```ts
   * ec2.NatProvider.instance({
   *   instanceType: new ec2.InstanceType('t3.micro'),
   *   machineImage: new ec2.GenericLinuxImage({
   *     'us-east-2': 'ami-0f9c61b5a562a16af'
   *   })
   * })
   * ```
   *
   * @default - Latest NAT instance image
   */
  readonly machineImage?: IMachineImage;

  /**
   * Instance type of the NAT instance
   */
  readonly instanceType: InstanceType;

  /**
   * Name of SSH keypair to grant access to instance
   *
   * @default - No SSH access will be possible.
   */
  readonly keyName?: string;

  /**
   * Security Group for NAT instances
   *
   * @default - A new security group will be created
   */
  readonly securityGroup?: ISecurityGroup;
}

export class FckNatInstanceProvider extends NatProvider implements IConnectable {
    private gateways: PrefSet<CfnNetworkInterface> = new PrefSet<CfnNetworkInterface>();
    private _securityGroup?: ISecurityGroup;
    private _connections?: Connections;

    constructor(private readonly props: NatInstanceProps) {
      super();
    }

    configureNat(options: ConfigureNatOptions): void {
      // Create the NAT instances. They can share a security group and a Role.
      const machineImage = this.props.machineImage || new LookupMachineImage({
        name: 'fck-nat-amzn2-*-arm64-ebs',
        owners: ['568608671756']
      })
      this._securityGroup = this.props.securityGroup ?? new SecurityGroup(options.vpc, 'NatSecurityGroup', {
        vpc: options.vpc,
        description: 'Security Group for NAT instances',
      });
      this._connections = new Connections({ securityGroups: [this._securityGroup] });

      // TODO: This should get buttoned up to only allow attaching ENIs created by this construct.
      const role = new iam.Role(options.vpc, 'NatRole', {
        assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
        inlinePolicies: {
          "attachNatEniPolicy": new iam.PolicyDocument({
            statements: [new iam.PolicyStatement({
              actions: ['ec2:AttachNetworkInterface'],
              resources: ['*']
            })]
        })}
      });

      for (const sub of options.natSubnets) {
        const networkInterface = new CfnNetworkInterface(
          sub, 'FckNatInterface', {
            subnetId: sub.subnetId,
            sourceDestCheck: false,
            groupSet: [this._securityGroup.securityGroupId]
          }
        )

        const eip = new CfnEIP(sub, 'Eip', {
          domain: 'vpc',
        })

        const eipAssociation = new CfnEIPAssociation(sub, 'EipAssociation', {
          allocationId: eip.attrAllocationId,
          networkInterfaceId: networkInterface.ref
        })

        const userData = UserData.forLinux()
        userData.addCommands(`echo "eni_id=${networkInterface.ref}" >> /etc/fck-nat.conf`)
        userData.addCommands('service fck-nat restart')

        const autoScalingGroup = new AutoScalingGroup(
          sub, 'FckNatAsg', {
            instanceType: this.props.instanceType,
            machineImage,
            vpc: options.vpc,
            vpcSubnets: { subnets: [sub] },
            securityGroup: this._securityGroup,
            role,
            desiredCapacity: 1,
            userData: userData,
          }
        )
        // NAT instance routes all traffic, both ways
        this.gateways.add(sub.availabilityZone, networkInterface);
      }

      // Add routes to them in the private subnets
      for (const sub of options.privateSubnets) {
        this.configureSubnet(sub);
      }
    }

    configureSubnet(subnet: PrivateSubnet): void {
        const az = subnet.availabilityZone;
        const gatewayId = this.gateways.pick(az).ref;
        subnet.addRoute('DefaultRoute', {
          routerType: RouterType.NETWORK_INTERFACE,
          routerId: gatewayId,
          enablesInternetConnectivity: true,
        });
    }
    
  /**
   * The Security Group associated with the NAT instances
   */
  public get securityGroup(): ISecurityGroup {
    if (!this._securityGroup) {
      throw new Error('Pass the NatInstanceProvider to a Vpc before accessing \'securityGroup\'');
    }
    return this._securityGroup;
  }

  /**
   * Manage the Security Groups associated with the NAT instances
   */
  public get connections(): Connections {
    if (!this._connections) {
      throw new Error('Pass the NatInstanceProvider to a Vpc before accessing \'connections\'');
    }
    return this._connections;
  }

  public get configuredGateways(): GatewayConfig[] {
    return this.gateways.values().map(x => ({ az: x[0], gatewayId: x[1].ref }));
  }
}
