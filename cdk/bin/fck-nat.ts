/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { FckNatTestStack } from '../lib/fck-nat-test-stack'
import { InstanceType } from '@aws-cdk/aws-ec2'
import * as dotenv from 'dotenv'
import { ALL_ARM64_AMIS, ALL_X86_AMIS, getFckNatProviders } from '../lib/fck-nat-amis'
import { FckNatInstanceProvider } from '../lib/fck-nat-ha-nat-provider'

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

const natInstanceProviders: FckNatInstanceProvider[] = []
natInstanceProviders.push(...getFckNatProviders(amiOwner, new InstanceType(arm64InstanceType), arm64AmiNames))
natInstanceProviders.push(...getFckNatProviders(amiOwner, new InstanceType(x86InstanceType), x86AmiNames))

new FckNatTestStack(app, 'FckNatTestStack', {
  natInstanceProviders: natInstanceProviders,
  env
})
