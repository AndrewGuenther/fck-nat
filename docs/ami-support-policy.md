# AMI Support Policy

## Why AMIs are refreshed periodically

AWS automatically deprecates public AMIs **two years after their original
publish date**. Deprecated AMIs still exist and can still be launched by
explicit AMI ID, but they are excluded from `DescribeImages` results by
default — meaning Terraform `aws_ami` data sources, Packer
`source_ami_filter` blocks, and the EC2 console "Browse AMIs" search will
no longer return them unless the caller explicitly opts in to deprecated
images (`include_deprecated = true` in Terraform, `--include-deprecated`
on the AWS CLI).

fck-nat ships infrequent releases — the project is largely feature-complete
and security patches arrive via `dnf` auto-update, not new package
versions. To keep the **latest released version** discoverable past AWS's
two-year wall, fck-nat re-publishes refreshed AMIs of the latest minor
version on a fixed cadence.

## Refresh cadence

The latest released minor version is rebuilt and re-published **every six
months**. The package version is *not* bumped — the publish-date suffix in
the AMI name (e.g. `fck-nat-al2023-hvm-1.4.0-20260801-arm64-ebs`) is the
field that changes between refreshes.

If you pin AMIs by name pattern with `most_recent = true`, you will
transparently graduate to the freshly-published AMI on the next deploy.
If you pin a specific AMI ID, you will need to bump the ID manually
when it is deprecated by AWS.

## What gets refreshed, what doesn't

| Version line | Refreshed periodically? | Notes |
| --- | --- | --- |
| Latest released minor (e.g. v1.4.x) | Yes, every 6 months | Both `fck-nat` and `fck-nat-nat64` flavors, both `arm64` and `x86_64` |
| Older minor versions (v1.3.x, v1.2.x, …) | No | Remain available until AWS auto-deprecates them at 2 years from their original publish date |

If you need a version that has been deprecated by AWS, set
`include_deprecated = true` on your data source and pin the specific
AMI ID.

## Tag-driven releases

When a new release tag is published on GitHub, the corresponding AMIs are
built and published automatically. This replaces the previous manual
release process.

## Future work

A follow-up will introduce explicit deprecation of AMIs older than 12
months (calling `aws ec2 enable-image-deprecation` on prior cohorts so
that consumers using `most_recent = true` graduate to the freshest
publish). Tracked in [issue #107](https://github.com/AndrewGuenther/fck-nat/issues/107).
