/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { FckNatTestStack } from '../lib/fck-nat-test-stack'
import { InstanceClass, InstanceSize, InstanceType, LookupMachineImage, NatInstanceProvider } from '@aws-cdk/aws-ec2'
import * as dotenv from 'dotenv'
import { FckNatPerfStack } from '../lib/fck-nat-perf-stack'

dotenv.config()

const app = new cdk.App()
const env = { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION }
const amiOwner = process.env.FCK_NAT_AMI_OWNER ?? '568608671756'

const instanceType = InstanceType.of(InstanceClass.T4G, InstanceSize.MICRO)

const natInstanceProvider = new NatInstanceProvider({
  instanceType: instanceType,
  machineImage: new LookupMachineImage({
    name: 'fck-nat-amzn2-*-arm64-ebs',
    owners: [amiOwner]
  })
})

new FckNatTestStack(app, 'FckNatTestStack', {
  natInstanceProviders: [natInstanceProvider],
  env
})

new FckNatPerfStack(app, 'FckNatPerfStack', {
  natInstanceProvider: natInstanceProvider,
  iperfInstanceType: instanceType,
  env
})
