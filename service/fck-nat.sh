#!/bin/sh

if test -f "/etc/fck-nat.conf"; then
    echo "Found fck-nat configuration at /etc/fck-nat.conf"
    . /etc/fck-nat.conf
else
    echo "No fck-nat configuration at /etc/fck-nat.conf"
fi

aws_region="$(/opt/aws/bin/ec2-metadata -z | cut -f2 -d' ' | sed 's/.$//')"
eth0_mac="$(cat /sys/class/net/eth0/address)"
token="$(curl -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 300' http://169.254.169.254/latest/api/token)"
eth0_eni_id="$(curl -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/network/interfaces/macs/$eth0_mac/interface-id)"

if test -n "$eip_id"; then
    echo "Found eip_id configuration, associating $eip_id..."

    aws ec2 associate-address \
        --region "$aws_region" \
        --allocation-id "$eip_id" \
        --network-interface-id "$eth0_eni_id" \
        --allow-reassociation
    sleep 3
fi

if test -n "$eni_id"; then
    echo "Found eni_id configuration, attaching $eni_id..."

    instance_id="$(/opt/aws/bin/ec2-metadata -i | cut -f2 -d' ')"

    aws ec2 modify-network-interface-attribute \
        --region "$aws_region" \
        --network-interface-id "$eth0_eni_id" \
        --no-source-dest-check

    while ! aws ec2 attach-network-interface \
        --region "$aws_region" \
        --instance-id "$instance_id" \
        --device-index 1 \
        --network-interface-id "$eni_id"; do
        echo "Waiting for ENI to attach..."
        sleep 5
    done

    while ! ip link show dev eth1; do
        echo "Waiting for ENI to come up..."
        sleep 1
    done

    nat_public_interface="eth0"
    nat_private_interface="eth1"
elif test -n "$interface"; then
    echo "Found interface configuration, using $interface"
    nat_public_interface=$interface
    nat_private_interface=$nat_public_interface
else
    nat_public_interface=$(ip route | grep default | cut -d ' ' -f 5)
    nat_private_interface=$nat_public_interface
    echo "No eni_id or interface configuration found, using default interface $nat_public_interface"
fi

echo "Enabling IPv4 forwarding..."
sysctl -q -w net.ipv4.ip_forward=1

echo "Disabling IPv4 reverse path protection..."
for i in $(find /proc/sys/net/ipv4/conf/ -name rp_filter) ; do
  echo 0 > $i;
done

echo "Flushing IPv4 NAT table..."
iptables -t nat -F

echo "Adding IPv4 NAT rules..."
iptables -t nat -A POSTROUTING -o "$nat_public_interface" -j MASQUERADE -m comment --comment "NAT routing rule installed by fck-nat"

if test -n "$nat64_enabled"; then
    echo "Found nat64_enabled configuration, setting up NAT64 via TAYGA..."
    nat_public_interface_ipv4="$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/network/interfaces/macs/$eth0_mac/local-ipv4s | head -n 1)"
    nat_public_interface_ipv6="$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/network/interfaces/macs/$eth0_mac/ipv6s | head -n 1)"

    pkill tayga
    /usr/local/sbin/tayga --rmtun

    cat <<EOF > /usr/local/etc/tayga.conf
tun-device nat64
ipv4-addr ${nat64_ipv4_addr:-192.168.255.1}
ipv6-addr ${nat64_ipv6_addr:-2001:db8:1::2}
prefix 64:ff9b::/96
dynamic-pool ${nat64_ipv4_dynamic_pool:-192.168.0.0/16}
data-dir /var/db/tayga
EOF

    echo "Creating nat64 interface..."
    /usr/local/sbin/tayga --mktun
    ip link set nat64 up
    ip addr add "$nat_public_interface_ipv4" dev nat64
    ip addr add "$nat_public_interface_ipv6" dev nat64
    ip route add "${nat64_ipv4_dynamic_pool:-192.168.0.0/16}" dev nat64
    ip route add 64:ff9b::/96 dev nat64
    /usr/local/sbin/tayga

    echo "Enabling IPv6 forwarding..."
    sysctl -q -w net.ipv6.conf."$nat_public_interface".accept_ra=2
    sysctl -q -w net.ipv6.conf."$nat_private_interface".accept_ra=2
    sysctl -q -w net.ipv6.conf.all.forwarding=1
fi

if test -n "$cwagent_enabled" && test -n "$cwagent_cfg_param_name"; then
    echo "Found cwagent_enabled and cwagent_cfg_param_name configuration, starting CloudWatch agent..."
    systemctl enable amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:$cwagent_cfg_param_name"
fi

echo "Done!"
