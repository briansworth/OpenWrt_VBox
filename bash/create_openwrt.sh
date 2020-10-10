#!/bin/bash

Help()
{
  echo
  echo "Download OpenWRT and create a VirtualBox VM for running it"
  echo
  echo "This script will download the provided OpenWRT version and"
  echo "create a Virtual Box virtual machine using this version of"
  echo "OpenWRT as the boot disk."
  echo "By default, this VM will have 3 network interface cards"
  echo "  1. Internal network adapter"
  echo "  2. NAT network adapter"
  echo "  3. Host-only network adapter"
  echo "It will have very low specs, 512 MB hdd, 256 MB vRAM, 1 vCPU"
  echo
  echo "Syntax: create_openwrt [-n|d|v]"
  echo
  echo -e "\t-d\tBase VM directory. The directory in which to place"
  echo -e "\t\tthe VM folder / files. A subdirectory named after the"
  echo -e "\t\tVM will be created under this directory."
  echo -e "\t\t(default: '\$HOME/vm')"
  echo
  echo -e "\t-n\tName of the virtual machine to create"
  echo -e "\t\t(default: 'wrt')"
  echo
  echo -e "\t-v\tThe version of OpenWrt to download and install"
  echo -e "\t\t(default: '19.07.4')"
  echo
  echo -e "\t-h\tDisplay this help page"
  echo
}

# Default values
VERSION='19.07.4'
VM_NAME='wrt'
VM_DIR="$HOME/vm"


while getopts n:v:d:h flag
do
  case "${flag}" in
    h) Help; exit;;
    n) VM_NAME=${OPTARG};;
    d) VM_DIR=${OPTARG};;
    v) VERSION=${OPTARG};;
    *) Help; exit 1;;
  esac
done


# WRT Info
IMG_URI="$VERSION/targets/x86/64/openwrt-$VERSION-x86-64-combined-ext4.img.gz"
DL_PATH="$HOME/Downloads/openwrt-$VERSION.img.gz"
IMG_PATH=${DL_PATH%???}

# VM Info
WRT_VM_DIR="$VM_DIR/$VM_NAME"
VDI_PATH="$WRT_VM_DIR/$VM_NAME.vdi"
HD_SIZE='512'
OS_TYPE='Linux_64'
NET_NAME='net0'

# Download OpenWrt IMG file
wrt_uri="https://downloads.openwrt.org/releases/$IMG_URI"
curl $wrt_uri -o $DL_PATH -sS --fail
if [[ $? -ne 0 ]]; then
  echo "Failed to download OpenWrt Version: $VERSION. Url: $wrt_uri" >&2
  exit 1
fi

gzip -dfk $DL_PATH

# Create OpenWrt VDI HDD
mkdir -p $WRT_VM_DIR
vboxmanage convertfromraw --format VDI $IMG_PATH $VDI_PATH
vboxmanage modifymedium $VDI_PATH --resize $HD_SIZE

# Create OpenWrt VM
vboxmanage createvm --name $VM_NAME \
  --ostype $OS_TYPE \
  --basefolder $VM_DIR \
  --register

# Attach created VDI HDD
vboxmanage storagectl $VM_NAME --name 'IDE' --add ide
vboxmanage storageattach $VM_NAME \
  --storagectl 'IDE' \
  --port 0 \
  --device 0 \
  --type hdd \
  --medium $VDI_PATH

# Modify system / general settings
vboxmanage modifyvm $VM_NAME --cpus 1 --memory 256 --vram 12
vboxmanage modifyvm $VM_NAME --boot1 disk
vboxmanage modifyvm $VM_NAME --audio none

# Add network adapters
host_if=$(vboxmanage list hostonlyifs | grep -E "^Name:\s.+" -m 1 | awk '{ print $2 }')
vboxmanage modifyvm $VM_NAME --nic1 intnet --intnet1 $NET_NAME
vboxmanage modifyvm $VM_NAME --nic2 nat
vboxmanage modifyvm $VM_NAME --nic3 hostonly --hostonlyadapter3 $host_if

vboxmanage showvminfo $VM_NAME | awk 'NR<=20'
