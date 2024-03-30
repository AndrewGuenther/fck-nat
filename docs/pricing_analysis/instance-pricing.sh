#!/usr/bin/env /bin/bash
aws pricing get-products \
    --service-code AmazonEC2 \
    --filters "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
    --region us-east-1 \
    | jq -rc '.PriceList[]' \
    | jq -rc 'select(.product.productFamily=="Compute Instance")' \
    | jq -rc '{ (.product.attributes.instanceType): { price: (.terms.OnDemand[].priceDimensions[].pricePerUnit.USD | tonumber) }}' \
    | jq -s add > instance-pricing.json
