# Choosing an Instance Size

It can be a bit difficult to understand what instance size is best for your needs when considering a fck-nat instance,
but if you keep in mind a few key rules, the decision should be relatively straightforward. We also include some
baseline recommendations below.

The rules of EC2 to internet networking:

1. Most instances offer bandwidth "Up to" a certain amount. This is their burst capacity. Their baseline is
   **signigicantly** smaller. The baseline value is available via the EC2 `describe-instance-types` API.
2. Instances with fewer than 32 vCPUs are limited to a maximum of 5Gbps egress to the internet.
3. Instances with >=32 vCPUs are allowed 50% their baseline bandwidth out to the internet.

Alright, now that we have those rules down, what's the best option for you? It's suggested that you read all of the
sections below before jumping to the one you need because there's a lot of good information spread throughout that
could help in your decision making, but here's a summary table:

| Bandwidth | Instance type | Price per Month |
| --------- | ------------- | --------------- |
| 32Mbps    | t4g.nano      | $3.06           |
| 64Mbps    | t3.micro      | $7.59           |
| 1.6Gbps   | c6gn.medium   | $32.81          |
| 3.125Gbps | c7gn.medium   | $48.25          |
| 5Gbps     | c7gn.large    | $132.20         |
| 25Gbps    | r6in.8xlarge  | $1074.56        |
| 50Gbps    | c7gn.8xlarge  | $1457.66        |

Yes, there's some big jumps there. No, there's not really any sensible option in between.

### I want to spend less than $10 per month on a NAT solution

For you my friend, we have the `t4g.nano`. Not only is the `t4g.nano` the least expensive option out of all instance
types, it also has the highest Gbps/dollar ratio of all the options under $10! The `t4g.nano` supports a burst
bandwidth of up to 5Gbps and a sustained bandwidth of 32Mbps for $3.06/month.

If you're looking for an option that's a little more expensive but has a higher sustained bandwidth, the `t3.micro` is
$7.59/month and supports a sustained bandwidth of 64Mbps.

### I need at least 1Gbps sustained egress

You have two really good options here. The `c6gn.medium` offers a sustained bandwidth of 1.6 Gbps for $32.81/month
which is the lowest price available for any instance supporting >1Gbps egress.

If you're willing to spend a little more, you can get the Rolls Royce of NAT instances, the `c7gn.medium`. The
`c7gn.medium` supports a whopping 3.125Gbps sustained bandwidth and boasts **the highest Gbps/dollar ration out of
any instance type in AWS** for $48.25/month

### How about 5Gbps sustained egress?

If you want to hit the max (at <32vCPUs) sustained capacity of 5Gbps out to the internet then your best option is the
`c7gn.large` which offers 5Gbps sustained for $132.20/month.

### I need **more**

Remember, once you're looking to top 5Gbps, you have to look at instance types with at least 32 vCPUs. This means that
you're looking at a significant price jump. At this point, it is worthwhile considering sticking to NAT Gateway, but
there's definitely high total throughput cases which warrant rolling your own NAT at this scale.

The lowest priced instance offering more than 5Gbps egress is the `c6g.8xlarge` for $794.42/month and offering...6Gbps.
Once you start getting to this level though, the scaling function actually becomes really straightforward because AWS
offers dedicated networking at known increments: 12Gbps (like the `c6g.8xlarge` up there), 25Gbps, 50Gbps, and 100Gbps.
Remember, at >=32vCPUs you're only getting 50% egress bandwidth so the effective values are really 6Gbps, 12.5Gbps,
25Gbps, and 50Gbps

Here's the instance types offering the best value at each of those additional levels:

| Bandwidth | Instance type | Price per Month |
| --------- | ------------- | --------------- |
| 6Gbps     | c6g.8xlarge   | $794.42         |
| 12.5Gbps  | m5n.8xlarge   | $1510.37        |
| 25Gbps    | r6in.8xlarge  | $1074.56        |
| 50Gbps    | c7gn.8xlarge  | $1457.66        |

As you can see, 6Gbps and 12.5Gbps are simply not economical options when compared to the best 5Gbps and 25Gbps
options. So you're effectively looking at jumping straight from 5Gbps to 25Gbps if you need higher sustained
bandwidth.

??? note "How were these values calculated?"
    Through some pain, effort, and a lot of `jq` you can produce the source data on your own and perform your own
    analysis on instance types. The scripts below will pull network bandwidth information from the EC2 API and pricing
    information from the pricing API then combine them along with a `max_egress` value that takes into account the
    rules above and a `ratio` value which is effectively Gbps per dollar and is used as a measurement of "value"

    ```shell
    aws ec2 describe-instance-types \
        --output json \
    | jq '.InstanceTypes[] | { (.InstanceType): { vcpus: .VCpuInfo.DefaultVCpus, baseline: .NetworkInfo.NetworkCards[0].BaselineBandwidthInGbps, burst: .NetworkInfo.NetworkPerformance}}' \
    | jq -s add > instance-networking.json


    aws pricing get-products \
        --service-code AmazonEC2 \
        --filters "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
        --region us-east-1 \
    | jq -rc '.PriceList[]' \
    | jq -r '{ (.product.attributes.instanceType): { price: (.terms.OnDemand[].priceDimensions[].pricePerUnit.USD | tonumber) }}' \
    | jq -s add > instance-pricing.json

    jq -s '.[0] * .[1]' instance-pricing.json instance-networking.json \
    | jq 'with_entries(select(.value | has("baseline") and has("price") and .price > 0.0))' \
    | jq 'to_entries | map(.value |= . + {max_egress: (if .vcpus < 32 then ([.baseline, 5.0] | min) else .baseline / 2 end) }) | map(.value |= . + {ratio: (.max_egress / (.price | tonumber)), price_monthly: (.price * 730)}) | sort_by(.value.ratio) | from_entries' > instance-merged.json
    ```
