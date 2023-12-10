#!/bin/bash 
#For Proxmox Server
#Created by Chocolate Explosion/wh0amI (Same Person)

#Change this in the future if KVM qcow2 is different
DOWNLOAD_QCOW2LINK="https://cdn.amazonlinux.com/os-images/2.0.20231116.0/kvm/amzn2-kvm-2.0.20231116.0-x86_64.xfs.gpt.qcow2"

#This bash script was generated for Proxmox to create and automate the creation of Amazon Linux 2 on premise
echo "Now downloading Amazon Linux 2 KVM qcow2 file"
cd /tmp
wget https://cdn.amazonlinux.com/os-images/2.0.20231116.0/kvm/amzn2-kvm-2.0.20231116.0-x86_64.xfs.gpt.qcow2

echo "Moving the Amazon GPT qcow2 to selected storage"

choose_storage_vm_disk() {
    # Get and list storage pools
    pools=$(pvesm status | awk 'NR>1 {print NR-1 ") " $1}')

    if [ -z "$pools" ]; then
		echo "No storage pools found."
		exit 1
    fi

    # Display pools and prompt user to select a pool
    read -p "$(echo -e "Available Storage Pools for Amazon Linux 2 qcow2:\n$pools\nSelect a storage pool (enter the number): ")" pool_number

    # Validate the input is a number
    if ! [[ "$pool_number" =~ ^[0-9]+$ ]]; then
		echo "Invalid input. Please enter a number."
		exit 1
    fi

    # Extract the selected pool name
    selected_pool=$(echo "$pools" | awk -v num=$pool_number 'NR == num {print $2}')

    if [ -z "$selected_pool" ]; then
		echo "Invalid selection. Please try again."
		exit 1
    fi

    echo "$selected_pool"
}
STORAGE_AMAZON_DISK=$(choose_storage_vm_disk)
echo "Selected $STORAGE_AMAZON_DISK for the Amazon Linux 2 qcow2 to be moved too"

# Define the VM disk name
VM_AMAZON_DISK_NAME="vm-amazon-disk-1.qcow2"

# Determine the storage type and construct the destination path accordingly
STORAGE_TYPE_SELECTION=$(pvesm status | grep "^$STORAGE_AMAZON_DISK" | awk '{print $3}')
DEST_PATH=""

if [ "$STORAGE_TYPE" == "dir" ] || [ "$STORAGE_TYPE" == "nfs" ]; then
    DEST_PATH="/mnt/pve/$STORAGE_AMAZON_DISK/images/$VM_ID/"
elif [ "$STORAGE_TYPE" == "lvm" ] || [ "$STORAGE_TYPE" == "lvmthin" ]; then
    DEST_PATH="/dev/$STORAGE_AMAZON_DISK/"
else
    echo "Unsupported storage type: $STORAGE_TYPE"
    exit 1
fi

# Confirm with the user before moving the file
read -p "Move the downloaded Amazon Linux 2 qcow2 file to $DEST_PATH? [Y/n] " confirm
if [[ $confirm =~ ^[Yy]$ ]] || [[ -z $confirm ]]; then
    echo "Moving downloaded Amazon Linux 2 qcow2 file to the storage pool: $STORAGE_AMAZON_DISK"
    mv /tmp/amzn2-kvm-2.0.20231116.0-x86_64.xfs.gpt.qcow2 "$DEST_PATH$VM_DISK_NAME"
else
    echo "Operation cancelled by the user."
    exit 1
fi

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

# Function to check if VM ID is already in use and that only numbers are inputted
check_vm_id() {
    local existing_ids=$(pvesh get /cluster/resources -type vm --output-format yaml | egrep -i 'vmid' | awk '{print $2}')

    while true; do
        read -p "Please enter the VM ID of the Proxmox VM (numeric only): " VM_ID

        # Check if the input is numeric
        if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
            echo "Invalid input. Please enter a numeric VM ID."
            continue  # Skip the rest of the loop and prompt again
        fi

        # Check if the VM ID is already in use
        if grep -q "^$VM_ID$" <<< "$existing_ids"; then
            echo "Error: VM ID $VM_ID is already in use. Please choose a different VM ID."
        else
            echo "Selected VM ID: $VM_ID"
            break  # Valid ID, break out of the loop
        fi
    done
    echo "$VM_ID"
}
# Call the function to get the selected VM ID
VM_ID=$(check_vm_id)
echo "$VM_ID was selected as the VM ID"

