#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { FckNatStack } from '../lib/fck-nat-stack';
import { FckNatPerfStack } from '../lib/fck-nat-perf-stack';

const app = new cdk.App();
const env = { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION }

// TODO: Instance size for both the NAT and perf instances should be parameterized.
new FckNatStack(app, 'FckNatStack', { env });
new FckNatPerfStack(app, 'FckNatPerfStack', { env });
