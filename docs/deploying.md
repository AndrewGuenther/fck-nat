# Deploying fck-nat

The most well-supported way to deploy fck-nat with all of its features available out of the box is via CDK. If you're
using another Infrastructure-as-code provider, you can still deploy a basic NAT instance with fck-nat, but it is more
intensive to support some of fck-nat's additional features.

Notably missing at the moment is a Terraform module. If you're using Terraform and would like to leverage fck-nat,
please +1 this issue: [Create a fck-nat Terraform module](https://github.com/AndrewGuenther/fck-nat/issues/4)

## CDK

fck-nat provides an official CDK module which supports all of fck-nat's features (namely high-availability mode)
out-of-the-box. The CDK module is currently available both in Typescript and Python. You can find detailed
documentation on [Construct Hub](https://constructs.dev/packages/cdk-fck-nat/v/1.0.0). Here's an example use of the
CDK construct in Typescript:

``` ts
const vpc = new Vpc(this, 'vpc', {
    natGatewayProvider: new FckNatInstanceProvider({
        instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.MICRO),
    }),
});
```

That's it! This will deploy your VPC using fck-nat as your NAT provider in high availability mode. This includes all
necessary routing configurations and deploys fck-nat in an Autoscaling group to ensure that a new instance is brought
up automatically in case the NAT instance is terminated.

You can also deploy fck-nat in non-HA mode using CDK's built-in `NatInstanceProvider` like so:

``` ts
const vpc = new Vpc(this, 'vpc', {
    natGatewayProvider: new NatInstanceProvider({
        instanceType: InstanceType.of(InstanceClass.T4G, InstanceSize.MICRO),
        machineImage: new LookupMachineImage({
            name: 'fck-nat-amzn2-*-arm64-ebs',
            owners: ['568608671756'],
        })
    }),
});
```

[Read more about the `NatInstanceProvider` construct](https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.NatInstanceProvider.html)

## Cloudformation

For brevity, this document assumes you already have a VPC with public and private subnets defined in your
Cloudformation template. This example template provisions the minimum resources required to connect fck-nat in your
VPC. **This template does not support high availability mode!**

1. A security group allowing ingress traffic from within the VPC and egress out to the internet
2. An EC2 instance using the fck-nat AMI
3. A route in the private subnet route table directing traffic to the fck-nat instance.

This snippet assumes the following resources are already defined:

1. `VPC`: An `AWS::EC2::VPC` resource.
2. `PublicSubnet`: An `AWS::EC2::Subnet` which has an `AWS::EC2::InternetGateway` attached.
3. `PrivateSubnetRouteTable`: An `AWS::EC2::RouteTable` with an `AWS::EC2::SubnetRouteTableAssociation` to a `AWS::EC2::Subnet`

``` yaml
NatInstanceSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
        GroupDescription: "fck-nat Security Group"
        VpcId: !Ref VPC
        SecurityGroupIngress:
        - IpProtocol: tcp
            FromPort: 0
            ToPort: 65535
            CidrIp: !GetAtt VPC.CidrBlock
        SecurityGroupEgress:
        - IpProtocol: tcp
            FromPort: 0
            ToPort: 65535
            CidrIp: 0.0.0.0/0

NatInstance:
    Type: AWS::EC2::Instance
    Properties:
        # You can find the latest public AMI ID with the following command:
        # aws ec2 describe-images --owners 568608671756 --filters 'Name=name,Values=fck-nat-amzn2-*'
        ImageId: ami-005e79c34846da0a4
        InstanceType: t4g.nano
        SourceDestCheck: false
        NetworkInterfaces:
        - AssociatePublicIpAddress: true
            SubnetId: !Ref PublicSubnet
            DeleteOnTermination: true
            DeviceIndex: 0
            GroupSet:
            - !Ref NatInstanceSecurityGroup

PrivateSubnetRoute:
    Type: AWS::EC2::Route
    DependsOn: NatInstance
    Properties:
        RouteTableId: !Ref PrivateSubnetRouteTable
        DestinationCidrBlock: 0.0.0.0/0
        InstanceId: !Ref NatInstance
```

## Manual - Web Console
The following instructions can be used to deploy the fck-nat AMI manually and manipulate the routing table.  
NOTE: The following example uses AMI version 1.2.0 for arm64 on t4g.nano.

### EC2 Instance Launch
1. Visit the EC2 service in your preferred region: [EC2 Link](https://us-east-2.console.aws.amazon.com/ec2/)
2. Click Launch Instances  
   ![Launch Instance](images/2_launch_instance.png "Launch Instance")
3. Give the instance a name
   ![Name Instance](images/3_name_instance.png "Name Instance")
4. Search for AMIs owned by "568608671756"
   ![Search AMI](images/4_search_owner.png "Search AMI Owner")
5. Select the ARM64 1.2.0 fck-nat AMI
   ![Select AMI](images/5_select_ami.png "Select AMI")  
   ![AMI Selected](images/5.2_ami_selected.png "AMI Selected")  
6. Select Instance Type t4g.nano
   ![Select t4g.nano](images/6_select_instance_type.png "Select Instance Type")  
7. Modify Network Settings  
   - Select VPC  
   - Place in public subnet, ensure Public IP is assigned  
   - Attached Security group that permits  
       inbound: entire VPC CIDR inbound, all traffic  
       outbound: 0.0.0.0/0, all traffic  
   ![Network Settings](images/7_network_settings.png "Network Settings")  
8. Leave Storage at 2GB
   ![Storage Settings](images/8_storage_2gb.png "Storage Settings")  
9. Review and launch
   ![Review and Launch](images/9_review_and_launch.png "Review and Launch")  
Wait for Launch

### Modify EC2 Network Interface
We must modify the ENI attached to the newly launched instance to disable source/destination checks, this allows us to route _through_ (actually hairpinning) the instance.
1. Click on the ENI of the instance
   ![Modify ENI](images/1_open_eni.png "Modify ENI")  
2. Select ENI, Click Actions -> Change source/dest. check
   ![change source dest check](images/2_change_source_dest_check.png "Change Source/Dest Check")  
3. Disable Source/Dest check and Save
   ![change source dest check](images/3_disable_and_save.png "Disable Source/Dest Check")  
 
