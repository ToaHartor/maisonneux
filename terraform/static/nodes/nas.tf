resource "proxmox_virtual_environment_vm" "nas" {
  bios          = "ovmf"
  description   = "Managed by Terraform"
  boot_order    = null
  machine       = "q35"
  migrate       = false
  name          = "nas"
  node_name     = var.proxmox_node_name
  protection    = false
  scsi_hardware = "virtio-scsi-single"
  started       = true
  tablet_device = false
  tags          = ["terraform", "debian"]
  vm_id         = 100

  lifecycle {
    ignore_changes = [
      mac_addresses,
      on_boot,
      reboot,
      migrate,
      stop_on_destroy,
      timeout_clone,
      timeout_create,
      timeout_migrate,
      timeout_reboot,
      timeout_shutdown_vm,
      timeout_start_vm,
      timeout_stop_vm,
    ]
  }


  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = null
  }

  cpu {
    # affinity     = null
    architecture = "x86_64"
    cores        = 16
    # flags        = []
    # hotplugged   = 0
    # limit        = 0
    # numa         = false
    sockets = 1
    type    = "host"
  }

  // Root disk
  disk {
    backup            = false
    datastore_id      = "local-lvm"
    discard           = "ignore"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "vm-100-disk-1"
    size              = 200
    ssd               = false
  }

  // NFS mounts


  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }

  // Additional attached disks
  dynamic "disk" {
    for_each = {
      for idx, val in var.data_disks : idx => val
    }
    iterator = data_disk
    content {
      backup            = false
      datastore_id      = ""
      discard           = "ignore"
      file_format       = "qcow2"
      interface         = "scsi${data_disk.key + 2}" # +2 for previous setup
      iothread          = false
      path_in_datastore = data_disk.value.path_in_datastore
      replicate         = false
      size              = data_disk.value.size
      ssd               = false
    }
  }

  hostpci {
    device  = "hostpci0"
    id      = "0000:08:00.0"
    mapping = null
    # mdev     = "nvidia-47"
    pcie     = false
    rom_file = null
    rombar   = true
    xvga     = true
  }
  memory {
    dedicated = 22 * 1024
    floating  = 0
    hugepages = null
    shared    = 0
  }
  network_device {
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = true
    mac_address  = "BC:24:11:F4:E4:69"
    model        = "virtio"
  }

  # network_device {
  #   bridge       = "vmbr1"
  #   disconnected = false
  #   enabled      = true
  #   firewall     = false
  #   model        = "virtio"
  #   # vlan_id      = 1
  # }

  operating_system {
    type = "l26"
  }
  serial_device {
    device = "socket"
  }
  vga {
    clipboard = null
    memory    = 16
    type      = "virtio"
  }

}

resource "proxmox_virtual_environment_firewall_rules" "nas_inbound" {

  depends_on = [proxmox_virtual_environment_vm.nas]

  node_name = proxmox_virtual_environment_vm.nas.node_name
  vm_id     = proxmox_virtual_environment_vm.nas.vm_id

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "phpmyadmin (temp)"
    dport   = "9990"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Jellyfin vue"
    dport   = "8099"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Transmission"
    dport   = "51413"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Artemis AIME"
    dport   = "22345"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH"
    dport   = "22"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Plex"
    dport   = "32400"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Adguard DNS"
    dport   = "53"
    proto   = "udp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Portainer"
    dport   = "9000"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Traefik HTTPS"
    dport   = "443"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Traefik HTTP"
    dport   = "80"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "DROP"
    comment = "Block everything"
    log     = "warning"
  }
}