# Function to get a valid VM name from the user
get_vm_name() {
    while true; do
        read -p "Please enter VM name: " VM_NAME

        # Check if VM name contains only alphanumeric characters, hyphens, and underscores
        if [[ "$VM_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Selected VM Name: $VM_NAME"
            break
        else
            echo "VM name contains illegal characters. Please reenter."
        fi
    done
    echo "$VM_NAME"
}
VM_NAME=$(get_vm_name)
echo "$VM_NAME selected for Proxmox VM"

# Function to list available memory options for VM
list_memory_options() {
    total_memory_mib=$(free -m | awk '/^Mem:/{print int($2)}')
    available_options=()
    option=2048

    while [ "$option" -le "$total_memory_mib" ]; do
        available_options+=("$option")
        option=$((option * 2))
    done

    echo "${available_options[@]}"
}

# User input for VM parameters
total_memory_mib=$(free -m | awk '/^Mem:/{print int($2)}')
echo "Total Physical Memory Available: $total_memory_mib MiB"

# Display memory options without "MiB" suffix
memory_options=($(list_memory_options))
num_options=${#memory_options[@]}

if [ "$num_options" -eq 0 ]; then
    echo "Insufficient memory for VM creation."
    exit 1
fi

echo "Available Memory Options for VM:"
for ((i = 0; i < num_options; i++)); do
    echo "$((i + 1)). ${memory_options[i]}"
done

# Read and validate user input for memory
while true; do
    read -p "Enter the number corresponding to the desired memory option (1 to $num_options): " selection

    if [[ "$selection" -ge 1 && "$selection" -le "$num_options" ]]; then
        MEMORY="${memory_options[$((selection - 1))]} MiB"
        break
    else
        echo "Invalid selection. Please choose a number from 1 to $num_options."
    fi
done

# Display selected memory without "MiB" suffix
echo "Selected Memory for VM: $MEMORY"

# Function to get the total number of CPU sockets and allow the user to select a number
choose_cpu_sockets() {
    # Get the total number of CPU sockets (Assuming each physical CPU is one socket)
    total_sockets=$(lscpu | grep "Socket(s):" | awk '{print $2}')

    if [ -z "$total_sockets" ]; then
		echo "Unable to determine the total number of CPU sockets."
		exit 1
    fi

    echo "Total CPU sockets available: $total_sockets"

    # Prompt user to select the number of sockets
    read -p "Select the number of CPU sockets for the VM (1 to $total_sockets): " selected_sockets

    # Validate the input is within the range
    if ! [[ "$selected_sockets" =~ ^[0-9]+$ ]] || [ "$selected_sockets" -lt 1 ] || [ "$selected_sockets" -gt "$total_sockets" ]; then
		echo "Invalid selection. Please enter a number between 1 and $total_sockets."
		exit 1
    fi

    echo "$selected_sockets"
}
CPU_SOCKETS=$(choose_cpu_sockets)
echo "CPU Sockets: $CPU_SOCKETS"

# Function to get the total number of CPU cores and allow the user to select a number
choose_cpu_cores() {
    # Get the total number of CPU cores
    total_cores=$(lscpu | grep "^CPU(s):" | awk '{print $2}')

    if [ -z "$total_cores" ]; then
		echo "Unable to determine the total number of CPU cores."
		exit 1
    fi

    echo "Total CPU cores available: $total_cores"

    # Prompt user to select the number of cores
    read -p "Select the number of CPU cores for the VM (1 to $total_cores): " selected_cores

    # Validate the input is within the range
    if ! [[ "$selected_cores" =~ ^[0-9]+$ ]] || [ "$selected_cores" -lt 1 ] || [ "$selected_cores" -gt "$total_cores" ]; then
		echo "Invalid selection. Please enter a number between 1 and $total_cores."
		exit 1
    fi

    echo "$selected_cores"
}
CPU_CORES=$(choose_cpu_cores)
echo "You have selected $CPU_CORES CPU core(s) for the VM"

choose_storage_pool() {
    # Get and list storage pools
    pools=$(pvesm status | awk 'NR>1 {print NR-1 ") " $1}')

    if [ -z "$pools" ]; then
		echo "No storage pools found."
		exit 1
    fi

    # Display pools and prompt user to select a pool
    read -p "$(echo -e "Available Storage Pools:\n$pools\nSelect a storage pool (enter the number): ")" pool_number

    # Validate the input is a number
    if ! [[ "$pool_number" =~ ^[0-9]+$ ]]; then
		echo "Invalid input. Please enter a number."
		exit 1
    fi

    # Extract the selected pool name
    selected_pool=$(echo "$pools" | awk -v num=$pool_number 'NR == num {print $2}')

    if [ -z "$selected_pool" ]; then
		echo "Invalid selection. Please try again."
		exit 1
    fi

    echo "$selected_pool"
}
STORAGE_POOL=$(choose_storage_pool)
echo "You have selected the storage pool: $STORAGE_POOL"

function choose_iso_storage_and_image() {
    # Get and list storage pools, excluding 'local-lvm'
    iso_pools=$(pvesm status | awk 'NR>1 && $1 != "local-lvm" {print $1}')

    if [ -z "$iso_pools" ]; then
        echo "No storage pools found."
        exit 1
    fi

    # Search for 'seed.iso' in each pool
    for pool in $iso_pools; do
        if [ -f "/mnt/pve/$pool/template/iso/seed.iso" ]; then
            echo "$pool:iso/seed.iso"
            return
        fi
    done

    echo "seed.iso not found in any storage pool."
    exit 1
}
ISO_SELECTION=$(choose_iso_storage_and_image)

if [ $? -eq 0 ]; then
    echo "$ISO_SELECTION found and will be mounted into VM"
else
    echo "Error: $ISO_SELECTION"
    exit 1
fi

# Prompt for the storage size and append 'G' if not present
read -p "Please enter the storage size (1G+): " STORAGE_SIZE
if [[ ! $STORAGE_SIZE =~ [Gg]$ ]]; then
    STORAGE_SIZE="${STORAGE_SIZE}G"
fi

# Allocate storage for the VM
pvesm alloc "$STORAGE_POOL" "$VM_ID" "vm-$VM_ID-disk-0.qcow2" "$STORAGE_SIZE"
echo "Storage allocated and created for Amazon Linux 2 VM."

# Create the VM
qm create "$VM_ID" \
    --name "$VM_NAME" \
    --memory "$MEMORY" \
    --sockets "$CPU_SOCKETS" \
    --cores "$CPU_CORES" \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-single \
    --ostype l26 \
	--bios seabios
    --machine pc-i440fx-8.1 \
    --ide2 $STORAGE_POOL:iso/seed.iso,media=cdrom \
    --scsi0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-0.qcow2 \
	--scsi1 $STORAGE_POOL:$VM_ID/$VM_DISK_NAME

echo "Starting $VM_NAME"	
qm start $VM_ID

echo "VM $VM_NAME with ID $VM_ID created and started successfully."
