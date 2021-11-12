#!/bin/bash

packer build -var-file="fck-nat-arm64.pkrvars.hcl" -var-file="fck-nat-public-all-regions.pkrvars.hcl" ./fck-nat.pkr.hcl
packer build -var-file="fck-nat-x86_64.pkrvars.hcl" -var-file="fck-nat-public-all-regions.pkrvars.hcl" ./fck-nat.pkr.hcl
