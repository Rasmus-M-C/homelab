variable "pm_api_url" {
  description = "e.g. https://192.168.1.10:8006/api2/json"
  type        = string
}

variable "pm_api_token_id" {
  description = "Full token ID, e.g. terraform@pve!terraform"
  type        = string

}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}
variable "talos_iso_file" {
  description = "Talos ISO as <storage>:iso/<file>. Must exist on every Proxmox node used."
  type        = string
  default     = "local:iso/talos-amd64.iso"
}

variable "vm_storage" {
  description = "Proxmox storage for VM disks (local-lvm or local-zfs)"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

# Each node is defined explicitly in values.tfvars.
variable "talos_control_configuration" {
  type = list(object({
    pm_node   = string
    vmid      = number
    vm_name   = string
    cpu_cores = number
    memory    = number # MiB
    disk_size = string # e.g. "64G"
    networks = list(object({
      id      = number
      macaddr = string # fixed MAC -> make a DHCP reservation for it on your router
      tag     = number # VLAN tag, 0 = no VLAN
    }))
  }))
}

variable "talos_worker_configuration" {
  type = list(object({
    pm_node   = string
    vmid      = number
    vm_name   = string
    cpu_cores = number
    memory    = number
    disk_size = string
    networks = list(object({
      id      = number
      macaddr = string
      tag     = number
    }))
  }))
}
