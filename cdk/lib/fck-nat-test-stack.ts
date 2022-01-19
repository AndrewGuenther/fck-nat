/* eslint-disable no-new */

import * as cdk from '@aws-cdk/core'
import { NatInstanceProvider } from '@aws-cdk/aws-ec2'
import { FckNatVpc } from './fck-nat-vpc'

interface FckNatTestStackProps extends cdk.StackProps {
  readonly natInstanceProviders: NatInstanceProvider[]
}

export class FckNatTestStack extends cdk.Stack {
  constructor (scope: cdk.Construct, id: string, props: FckNatTestStackProps) {
    super(scope, id, props)

    for (const [idx, natInstanceProvider] of props.natInstanceProviders.entries()) {
      // There's definitely something better than an index to use here, but it would be a pain to plumb through
      new FckNatVpc(this, `fck-nat-vpc-${idx}`, { natInstanceProvider })
    }
  }
}
