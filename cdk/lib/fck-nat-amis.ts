import { NatInstanceProvider, InstanceType, LookupMachineImage, NatProvider } from '@aws-cdk/aws-ec2'
import { FckNatInstanceProvider } from './fck-nat-ha-nat-provider'

export const ALL_ARM64_AMIS = ['fck-nat-amzn2-*-arm64-ebs', 'fck-nat-ubuntu-*-arm64-ebs']
export const ALL_X86_AMIS = ['fck-nat-amzn2-*-x86_64-ebs', 'fck-nat-ubuntu-*-x86_64-ebs']

export function getFckNatProviders (
  amiOwner: string,
  instanceType: InstanceType,
  names: string[]
): NatProvider[] {
  const images: NatProvider[] = []

  for (const name of names) {
    images.push(new FckNatInstanceProvider({
      instanceType: instanceType,
      machineImage: new LookupMachineImage({
        name,
        owners: [amiOwner]
      })
    }))
  }

  return images
}
