#!/bin/bash
# Proxmox VM Creation Tool
# Created by Chocolate Explosion aka wh0amI

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

# Function to list storage pools (except local-lvm) and allow user to select one for ISO and ISO image
choose_iso_storage_and_image() {
    # Get and list storage pools, excluding 'local-lvm'
    iso_pools=$(pvesm status | awk 'NR>1 && $1 != "local-lvm" {print NR-1 ") " $1}')

    if [ -z "$iso_pools" ]; then
		echo "No storage pools found."
		exit 1
    fi

    # Display pools and prompt user to select a pool
    read -p "$(echo -e "Available Storage Pools for ISO:\n$iso_pools\nSelect a storage pool (enter the number): ")" iso_number

    # Validate the input is a number
    if ! [[ "$iso_number" =~ ^[0-9]+$ ]]; then
		echo "Invalid input. Please enter a number."
		exit 1
    fi

    # Extract the selected pool name
    selected_iso_pool=$(echo "$iso_pools" | awk -v num=$iso_number 'NR == num {print $2}')

    if [ -z "$selected_iso_pool" ]; then
		echo "Invalid selection. Please try again."
		exit 1
    fi

    # List available ISO images in the selected storage pool
    iso_images=$(ls /mnt/pve/$selected_iso_pool/template/iso/ | cat -n)

    if [ -z "$iso_images" ]; then
		echo "No ISO images found in the selected storage pool."
		exit 1
    fi

    # Display ISO images and prompt user to select an image
    read -p "$(echo -e "Available ISO Images:\n$iso_images\nSelect an ISO image (enter the number): ")" iso_image_number

    # Validate the input is a number
    if ! [[ "$iso_image_number" =~ ^[0-9]+$ ]]; then
		echo "Invalid input. Please enter a number."
		exit 1
    fi

    # Extract the selected ISO image name
    selected_iso_image=$(echo "$iso_images" | awk -v num=$iso_image_number 'NR == num {print $2}')

    if [ -z "$selected_iso_image" ]; then
		echo "Invalid selection. Please try again."
		exit 1
    fi

    echo "$selected_iso_pool:iso/$selected_iso_image"
}
ISO_SELECTION=$(choose_iso_storage_and_image)
echo "You have selected the storage pool and ISO image: $ISO_SELECTION"

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

# Function to list and select available memory options for VM
select_memory_option() {
    # Use 'grep' and 'cut' as an alternative to 'awk' for compatibility
    local total_memory_mib=$(free -m | grep "^Mem:" | cut -d':' -f2 | cut -d' ' -f2)

    local available_options=()
    local option=2048

    while [ "$option" -le "$total_memory_mib" ]; do
		available_options+=("$option")
		option=$((option * 2))
    done

    echo "Total Physical Memory Available: $total_memory_mib MiB"
    echo "Available Memory Options for VM:"

    local num_options=${#available_options[@]}
    if [ "$num_options" -eq 0 ]; then
		echo "Insufficient memory for VM creation."
		exit 1
    fi

    for ((i = 0; i < num_options; i++)); do
		echo "$((i + 1)). ${available_options[i]} MiB"
    done

    while true; do
	read -p "Enter the number corresponding to the desired memory option (1 to $num_options): " selection
		if [[ "$selection" -ge 1 && "$selection" -le "$num_options" ]]; then
			MEMORY="${available_options[$((selection - 1))]}M"
			echo "Selected Memory for VM: $MEMORY"
			break
		else
			echo "Invalid selection. Please choose a number from 1 to $num_options."
		fi
    done
}
MEMORY=$(select_memory_option)
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

# Function to prompt for the storage size and format it correctly
select_storage_size() {
    while true; do
        local min_storage=0
        case $OS_TYPE in
            "w11")
                min_storage=100
                ;;
            "wxp"|"w2k"|"w2k3"|"w2k8"|"wvista")
                min_storage=50
                ;;
            "win7"|"win8"|"win10")
                min_storage=80
                ;;
            "l24"|"l26")
                min_storage=20
                ;;
            *)
                min_storage=1  # For 'other' types, a minimum of 1G is assumed
                ;;
        esac

        echo "Note: For OS type $OS_TYPE, a minimum storage of $min_storage GB is required."
        read -p "Please enter the storage size (e.g., 20G, 50G, etc.): " STORAGE_SIZE

        # Remove the 'G' suffix and check if the entered value is a number and meets the minimum requirement
        local numeric_size=${STORAGE_SIZE%[Gg]}
        if [[ "$numeric_size" =~ ^[0-9]+$ ]] && [ "$numeric_size" -ge "$min_storage" ]; then
            STORAGE_SIZE="${numeric_size}G"
            echo "Storage size for $VM_NAME is $STORAGE_SIZE"
            break
        else
            echo "Invalid or insufficient storage size. Please enter a value of $min_storage GB or more."
        fi
    done
}

