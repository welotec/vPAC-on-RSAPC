#!/bin/bash
function find_onboard_MACs {
	old_mac=000000000000
	file=$(mktemp)
	i=0
	files='/sys/class/net/*/address'
	if [[ $1 == 'test' ]]; then
		files='./macs_to_test.txt'
	fi
	for mac in $(cat $files | sort); do
		check=$(( 0x${mac//:/} - 0x${old_mac//:/} ))
		if [[ $check == 1 ]] && (( i < 7 )); then
			echo $old_mac >> $file
			echo $mac >> $file
			((i++))
		elif (( i >= 7 )); then
			break
		else
			i=0
			echo "" > $file
		fi
		old_mac=$mac
	done
	data=$(uniq $file)
	for mac in $data; do
		echo $mac
	done
	rm $file
}

declare -A mac_to_pci

for mac in $(find_onboard_MACs); do
    iface=$(ip a | grep "$mac" -B 1 | awk 'NR==1{print $2}' | cut -d ":" -f 1)
    pci=$(basename "$(readlink -f /sys/class/net/$iface/device)")
    mac_to_pci["$pci"]=$mac
done

for pci in $(printf "%s\n" "${!mac_to_pci[@]}" | sort); do
    echo "${mac_to_pci[$pci]}"
done
# Collect MAC addresses in JSON array format
#json_output="["
#for pci in $(printf "%s\n" "${!mac_to_pci[@]}" | sort); do
#    json_output+="\"${mac_to_pci[$pci]}\","
#done
## Remove trailing comma and close JSON array
#json_output="${json_output%,}]"
#
## Output JSON
#echo "$json_output" | jq .
#
