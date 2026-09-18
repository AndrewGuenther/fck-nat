#!/usr/bin/env bash
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
    | jq -rc '{ (.product.attributes.instanceType): { price: (.terms.OnDemand[].priceDimensions[].pricePerUnit.USD | tonumber) }}' \
    | jq -sS add > instance-pricing.json
