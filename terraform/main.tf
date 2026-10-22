# Talos VMs boot from the Talos ISO into maintenance mode and get an IP via
# DHCP. The bootstrap step (bootstrap.ps1 or the Ansible playbook) then
# installs Talos to disk and creates the Kubernetes cluster.

resource "proxmox_vm_qemu" "talos_control" {
  for_each = { for config in var.talos_control_configuration : config.vmid => config }

  target_node = each.value.pm_node
  vmid        = each.value.vmid
  name        = each.value.vm_name
  description = "Talos control plane node. Managed by Terraform."
  tags        = "kubernetes,control"
  agent       = 1
  onboot      = true
  vm_state    = "running"
  qemu_os     = "l26"

  memory  = each.value.memory
  balloon = 0

  cpu {
    cores   = each.value.cpu_cores
    sockets = 1
    type    = "host"
  }

  ipconfig0 = "ip=dhcp"
  skip_ipv6 = true

  dynamic "network" {
    for_each = each.value.networks
    content {
      id      = network.value.id
      model   = "virtio"
      bridge  = var.network_bridge
      macaddr = network.value.macaddr
      tag     = network.value.tag
    }
  }

  scsihw = "virtio-scsi-single"
  boot   = "order=scsi0;ide2" # empty disk on first boot -> falls through to the ISO
  disks {
    scsi {
      scsi0 {
        disk {
          storage  = var.vm_storage
          size     = each.value.disk_size
          iothread = true
          discard  = true
        }
      }
    }
    ide {
      ide2 {
        cdrom {
          iso = var.talos_iso_file
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [vm_state]
  }
}

resource "proxmox_vm_qemu" "talos_worker" {
  for_each = { for config in var.talos_worker_configuration : config.vmid => config }

  target_node = each.value.pm_node
  vmid        = each.value.vmid
  name        = each.value.vm_name
  description = "Talos worker node. Managed by Terraform."
  tags        = "kubernetes,worker"
  agent       = 1
  onboot      = true
  vm_state    = "running"
  qemu_os     = "l26"

  memory  = each.value.memory
  balloon = 0

  cpu {
    cores   = each.value.cpu_cores
    sockets = 1
    type    = "host"
  }

  ipconfig0 = "ip=dhcp"
  skip_ipv6 = true

  dynamic "network" {
    for_each = each.value.networks
    content {
      id      = network.value.id
      model   = "virtio"
      bridge  = var.network_bridge
      macaddr = network.value.macaddr
      tag     = network.value.tag
    }
  }

  scsihw = "virtio-scsi-single"
  boot   = "order=scsi0;ide2"
  disks {
    scsi {
      scsi0 {
        disk {
          storage  = var.vm_storage
          size     = each.value.disk_size
          iothread = true
          discard  = true
        }
      }
    }
    ide {
      ide2 {
        cdrom {
          iso = var.talos_iso_file
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [vm_state]
  }
}
