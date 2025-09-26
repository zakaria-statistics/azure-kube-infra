# Public IPs for bastions
resource "azurerm_public_ip" "pip_bastion_kube" {
  name                = "pip-bastion-kube"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "pip_bastion_dbs" {
  name                = "pip-bastion-dbs"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NICs
resource "azurerm_network_interface" "nic_bastion_kube" {
  name                = "nic-bastion-kube"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub1_bastion_kube.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_bastion_kube.id
  }
}

resource "azurerm_network_interface" "nic_bastion_dbs" {
  name                = "nic-bastion-dbs"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub5_bastion_dbs.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_bastion_dbs.id
  }
}

resource "azurerm_network_interface" "nic_cp" {
  count               = var.cp_count
  name                = "nic-cp-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub2_controlplane.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic_worker" {
  count               = var.worker_count
  name                = "nic-worker-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub3_workers.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic_db" {
  count               = var.db_count
  name                = "nic-db-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.sub4_dbs.id
    private_ip_address_allocation = "Dynamic"
  }
}

# VMs
resource "azurerm_linux_virtual_machine" "vm_bastion_kube" {
  name                  = "vm-bastion-kube"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size_bastion
  network_interface_ids = [azurerm_network_interface.nic_bastion_kube.id]

  # required auth at provision time
  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = local.effective_ssh_pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/bastion-k8s.yml", {
    hostname    = "bastion-kube"
    username    = var.admin_username
    ssh_pubkey  = local.effective_ssh_pubkey
    ssh_privkey = indent(6, trimspace(local.effective_ssh_privkey))
  }))
}

resource "azurerm_linux_virtual_machine" "vm_bastion_dbs" {
  name                  = "vm-bastion-dbs"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size_bastion
  network_interface_ids = [azurerm_network_interface.nic_bastion_dbs.id]

  # required auth at provision time
  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = local.effective_ssh_pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(
    templatefile("${path.module}/cloud-init/db-bastion.yml", {
      hostname   = "bastion-dbs"
      username   = var.admin_username
      ssh_pubkey = local.effective_ssh_pubkey
      # keep PEM formatting: trim, then indent by 6 spaces to align under "content: |"
      ssh_privkey = indent(6, trimspace(local.effective_ssh_privkey))
  }))
}


resource "azurerm_linux_virtual_machine" "vm_cp" {
  count                 = var.cp_count
  name                  = "vm-cp-${count.index}"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size_cp
  network_interface_ids = [azurerm_network_interface.nic_cp[count.index].id]

  # required auth at provision time
  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = local.effective_ssh_pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/k8s.yml", {
    hostname   = format("cp-%02d", count.index)
    username   = var.admin_username
    ssh_pubkey = local.effective_ssh_pubkey
  }))
}

resource "azurerm_linux_virtual_machine" "vm_worker" {
  count                 = var.worker_count
  name                  = "vm-worker-${count.index}"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size_worker
  network_interface_ids = [azurerm_network_interface.nic_worker[count.index].id]

  # required auth at provision time
  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = local.effective_ssh_pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/k8s.yml", {
    hostname   = format("worker-%02d", count.index)
    username   = var.admin_username
    ssh_pubkey = local.effective_ssh_pubkey
  }))
}

resource "azurerm_linux_virtual_machine" "vm_db" {
  count                 = var.db_count
  name                  = "vm-db-${count.index}"
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size_db
  network_interface_ids = [azurerm_network_interface.nic_db[count.index].id]

  # required auth at provision time
  admin_username                  = var.admin_username
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = local.effective_ssh_pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/db-vm.yml", {
    hostname   = format("db-%02d", count.index)
    username   = var.admin_username
    ssh_pubkey = local.effective_ssh_pubkey
  }))
}