# Function to select network adapter
select_net_adapter() {
    local net_adapters=("e1000" "e1000-82540em" "e1000-82544gc" "e1000-82545em" "e1000e" "i82551" "i82557b" "i82559er" "ne2k_isa" "ne2k_pci" "pcnet" "rtl8139" "virtio" "vmxnet3") # truncated for brevity
    echo "Available Network Adapters:"
    PS3="Select a network adapter: "
    select net in "${net_adapters[@]}"; do
        if [[ -n $net ]]; then
            echo "Selected Network Adapter: $net"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo $net
}
NET_ADAPTER=$(select_net_adapter)
echo "The NET Adapter selected for $VM_NAME is $NET_ADAPTER"
		
# Function to select SCSI Hardware Controller
select_scsi_hw() {
    local scsi_hws=("lsi" "lsi53c810" "megasas" "pvscsi" "virtio-scsi-pci" "virtio-scsi-single")
    echo "Available SCSI Hardware Controllers:"
    PS3="Select a SCSI hardware controller: "
    select scsi in "${scsi_hws[@]}"; do
        if [[ -n $scsi ]]; then
            echo "Selected SCSI Hardware Controller: $scsi"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo $scsi
}
SCSI_CONTROLLER=$(select_scsi_hw)
echo "The SCSI Hardware Controller selected for $VM_NAME is $SCSI_CONTROLLER"

# Function to select OS type and set machine and bios if necessary
select_os_type() {
    local os_types=("other" "wxp" "w2k" "w2k3" "w2k8" "wvista" "win7" "win8" "win10" "win11" "l24" "l26" "solaris")
    echo "Available OS Types:"
    PS3="Select an OS type: "
    select os in "${os_types[@]}"; do
        if [[ -n $os ]]; then
            echo "Selected OS Type: $os"
            if [[ $os == "w11" ]]; then
                MACHINE="pc-q35-8.1"
                BIOS="ovmf"
                echo "Set machine to $MACHINE and bios to $BIOS for Windows 11"
            else
                MACHINE="pc-i440fx-8.1"
                BIOS="seabios"
            fi
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo $os
}

