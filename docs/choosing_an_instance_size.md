# Choosing an Instance Size

It can be a bit difficult to understand what instance size is best for your needs when considering a fck-nat instance,
but if you keep in mind a few key rules, the decision should be relatively straightforward. We also include some
baseline recommendations below.

The rules of EC2 to internet networking:

1. Most instances offer bandwidth "Up to" a certain amount. This is their burst capacity. Their baseline is
   **significantly** smaller. The baseline value is available via the EC2 `describe-instance-types` API.
2. Instances with fewer than 32 vCPUs are limited to a maximum of 5Gbps egress to the internet.
3. Instances with >=32 vCPUs are allowed 50% their baseline bandwidth out to the internet.
4. Certain instance types are excluded from this rule and are allowed their full baseline bandwidth out to the internet:
   `c8in`, `c8ine`, `m8in`, `m8ine`, `m8idn`, `r8in`, and `r8idn`.

Reference: [Amazon EC2 instance network bandwidth](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-network-bandwidth.html)

All right, now that we have those rules down, what's the best option for you? It's suggested that you read all of the
sections below before jumping to the one you need because there's a lot of good information spread throughout that
could help in your decision making, but here's a summary table:

| Bandwidth | Instance type | Price per Month |
| --------- | ------------- | --------------- |
| 32Mbps    | t4g.nano      | $3.07           |
| 64Mbps    | t4g.micro     | $6.13           |
| 128Mbps   | t4g.small     | $12.26          |
| 1.6Gbps   | c6gn.medium   | $31.54          |
| 3.125Gbps | c8gn.medium   | $43.29          |
| 5Gbps     | c8gn.large    | $86.51          |
| 6.25Gbps  | c8in.xlarge   | $198.68         |
| 12.5Gbps  | c8in.2xlarge  | $397.35         |
| 25Gbps    | c8in.4xlarge  | $794.71         |
| 100Gbps   | c8gn.16xlarge | $2768.16        |

Yes, there are some big jumps there. The most cost-effective options are <= 5 Gbps.

### I want to spend less than $10 per month on a NAT solution

For you my friend, we have the `t4g.nano`. Not only is the `t4g.nano` the least expensive option out of all instance
types, it has the highest Gbps/dollar ratio of all the options under $10! The `t4g.nano` supports a burst bandwidth of
up to 5Gbps and a sustained bandwidth of 32Mbps for $3.07/month.

The entire `t4g` family has the same price ratio per Gbps. So if you're looking for an option that's a little more
expensive but has a higher bandwidth, the `t4g.micro` is $6.13/month and supports a sustained bandwidth of 64Mbps.

### I need at least 1Gbps sustained egress

You have two really good options here. The `c6gn.medium` offers a sustained bandwidth of 1.6 Gbps for $31.54/month,
which is the lowest price available for any instance supporting >1Gbps egress.

If you're willing to spend a little more, you can get the Rolls Royce of NAT instances, the `c8gn.medium`. The
`c8gn.medium` supports a whopping 3.125Gbps sustained bandwidth and boasts **the highest Gbps/dollar ratio of any
instance type in AWS** for $43.29/month.

### How about 5Gbps sustained egress?

If you want to hit the max (at <32vCPUs) sustained capacity of 5Gbps out to the internet, then your best option is the
`c8gn.large`, which offers 5Gbps sustained for $86.51/month.

### I need **more**

