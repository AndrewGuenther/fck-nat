import * as cdk from '@aws-cdk/core';
import { FckNatStack } from '../lib/fck-nat-stack';
import { FckNatPerfStack } from '../lib/fck-nat-perf-stack';
import { InstanceClass, InstanceSize, InstanceType } from '@aws-cdk/aws-ec2';
import * as dotenv from 'dotenv'

dotenv.config()

const app = new cdk.App();
const env = { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION }
const enablePerf = process.env.FCK_NAT_ENABLE_PERF_STACK || false
const amiOwner = process.env.FCK_NAT_AMI_OWNER || '568608671756'

const instanceType = InstanceType.of(InstanceClass.T4G, InstanceSize.MICRO)

new FckNatStack(app, 'FckNatStack', {
  natInstanceType: instanceType,
  iperfInstanceType: enablePerf ? instanceType : undefined,
  amiOwner,
  env
});

if (enablePerf) {
  new FckNatPerfStack(app, 'FckNatPerfStack', {
    iperfInstanceType: instanceType,
    env
  });
}
