resource "proxmox_virtual_environment_vm" "truenas" {
  name          = "truenas"
  bios          = "ovmf"
  description   = "Managed by Terraform"
  tags          = ["terraform", "truenas"]
  migrate       = false
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  tablet_device = false
  started       = true
  node_name     = "datacenter"
  vm_id         = 101

  on_boot = true

  boot_order = ["scsi0"]

  agent {
    # Install qemu-guest-agent for FreeBSD from here https://github.com/gushmazuko/truenas-qemu-guest-agent
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
      mac_addresses
    ]
  }

  initialization {
    datastore_id = ""
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  # Init (because unable to use cloud init with truenas)
  # cdrom {
  #   enabled   = true
  #   file_id   = "local:iso/TrueNAS-13.0-U6.2.iso"
  #   interface = "ide2"
  # }

  disk {
    backup       = false
    discard      = "ignore"
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    iothread     = true
    size         = 32
  }

  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 8192
  }

  # Pass LSI card to the VM
  hostpci {
    device = "hostpci0"
    id     = "0000:03:00" # 1000:0087
    rombar = true
    pcie   = false
  }

  operating_system {
    type = "l26"
  }

  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }

  # network_device {
  #   bridge       = "vmbr1"
  #   disconnected = false
  #   enabled      = true
  #   firewall     = false
  #   model        = "virtio"
  #   # vlan_id      = 1
  # }



}

resource "proxmox_virtual_environment_firewall_rules" "truenas_inbound" {

  depends_on = [proxmox_virtual_environment_vm.truenas]

  node_name = proxmox_virtual_environment_vm.truenas.node_name
  vm_id     = proxmox_virtual_environment_vm.truenas.vm_id

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "TrueNAS interface"
    dport   = "80"
    proto   = "tcp"
    log     = "info"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH"
    dport   = "22"
    proto   = "tcp"
    log     = "info"
  }

  # NFS
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "NFS share TCP"
    source  = "192.168.1.47,192.168.1.100"
    dport   = "111,724,2049"
    proto   = "tcp"
    log     = "info"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "NFS share UDP"
    source  = "192.168.1.47,192.168.1.100"
    dport   = "111,2049"
    proto   = "udp"
    log     = "info"
  }


  rule {
    type    = "in"
    action  = "DROP"
    comment = "Block everything"
    log     = "info"
  }
}


resource "proxmox_virtual_environment_download_file" "truenas_13_0_U6_2_img" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "datacenter"
  url          = "https://download-core.sys.truenas.net/13.0/STABLE/U6.2/x64/TrueNAS-13.0-U6.2.iso"
}
