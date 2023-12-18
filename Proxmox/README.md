# Ch0colate 3xplosion Proxmox Creation Tool

### Task To Be Completed
1. Create function for CPU Type Selection

## Proxmox VM Creation Completed
- [X] Creates VM either Linux or Windows
- [X] If Windows 11 OS Type is selected will create TPM and EFI Disk for that machine
- [X] Storage size will be dependant on OS Type selected, if Windows 11 is selected 100 GB will be required, if lower atleast 50 GB will be required
- [X] User selection for VM ID with error checking
- [X] User selection for VM name with error checking
- [X] User selection for CPU Sockets, CPU Cores, RAM Size Selection
- [X] User selection for SCSI Hardware Controller
- [X] User selection for Net Adapter and Bridge

#### Future Task List
1. User ability to modify, Start at boot, Start/Shutdown Order, startup delay, shutdown timeout, Resource Pool
2. User ability to create Networks, bonds, bridges, VLAN Aware
3. User ability to download ISO, Images, based on OS
4. Add Apple MAC VM creation (illegal *cough*)
5. Fix function Error Checking output
6. Add BSD VM creation selection, or OS type
7. Add simple, complex or automated VM creation for user
8. Storage type selection, RAW, vmdk, qcow2
9. Storage selection of SSD emulation, read-only, Async IO selection
10. User ability to add CPU Flags, VCPUs, CPU Units, CPU Affinity
11. User ability to select ballooning device, or minmum memory
12. User ability to select VLAN tag, Firewall selection, MTU, Multiqueue
13. User ability to add tags
