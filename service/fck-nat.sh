#!/bin/sh

sysctl -q -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE -m comment --comment "NAT routing rule installed by fck-nat"
