#!/bin/bash

# Source config file
source /etc/gwlbtun.conf

echo "==> Setting up GWLB interface"
echo Mode is $1, In Int is $2, Out Int is $3, ENI is $4, NAT Int is $NAT_PUBLIC_INTERFACE