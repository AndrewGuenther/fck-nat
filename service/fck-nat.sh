#!/bin/sh

# Grab the interface with the default route
interface=$(ip route | grep default | cut -d ' ' -f 5)

sysctl -q -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE -m comment --comment "NAT routing rule installed by fck-nat"
