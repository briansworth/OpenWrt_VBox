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

# Review interfaces
ip link | grep eth2
# now shows eth2 as 'UP'

# Find IP address
ip a show eth2
# should now be able to ssh from this IP address