# Function to select Bridge Interface
select_bridge_interface() {
    # Get a list of available bridge interfaces and their IP addresses
    mapfile -t bridges < <(ip a | awk '/vmbr[0-9]+:/ {iface=$2; getline; getline; if ($1 == "inet") print iface, $2}')

    if [ ${#bridges[@]} -eq 0 ]; then
        echo "No bridge interfaces found."
        exit 1
    fi

    echo "Available Bridge Interfaces:"
    for i in "${!bridges[@]}"; do
        echo "$((i + 1)). ${bridges[i]}"
    done

    # Prompt user to select a bridge interface
    while true; do
        read -p "Enter the bridge you want for this VM (1 to ${#bridges[@]}): " bridge_selection
        if [[ "$bridge_selection" =~ ^[0-9]+$ ]] && [ "$bridge_selection" -ge 1 ] && [ "$bridge_selection" -le "${#bridges[@]}" ]; then
            # Extract just the bridge name (vmbr#)
            BRIDGE=$(echo "${bridges[$((bridge_selection - 1))]}" | cut -d ' ' -f 1)
            echo "Selected Bridge Interface: $BRIDGE"
            break
        else
            echo "Invalid selection. Please choose a number from 1 to ${#bridges[@]}."
        fi
    done

    echo $BRIDGE
}
BRIDGE=$(select_bridge_interface)
echo "The Bridge Interface selected for $VM_NAME is $BRIDGE"

create_vm() {
    while true; do
	
	OS_TYPE=$(select_os_type)
	echo "You have selected OS Type: $OS_TYPE"

	STORAGE_SIZE=$(select_storage_size)
	echo "You have selected $STORAGE_SIZE for the VM $VM_NAME"


        # Display a summary of all user selections
        echo "--------------------------------"
        echo "Summary of your selections:"
        echo "Storage Pool: $STORAGE_POOL"
        echo "ISO Image: $ISO_SELECTION"
        echo "VM ID: $VM_ID"
        echo "VM Name: $VM_NAME"
        echo "Memory Size: $MEMORY"
        echo "CPU Sockets: $CPU_SOCKETS"
        echo "CPU Cores: $CPU_CORES"
        echo "CPU Type: $CPU_TYPE"
        echo "Network Adapter: $NET_ADAPTER"
        echo "SCSI Hardware Controller: $SCSI_CONTROLLER"
        echo "Bridge Interface: $BRIDGE"
        echo "Operating System Type: $OS_TYPE"
        echo "--------------------------------"

        # Prompt user to confirm before proceeding
        read -p "Proceed with VM creation? (yes/redo/no): " confirmation
        case "${confirmation,,}" in  # converting to lowercase
            "yes")
                echo "Proceeding with VM creation..."
                break
                ;;
            "redo")
                echo "Redoing the entire selection..."
                continue
                ;;
            "no")
                echo "VM creation cancelled."
                exit 0
                ;;
            *)
                echo "Invalid selection. Please answer yes, redo, or no."
                ;;
        esac
    done

    # Allocate the main SCSI disk
    pvesm alloc "$STORAGE_POOL" "$VM_ID" "vm-$VM_ID-disk-0.qcow2" "$STORAGE_SIZE"
    echo "Storage allocated and created for $VM_NAME VM."

    if [[ $OS_TYPE == "w11" ]]; then
        # Allocate the EFI disk for Windows 11
        pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-1.qcow2 1M
        echo "Created EFI Disk for $VM_NAME"

        # Allocate the TPM state disk for Windows 11
        pvesm alloc $STORAGE_POOL $VM_ID vm-$VM_ID-disk-2.raw 4M
        echo "Created TPM State Disk for $VM_NAME"
    fi

    # Create the VM
    qm create "$VM_ID" \
        --name "$VM_NAME" \
        --memory "$MEMORY" \
        --sockets "$CPU_SOCKETS" \
        --cores "$CPU_CORES" \
        --cpu "$CPU_TYPE" \
        --net0 "$NET_ADAPTER,bridge=$BRIDGE" \
        --scsihw "$SCSI_CONTROLLER" \
        --ostype "$OS_TYPE" \
        --machine "$MACHINE" \
        --bios "$BIOS" \
        --ide2 "$ISO_SELECTION" \
        --scsi0 "$STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-0.qcow2"

    if [[ $OS_TYPE == "w11" ]]; then
        # Attach the EFI and TPM state disk to the VM for Windows 11
        qm set $VM_ID --efidisk0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-1.qcow2,size=528K,efitype=4m,pre-enrolled-keys=1
        qm set $VM_ID --tpmstate0 $STORAGE_POOL:$VM_ID/vm-$VM_ID-disk-2.raw,version=v2.0
    fi

    echo "VM $VM_NAME created successfully."
}

create_vm