#!/bin/sh

if test -f "/etc/fck-nat.conf"; then
    echo "Found fck-nat configuration at /etc/fck-nat.conf"
    . /etc/fck-nat.conf
else
    echo "No fck-nat configuration at /etc/fck-nat.conf"
fi

if test -n "$eni_id"; then
    echo "Found eni_id configuration, attaching $eni_id..."

    aws_region="$(/opt/aws/bin/ec2-metadata -z | cut -f2 -d' ' | sed 's/.$//')"
    instance_id="$(/opt/aws/bin/ec2-metadata -i | cut -f2 -d' ')"

    aws ec2 attach-network-interface \
        --region "$aws_region" \
        --instance-id "$instance_id" \
        --device-index 1 \
        --network-interface-id "$eni_id"
    
    nat_interface="eth1"
elif test -n "$interface"; then
    echo "Found interface configuration, using $interface"
    nat_interface=$interface
fi

default_interface=$(ip route | grep default | cut -d ' ' -f 5)

echo "Enabling ip_forward..."
sysctl -q -w net.ipv4.ip_forward=1

echo "Adding NAT rules..."
if test -n "$nat_interface"; then
    iptables -A FORWARD -i $nat_interface -o $default_interface -j ACCEPT
    iptables -A FORWARD -i $default_interface -o $nat_interface -m state --state ESTABLISHED,RELATED -j ACCEPT
fi
iptables -t nat -A POSTROUTING -o "$default_interface" -j MASQUERADE -m comment --comment "NAT routing rule installed by fck-nat"

echo "Done!"
