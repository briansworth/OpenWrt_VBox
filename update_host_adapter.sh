#!/bin/ash

# Show currently configured interfaces
uci show network

# Identify NICs on system
ip link
# shows eth2 as 'DOWN'

# Create MGMT interface using eth2
uci set network.mgmt=interface
uci set network.mgmt.ifname='eth2'
uci set network.mgmt.proto='dhcp'

# Review uci changes
uci changes
# Apply configuration changes
uci commit

# Reload network
/etc/init.d/network restart

# Wait for network restart before getting interface
sleep 4
echo
echo

# Show eth2 interface & IP address
ip a show eth2
# should now be able to ssh from this IP address
