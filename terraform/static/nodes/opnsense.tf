resource "proxmox_virtual_environment_vm" "opnsense" {
  name          = "opnsense"
  bios          = "ovmf"
  description   = "Managed by Terraform"
  tags          = ["terraform", "opnsense"]
  migrate       = false
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  tablet_device = false
  started       = true
  node_name     = var.proxmox_node_name
  vm_id         = 102

  on_boot = false

  boot_order = ["scsi0"] # "ide2"

  agent {
    # Install qemu-guest-agent in the interface then enable this
    enabled = true
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  lifecycle {
    ignore_changes = [
      mac_addresses,
      on_boot,
      reboot,
      migrate,
      stop_on_destroy,
    ]
  }

  initialization {
    # datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "192.168.1.205/32"
      }
    }
  }

  # Init (remove once initialized)
  # ! Disable secure boot in bios to be able to boot
  # Log in as installer/opnsense then install on the OS disk, then remove the cdrom
  # cdrom {
  #   enabled = false
  #   # file_id   = proxmox_virtual_environment_download_file.opnsense_img.id
  #   interface = "ide2"
  # }

  # OS disk
  disk {
    backup       = false
    discard      = "ignore"
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    iothread     = true
    size         = 16
    ssd          = true
  }

  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }

  cpu {
    architecture = "x86_64"
    cores        = 2
    sockets      = 1
    type         = "host"
  }

  memory {
    dedicated = 2048
  }

  operating_system {
    type = "l26"
  }

  # vtnet0
  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }

  # vtnet1
  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
}

resource "proxmox_virtual_environment_firewall_options" "opnsense" {
  node_name = proxmox_virtual_environment_vm.opnsense.node_name
  vm_id     = proxmox_virtual_environment_vm.opnsense.vm_id

  # dhcp          = true
  # enabled       = false
  # ipfilter      = true
  # log_level_in  = "info"
  # log_level_out = "info"
  # macfilter     = false
  # ndp           = true
  # input_policy  = "ACCEPT"
  # output_policy = "ACCEPT"
  radv = true
}


# resource "proxmox_virtual_environment_download_file" "opnsense_img" {
#   content_type            = "iso"
#   datastore_id            = "local"
#   file_name               = "opnsense_install_amd64.iso"
#   node_name               = var.proxmox_node_name
#   decompression_algorithm = "bz2"
#   # overwrite               = true
#   url = "https://mirror.ams1.nl.leaseweb.net/opnsense/releases/24.7/OPNsense-24.7-dvd-amd64.iso.bz2"
# }
