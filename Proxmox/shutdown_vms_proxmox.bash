#!/bin/bash

# Function to check if a VM ID exists
vm_exists() {
    local vm_id="$1"
    if [ -n "$(qm list | awk -v id="$vm_id" '$1 == id {print}')" ]; then
        return 0  # VM ID exists
    else
        return 1  # VM ID does not exist
    fi
}

# Function to gracefully shut down a VM
shutdown_vm() {
    local vm_id="$1"
    if vm_exists "$vm_id"; then
        echo "Shutting down VM $vm_id..."
        qm shutdown "$vm_id"
    else
        echo "VM $vm_id does not exist."
    fi
}

# Function to shutdown a range of VMs
shutdown_vm_range() {
    local start_vm_id="$1"
    local end_vm_id="$2"

    for ((vm_id = start_vm_id; vm_id <= end_vm_id; vm_id++)); do
        shutdown_vm "$vm_id"
    done
}

# Main script

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <VM ID, VM ID Range (start-end), ...>"
    exit 1
fi

for arg in "$@"; do
    if [[ "$arg" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start_id="${BASH_REMATCH[1]}"
        end_id="${BASH_REMATCH[2]}"
        shutdown_vm_range "$start_id" "$end_id"
    else
        shutdown_vm "$arg"
    fi
done

exit 0
