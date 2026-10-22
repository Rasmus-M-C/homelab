# One control plane on pve1, one worker on pve2. Adjust "<-" values per host.

talos_iso_file = "local:iso/talos-amd64.iso"
vm_storage     = "local-lvm"
network_bridge = "vmbr0"

talos_control_configuration = [
  {
    pm_node   = "pve0" # <- your first Proxmox node name
    vmid      = 1110
    vm_name   = "talos-control-1"
    cpu_cores = 4     # <-
    memory    = 4024  # <- MiB
    disk_size = "64G" # <-
    networks = [
      { id = 0, macaddr = "BC:24:11:50:00:19", tag = 0 }
    ]
  },
]

talos_worker_configuration = [
  {
    pm_node   = "pve1" # <- your second Proxmox node name
    vmid      = 2110
    vm_name   = "talos-worker-1"
    cpu_cores = 4      # <-
    memory    = 8192   # <- MiB
    disk_size = "100G" # <-
    networks = [
      { id = 0, macaddr = "BC:24:11:50:00:21", tag = 0 }
    ]
  },
]