For over 5Gbps on a single instance, expect to pay *much* more. AWS only offers greater bandwidth on instance types
with at least 32 vCPUs, or certain special network-optimized instance families. This means that you're looking at a
significant price jump. (To get 5x the bandwidth, you'll pay >9x the price.)

At this point, it's worthwhile to consider sticking with NAT Gateway, but rolling your own NAT might still be warranted
at this scale if your total throughput is high enough.

Normally instances with >= 32 vCPUs get 50% of baseline bandwidth for IGW traffic, but the
[`c8in` and `c8ine` families](https://aws.amazon.com/ec2/instance-types/c8i/)
are special Intel-based instances optimized for high bandwidth workloads, which instead get 100% of baseline even for
IGW traffic. (All of our other best picks in t4g/c8gn/etc. are Graviton `arm64`, but c8in are Intel `x86_64` instead.)

Here are the lowest-priced instances at each relevant bandwidth level:

| Bandwidth | Instance type | Price per Month | Price per Month per Gbps |
| --------- | ------------- | --------------- | ------------------------ |
| 32Mbps    | t4g.nano      | $    3.07       | $   95.81                |
| 64Mbps    | t4g.micro     | $    6.13       | $   95.81                |
| 128Mbps   | t4g.small     | $   12.26       | $   95.81                |
| 256Mbps   | t4g.medium    | $   24.53       | $   95.81                |
| 1.6Gbps   | c6gn.medium   | $   31.54       | $   19.71                |
| 3.125Gbps | c8gn.medium   | $   43.29       | $   13.85                |
| 5Gbps     | c8gn.large    | $   86.51       | $   17.30                |
| 6.25Gbps  | c8in.xlarge   | $  198.68       | $   31.79                |
| 12.5Gbps  | c8in.2xlarge  | $  397.35       | $   31.79                |
| 25Gbps    | c8in.4xlarge  | $  794.71       | $   31.79                |
| 50Gbps    | c8gn.8xlarge  | $ 1384.08       | $   27.68                |
| 100Gbps   | c8gn.16xlarge | $ 2768.16       | $   27.68                |

The `c8in` family provides economical options between 5Gbps and 25Gbps. The spec sheet says you could go all the way up
to `c8in.48xlarge` for 300Gbps, but this is untested with fck-nat.

??? note "How were these values calculated?"
    Through some pain, effort, and a lot of `jq` you can produce the source data on your own and perform your own
    analysis on instance types. The scripts below will pull network bandwidth information from the EC2 API and pricing
    information from the pricing API then combine them along with a `max_egress` value that takes into account the
    rules above and a `ratio` value which is effectively Gbps per dollar and is used as a measurement of "value"

    You can find the scripts below as well as the most recent output to run your own analysis on in the
    [`docs/pricing_analysis`](https://github.com/AndrewGuenther/fck-nat/tree/main/docs/pricing_analysis) folder

    ```shell
    aws ec2 describe-instance-types \
        --output json \
    | jq '.InstanceTypes[] | { (.InstanceType): { vcpus: .VCpuInfo.DefaultVCpus, baseline: .NetworkInfo.NetworkCards[0].BaselineBandwidthInGbps, burst: .NetworkInfo.NetworkPerformance}}' \
    | jq -s add > instance-networking.json


    aws pricing get-products \
        --service-code AmazonEC2 \
        --filters \
            "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
            "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
            "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
            "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
            "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
            "Type=TERM_MATCH,Field=operation,Value=RunInstances" \
        --region us-east-1 \
    | jq -rc '.PriceList[]' \
    | jq -rc 'select(.product.productFamily=="Compute Instance")' \
    | jq -r '{ (.product.attributes.instanceType): { price: (.terms.OnDemand[].priceDimensions[].pricePerUnit.USD | tonumber) }}' \
    | jq -s add > instance-pricing.json

    jq -s '.[0] * .[1]' instance-pricing.json instance-networking.json \
    | jq 'with_entries(select(.value | has("baseline") and has("price") and .price > 0.0))' \
    | jq 'with_entries(select(.key | test("^hpc") | not))' \
    | jq 'to_entries | map(. as $entry | .value |= . + {max_egress: (if ($entry.key | test("^(c8in|c8ine|m8in|m8ine|m8idn|r8in|r8idn)\\.")) then .baseline elif .vcpus < 32 then ([.baseline, 5.0] | min) else .baseline / 2 end) }) | map(.value |= . + {ratio: (.max_egress / (.price | tonumber)), price_monthly: (.price * 730)}) | sort_by(.value.ratio) | from_entries' > instance-merged.json
    ```
