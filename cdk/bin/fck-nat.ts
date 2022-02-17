/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { FckNatTestStack } from '../lib/fck-nat-test-stack'
import { InstanceType, LookupMachineImage, NatInstanceProvider, NatProvider } from '@aws-cdk/aws-ec2'
import * as dotenv from 'dotenv'
import { FckNatPerfStack } from '../lib/fck-nat-perf-stack'
import { ALL_ARM64_AMIS, ALL_X86_AMIS, getFckNatProviders } from '../lib/fck-nat-amis'

dotenv.config()

const app = new cdk.App()
const env = { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION }

const amiOwner = process.env.FCK_NAT_AMI_OWNER ?? '568608671756'

let arm64AmiNames = process.env.FCK_NAT_ARM64_AMIS?.split(',') ?? ALL_ARM64_AMIS
arm64AmiNames = arm64AmiNames.filter(elem => elem.length > 0)
let x86AmiNames = process.env.FCK_NAT_X86_AMIS?.split(',') ?? ALL_X86_AMIS
x86AmiNames = x86AmiNames.filter(elem => elem.length > 0)

const arm64InstanceType = process.env.FCK_NAT_ARM64_INSTANCE_TYPE ?? 't4g.micro'
const x86InstanceType = process.env.FCK_NAT_X86_INSTANCE_TYPE ?? 't3.micro'

const natInstanceProviders: NatProvider[] = []
natInstanceProviders.push(...getFckNatProviders(amiOwner, new InstanceType(arm64InstanceType), arm64AmiNames))
natInstanceProviders.push(...getFckNatProviders(amiOwner, new InstanceType(x86InstanceType), x86AmiNames))

new FckNatTestStack(app, 'FckNatTestStack', {
  natInstanceProviders: natInstanceProviders,
  env
})

const perfInstanceType = process.env.FCK_NAT_PERF_INSTANCE_TYPE ?? 't4g.micro'
const perfAmiName = process.env.FCK_NAT_PERF_AMI_NAME ?? 'fck-nat-amzn2-*-arm64-ebs'

new FckNatPerfStack(app, 'FckNatPerfStack', {
  natInstanceProvider: new NatInstanceProvider({
    instanceType: new InstanceType(perfInstanceType),
    machineImage: new LookupMachineImage({
      name: perfAmiName,
      owners: [amiOwner]
    })
  }),
  iperfInstanceType: new InstanceType(perfInstanceType),
  env
})
