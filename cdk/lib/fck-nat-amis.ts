import { NatInstanceProvider, InstanceType, LookupMachineImage } from '@aws-cdk/aws-ec2'

export const ALL_ARM64_AMIS = ['fck-nat-amzn2-*-arm64-ebs', 'fck-nat-ubuntu-*-arm64-ebs']
export const ALL_X86_AMIS = ['fck-nat-amzn2-*-x86_64-ebs', 'fck-nat-ubuntu-*-x86_64-ebs']

export function getFckNatProviders (
  amiOwner: string,
  instanceType: InstanceType,
  names: string[]
): NatInstanceProvider[] {
  const images: NatInstanceProvider[] = []

  for (const name of names) {
    images.push(new NatInstanceProvider({
      instanceType: instanceType,
      machineImage: new LookupMachineImage({
        name,
        owners: [amiOwner]
      })
    }))
  }

  return images
}
