#!/bin/sh

if test -f "/etc/fck-nat.conf"; then
    echo "Found fck-nat configuration at /etc/fck-nat.conf"
    . /etc/fck-nat.conf
else
    echo "No fck-nat configuration at /etc/fck-nat.conf"
fi

token="$(curl -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 300' http://169.254.169.254/latest/api/token)"
instance_id="$(curl -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)"
aws_region="$(curl -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/placement/region)"
outbound_mac="$(curl -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/mac)"
outbound_eni_id="$(curl -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/network/interfaces/macs/$outbound_mac/interface-id)"
nat_interface=$(ip link show dev "$outbound_eni_id" | head -n 1 | awk '{print $2}' | sed s/://g )

if test -n "$eip_id"; then
    echo "Found eip_id configuration, associating $eip_id..."

    aws ec2 associate-address \
        --region "$aws_region" \
        --allocation-id "$eip_id" \
        --network-interface-id "$outbound_eni_id" \
        --allow-reassociation
    sleep 3
fi

if test -n "$eni_id"; then
    echo "Found eni_id configuration, attaching $eni_id..."

    aws ec2 modify-network-interface-attribute \
        --region "$aws_region" \
        --network-interface-id "$outbound_eni_id" \
        --no-source-dest-check

    if ! ip link show dev "$eni_id"; then
        while ! aws ec2 attach-network-interface \
            --region "$aws_region" \
            --instance-id "$instance_id" \
            --device-index 1 \
            --network-interface-id "$eni_id"; do
            echo "Waiting for ENI to attach..."
            sleep 5
        done

        while ! ip link show dev "$eni_id"; do
            echo "Waiting for ENI to come up..."
            sleep 1
        done
    else
        echo "$eni_id already attached, skipping ENI attachment"
    fi
elif test -n "$interface"; then
    echo "Found interface configuration, using $interface"
    nat_interface=$interface
else
    echo "No eni_id or interface configuration found, using default interface $nat_interface"
fi

echo "Enabling ip_forward..."
sysctl -q -w net.ipv4.ip_forward=1

echo "Disabling reverse path protection..."
for i in $(find /proc/sys/net/ipv4/conf/ -name rp_filter) ; do
  echo 0 > $i;
done

echo "Flushing NAT table..."
iptables -t nat -F

echo "Adding NAT rule..."
iptables -t nat -A POSTROUTING -o "$nat_interface" -j MASQUERADE -m comment --comment "NAT routing rule installed by fck-nat"

if test -n "$cwagent_enabled" && test -n "$cwagent_cfg_param_name"; then
    echo "Found cwagent_enabled and cwagent_cfg_param_name configuration, starting CloudWatch agent..."
    systemctl enable amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:$cwagent_cfg_param_name"
fi

if test -n "$route_table_ids"; then
    echo "Found route_table_ids configuration, ... "

    for route_table_id in $(echo "$route_table_ids" | tr ',' ' '); do
        echo "Routing internet traffic for $route_table_id to $instance_id"

        internet_route_state=$(aws ec2 describe-route-tables \
            --region "$aws_region" \
            --route-table-ids "$route_table_id" \
            --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].State | [0]" \
            --output text)

        if [ "$internet_route_state" = "active" ]; then
            aws ec2 replace-route \
                --region "$aws_region" \
                --route-table-id "$route_table_id" \
                --destination-cidr-block "0.0.0.0/0" \
                --instance-id "$instance_id"
        else
            aws ec2 create-route \
                --route-table-id "$route_table_id" \
                --destination-cidr-block "0.0.0.0/0" \
                --instance-id "$instance_id" \
                --region "$aws_region"
        fi
        sleep 3
    done
fi

echo "Done!"
