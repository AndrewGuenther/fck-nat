# AWS Publish Role (for maintainers)

The CI workflows in `.github/workflows/ami-publish.yml` and
`.github/workflows/ami-release.yml` use OIDC federation to assume an IAM
role in the AMI publishing AWS account (`568608671756`). No long-lived
AWS credentials are stored in GitHub Actions secrets — only the role's
ARN, in the secret `AWS_PUBLISH_ROLE_ARN`.

This page is the reference for setting that role up. It only needs to
be done once per publishing account.

## 1. Create the GitHub OIDC provider

If the publishing account does not already have a GitHub Actions OIDC
provider, create one:

```sh
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

> The thumbprint above is the canonical value AWS publishes for GitHub's
> OIDC issuer. Newer SDKs validate the signing chain directly and the
> thumbprint check is effectively a no-op, but the API still requires
> the field.

## 2. Trust policy for the role

Save as `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::568608671756:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:AndrewGuenther/fck-nat:*"
        }
      }
    }
  ]
}
```

The `sub` condition restricts the role to workflows in this repository.
You can tighten further to `repo:AndrewGuenther/fck-nat:ref:refs/heads/main`
or `:environment:publish` if a deployment environment is configured.

## 3. Permissions policy for the role

Save as `permissions-policy.json`. This grants the EC2 actions Packer
needs to build, register, copy, and (in a future PR) deprecate AMIs.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PackerBuildAndPublish",
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "ec2:EnableImageDeprecation",
        "ec2:DisableImageDeprecation"
      ],
      "Resource": "*"
    }
  ]
}
```

## 4. Create the role and attach the policy

```sh
aws iam create-role \
    --role-name fck-nat-github-actions-publish \
    --assume-role-policy-document file://trust-policy.json

aws iam put-role-policy \
    --role-name fck-nat-github-actions-publish \
    --policy-name fck-nat-publish \
    --policy-document file://permissions-policy.json
```

## 5. Add the role ARN as a repository secret

In the GitHub repo settings → *Secrets and variables* → *Actions*, add:

- **Name:** `AWS_PUBLISH_ROLE_ARN`
- **Value:** `arn:aws:iam::568608671756:role/fck-nat-github-actions-publish`

## 6. (Optional) Test the workflow

Trigger the publish workflow manually:

```sh
gh workflow run ami-publish.yml
```

The first run will build all four AMI variants (`arm64`, `x86_64`,
`nat64-arm64`, `nat64-x86_64`) and copy them to all 34 supported regions.
Expect the run to take ~60–90 minutes depending on AWS API throughput.
