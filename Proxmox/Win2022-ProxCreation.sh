#!/bin/bash

# Define VM ID and Storage
VM_ID=131
STORAGE_POOL="chocolatestream_storage"
NEW_EFI_SIZE=528K

# Create a new EFI disk with the desired size
qemu-img create -f qcow2 -o size=$NEW_EFI_SIZE /mnt/pve/$STORAGE_POOL/images/$VM_ID/vm-$VM_ID-disk-1.qcow2
echo "Created EFI Disk"

# Allocate the main SCSI disk
pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-0.qcow2 100G
echo "Created Storage Disk for VM"

# Allocate the TPM state disk with specified parameters
pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-2.raw 4M
echo "Created TPM State Disk for VM"

# Create the VM

# Step 4: Create the main VM
qm create $VM_ID \
    --name "WinServer2022" \
    --memory 4096 \
    --sockets 2 \
    --cores 4 \
    --cpu "x86-64-v2-AES" \
    --net0 e1000,bridge=vmbr1 \
    --scsihw virtio-scsi-single \
    --ostype win11 \
    --machine q35 \
    --bios ovmf \
    --ide2 $STORAGE_POOL:iso/windowserver-2022-amd64.iso,media=cdrom \
    --scsi0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-0.qcow2 \
    --efidisk0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-1.qcow2,size=528K,efitype=4m,pre-enrolled-keys=1

echo "VM Created Windows Server 2022"

# Attach the EFI disk to the VM with specific options using qm set
qm set $VM_ID --efidisk0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-1.qcow2,size=528K,efitype=4m,pre-enrolled-keys=1
echo "EFI Disk Set"

# Attach the TPM state disk to the VM
qm set $VM_ID --tpmstate0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-2.raw,version=v2.0
echo "TPM State Disk set for VM"

# Start the VM
qm start $VM_ID
echo "VM Start for $VM_ID"

