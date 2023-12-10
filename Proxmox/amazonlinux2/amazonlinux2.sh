#!/bin/bash 

#This bash script was generated for Proxmox to create and automate the creation of Amazon Linux 2 on premise

#!/bin/bash

# Warns user to change 

# Prompt for VM ID, VM Name, and Storage Size
read -p "Please enter the VM ID of the Proxmox VM: " VM_ID
read -p "Please enter VM name: " VM_NAME
read -p "Please enter the storage size (1G+): " STORAGE_SIZE

# Define STORAGE_POOL
STORAGE_POOL="/mnt/pve/CHANGEME"

# Navigate to /opt/ and create a directory for config files
cd /opt/ || exit
mkdir -p amazonlinux_config
cd amazonlinux_config || exit

# Create and write to meta-data file
# PLEASE MODIFY based on Proxmox Configuration, such as hostname and network interface
cat > meta-data << EOF
local-hostname: vm_hostname
network-interfaces: |
  auto eth0
  iface eth0 inet static
  address 192.168.1.10
  network 192.168.1.0
  netmask 255.255.255.0
  broadcast 192.168.1.255
  gateway 192.168.1.254
EOF

echo "meta-data file created."

# Create and write to user-data file
# PLEASE MODIFY based on Proxmox Configuration based on name and password
cat > user-data << EOF
#cloud-config

users:
  - name: administrator
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    home: /home/administrator
    lock_passwd: false
    plain_text_passwd: amazon

#chpasswd:
#  list: |
#    administrator:amazon
#  expire: False

# Other cloud-config settings like package upgrade, package installation, etc.
EOF

echo "user-data file created."

# Generate seed.iso
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
CURRENT_DIR=$(pwd)
echo "Amazon seed.iso was generated in $CURRENT_DIR/seed.iso"

# Wait for 15 minutes before proceeding
echo "Please move the seed.iso to the appropriate storage. Waiting for 15 minutes..."
sleep 900

# Allocate storage for the VM
pvesm alloc "$STORAGE_POOL" "$VM_ID" "vm-$VM_ID-disk-0.qcow2" "$STORAGE_SIZE"
echo "Storage allocated and created for Amazon Linux 2 VM."

# Create the VM
qm create "$VM_ID" \
    --name "$VM_NAME" \
    --memory 4096 \
    --sockets 2 \
    --cores 4 \
    --net0 VirtIO,bridge=vmbr0 \
    --scsihw virtio-scsi-single \
    --ostype linux \
    --machine default \
    --bios default \
    --ide2 $STORAGE_POOL:iso/seed.iso,media=cdrom \
    --scsi0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-0.qcow2

echo "Starting $VM_NAME"	
qm start $VM_ID

echo "VM $VM_NAME with ID $VM_ID created and started successfully."
