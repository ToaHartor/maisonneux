#!/bin/bash
set -euo pipefail

# Device has two interfaces : wireguard link (wg0) and wifi link (wlp1s0)
# Try wireguard first as it is only mounted if not in local

function get_ipaddr_of_interface {
    local interface=$1
    if ! ip -f inet addr show $1 &>/dev/null; then
        echo "1"
    else
        echo "$(ip -f inet addr show $1 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')"
    fi
}

iface_list=("wg0" "wlp1s0")

for iface in "${iface_list[@]}"
do
    ipaddr=$(get_ipaddr_of_interface $iface)
    if [[ $ipaddr != "1" ]]; then
        echo "$ipaddr"
        exit 0
    fi
done

exit 1