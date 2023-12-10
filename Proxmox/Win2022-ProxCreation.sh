#!/bin/bash

# Define VM ID and Storage
VM_ID=131
STORAGE_POOL="/mnt/pve/CHANGEME"

# Allocate disks before VM creation

# Step 1: Allocate the main SCSI disk
pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-0.qcow2 100G

# Step 2: Allocate the EFI disk with specified parameters
pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-1.qcow2 528K

# Step 3: Allocate the TPM state disk with specified parameters
pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-2.raw 4M

# Create the VM and attach the pre-allocated disks

# Step 4: Create the main VM
qm create $VM_ID \
    --name "WinServer2022" \
    --memory 4096 \
    --sockets 2 \
    --cores 4 \
    --net0 e1000,bridge=vmbr1 \
    --scsihw virtio-scsi-single \
    --ostype win11 \
    --machine q35 \
    --bios ovmf \
    --ide2 $STORAGE_POOL:iso/windowserver-2022-amd64.iso,media=cdrom \
    --scsi0 /mnt/pve/chocolatestream_storage/images/$VM_ID/vm-$VM_ID-disk-0.qcow2 \
    --efidisk0 /mnt/pve/chocolatestream_storage/images/$VM_ID/vm-$VM_ID-disk-1.qcow2,size=528K,efitype=4m,pre-enrolled-keys=1 \
    --tpmstate0 /mnt/pve/chocolatestream_storage/images/$VM_ID/vm-$VM_ID-disk-2.qcow2,version=v2.0

# Step 5: Start the VM
qm start $VM_ID

# Note: Steps for inserting Autounattend.xml and further Windows configuration would go here.

# Step 6: Install and Configure Active Directory using PowerShell scripts

# Note: Detailed PowerShell commands and Proxmox API calls would be required here.
