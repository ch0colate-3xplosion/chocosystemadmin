#!/bin/bash

# Define the source directory containing the VM configuration files
config_dir="/etc/pve/qemu-server"

# Define the base VM ID and the target VM ID
base_vm_id=422
target_vm_id=436

# Function to rename and create a new VM configuration
rename_and_create_vm() {
    local source_vm_id="$1"
    local target_vm_id="$2"
    local directory_name="$3"
    
    # Check if the source VM ID exists
    if [ -f "$config_dir/$source_vm_id.conf" ]; then
        # Sanitize the directory name by replacing non-alphanumeric, _, . with -
        sanitized_directory_name=$(echo "$directory_name" | sed -e 's/[^a-zA-Z0-9_-]/-/g' -e 's/--*/-/g')
        
        echo "Renaming VM $source_vm_id to vulnhub-$sanitized_directory_name-01 (VM $target_vm_id)..."
        
        # Create a copy of the VM configuration file with the new VM ID
        cp "$config_dir/$source_vm_id.conf" "$config_dir/$target_vm_id.conf"
        
        # Update the VM configuration file with the new name
        sed -i "s/name: .*/name: vulnhub-$sanitized_directory_name-01/" "$config_dir/$target_vm_id.conf"
        
        # Reload the Proxmox configuration to apply changes
        systemctl restart pveproxy
        echo "VM $source_vm_id renamed and new VM $target_vm_id (vulnhub-$sanitized_directory_name-01) created."
    else
        echo "VM $source_vm_id does not exist."
    fi
}

# Loop through the directories and rename/create VMs
for directory in /mnt/pve/chocolatestream_storage/vulnhub_downloads/vuln_ova/*; do
    if [ -d "$directory" ]; then
        directory_name="$(basename "$directory")"
        rename_and_create_vm "$base_vm_id" "$target_vm_id" "$directory_name"
        ((base_vm_id++))
        ((target_vm_id++))
    fi
done

echo "All VMs renamed and new VMs created."
