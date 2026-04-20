#!/bin/bash

apt install -y ansible

read IFACE GATEWAY <<<"$(
  ip route show default | awk '{print $5, $3}'
)"

IP_ADDR=$(
  ip -4 addr show dev "$IFACE" \
  | awk '/inet / {print $2}' \
  | cut -d/ -f1
)

DNS=$(
  resolvectl dns "$IFACE" 2>/dev/null \
  | awk 'NR>1 {for (i=2;i<=NF;i++) printf "%s ", $i}'
)

# Fallback if resolvectl returns nothing
[ -z "$DNS" ] && DNS=$(awk '/^nameserver/ {printf "%s ", $2}' /etc/resolv.conf)

echo "Interface: $IFACE"
echo "IP:        $IP_ADDR"
echo "Gateway:   $GATEWAY"
echo "DNS:       $DNS"

ansible-playbook -l localhost install_packages_deb.yml

# I haven't figured out why 
#ip address add $IP_ADDR dev $IFACE
#ip route add default via $GATEWAY dev $INTERFACE
resolvectl dns $IFACE $DNS
ansible-playbook -l localhost install_packages_deb.yml
ansible-playbook -l localhost start_timemaster.yml
ansible-playbook -l localhost setup_tuned.yml
ansible-playbook -l localhost assign_interfaces.yml -e "mgmt_bridge_address=$IP_ADDR" -e"gateway=$GATEWAY"
ansible-playbook -l localhost switch_NM_to_systemd-networkd.yml
ansible-playbook -l localhost download_ssc600.yml
echo "reboot the machine and run the following two commands:"
echo "ansible-playbook -l localhost download_ssc600.yml -e\"ssc600_downloadlink=<your downloadlink>\""
echo "ansible-playbook -l localhost install_ssc600.yml"

