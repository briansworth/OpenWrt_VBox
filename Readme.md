# OpenWrt_VBox

Create a VirtualBox VM to run OpenWRT with one command.

Installing OpenWRT on a VM is not as simple as a traditional OS.
There isn't an ISO file you can use to go through an install wizard.
Instead, it requires downloading an IMG file, and converting it into a
virtual hard disk drive that can then be booted from.

The entire process however, can be automated relatively easily.
The code in this repository contains PowerShell and Bash scripts
to take care of the VM creation, and some other scripts / information
for configuring the VM once it is up and running.

## Examples

### PowerShell

```powershell
New-VBoxOpenWrtVM.ps1 -VMName 'openwrt-0' -Version '19.07.4'
```

### Bash

```bash
create_openwrt.sh -n 'openwrt-0' -v '19.07.4'
```

Both of the examples above will create a VM named 'openwrt-0',
running version 19.07.4 of OpenWRT.

## Additional Information

There is built-in help pages in both scripts that explain additional
details about how to use the scripts,
and the specs of the VM it will create.

### Network configuration

The network configuration is important to note.
The VM will have 3 network adapters attached to it by default.

NIC 1: Internal
    - The interface other machines will use to communicate with / over

NIC 2: NAT
    - This interface will allow for outbound internet connectivity

NIC 3: Host-only
    - The management interface you will use for SSH / HTTP on the host

Using a NAT network adapter instead of a bridged network adapter,
ensures that the VM is not available on the same network as the host.
This means that the built-in DHCP server won't affect the host network.

This configuration does mean that the VM is isolated to the host.
If you plan on having multiple host machines with VMs connected
together, you would want to use a bridged adapter.

#### Network inside the VM

By default, NIC 1 & 2 will be bridged when the VM starts up.
Assuming the host has internet access,
you can connect to the internet right away '`opkg update`'.

NIC 1 will be eth0, and the interface will be named 'lan'.
NIC 2 will be eth1, and the interface will be named 'wan'.
NIC 3 will be eth2, and it will not be configured by default.

To configure NIC 3, you can run the `update_host_adapter.sh` script
on the VM.
This script will add the interface as 'mgmt' and enable DHCP.

Once the Host-only interface is up,
you will be able to manage the server on the host machine using
the Web interface 'LUCI' or over SSH.
