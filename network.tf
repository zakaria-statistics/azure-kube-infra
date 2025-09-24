resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-kube-lab"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group
}

# =============================  Subnets ============================
resource "azurerm_subnet" "sub1_bastion_kube" {
  name                 = "sub1-bastion-kube"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidrs.sub1_bastion_kube]
}

resource "azurerm_subnet" "sub2_controlplane" {
  name                 = "sub2-controlplane"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidrs.sub2_controlplane]
}

resource "azurerm_subnet" "sub3_workers" {
  name                 = "sub3-workers"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidrs.sub3_workers]
}

resource "azurerm_subnet" "sub4_dbs" {
  name                 = "sub4-dbs"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidrs.sub4_dbs]
}

resource "azurerm_subnet" "sub5_bastion_dbs" {
  name                 = "sub5-bastion-dbs"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidrs.sub5_bastion_dbs]
}

# ========================= NSGs =============================
resource "azurerm_network_security_group" "nsg_sub1" {
  name                = "nsg-sub1-bastion-kube"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "allow-ssh-from-admin-cidr"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-outbound-to-kube-api"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_cidrs.sub2_controlplane
  }
}

resource "azurerm_network_security_group" "nsg_sub2" {
  name                = "nsg-sub2-controlplane"
  location            = var.location
  resource_group_name = var.resource_group

  # Allow API :6443 from Sub1 (kube bastion)
  security_rule {
    name                       = "allow-apiserver-from-sub1"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = var.subnet_cidrs.sub1_bastion_kube
    destination_address_prefix = "*"
  }

  # Allow API from workers (for kubelet)
  security_rule {
    name                       = "allow-apiserver-from-sub3"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = var.subnet_cidrs.sub3_workers
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_sub3" {
  name                = "nsg-sub3-workers"
  location            = var.location
  resource_group_name = var.resource_group

  # Let Azure LB reach NodePorts on workers
  security_rule {
    name                       = "allow-azlb-to-nodeports"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = [var.nodeport_range]
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # NGINX ingress controller health probe (10254)
  security_rule {
    name                       = "allow-azlb-probe-10254"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10254"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow control plane  to kubelet (10250)
  security_rule {
    name                       = "allow-kubelet-from-sub2"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = var.subnet_cidrs.sub2_controlplane
    destination_address_prefix = "*"
  }

  # Allow access to internet (e.g., for image pulls)
  security_rule {
    name                       = "allow-outbound-internet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_network_security_group" "nsg_sub4" {
  name                = "nsg-sub4-dbs"
  location            = var.location
  resource_group_name = var.resource_group
}

# DB rules (22 from sub5; DB ports from sub5 and sub3)
resource "azurerm_network_security_rule" "db_ssh_from_bastiondbs" {
  name                        = "allow-ssh-from-sub5"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.subnet_cidrs.sub5_bastion_dbs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_sub4.name
}

resource "azurerm_network_security_rule" "db_ports_from_bastiondbs" {
  for_each                    = toset(var.db_ports)
  name                        = "allow-db-${each.value}-from-sub5"
  priority                    = 200 + index(var.db_ports, each.value)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(each.value)
  source_address_prefix       = var.subnet_cidrs.sub5_bastion_dbs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_sub4.name
}

resource "azurerm_network_security_rule" "db_ports_from_workers" {
  for_each                    = toset(var.db_ports)
  name                        = "allow-db-${each.value}-from-sub3"
  priority                    = 300 + index(var.db_ports, each.value)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(each.value)
  source_address_prefix       = var.subnet_cidrs.sub3_workers
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_sub4.name
}

resource "azurerm_network_security_group" "nsg_sub5" {
  name                = "nsg-sub5-bastion-dbs"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    name                       = "allow-ssh-from-dba-cidr"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.dba_cidr
    destination_address_prefix = "*"
  }
}

# ========================= Associate NSGs to subnets =============================
resource "azurerm_subnet_network_security_group_association" "a1" {
  subnet_id                 = azurerm_subnet.sub1_bastion_kube.id
  network_security_group_id = azurerm_network_security_group.nsg_sub1.id
}
resource "azurerm_subnet_network_security_group_association" "a2" {
  subnet_id                 = azurerm_subnet.sub2_controlplane.id
  network_security_group_id = azurerm_network_security_group.nsg_sub2.id
}
resource "azurerm_subnet_network_security_group_association" "a3" {
  subnet_id                 = azurerm_subnet.sub3_workers.id
  network_security_group_id = azurerm_network_security_group.nsg_sub3.id
}
resource "azurerm_subnet_network_security_group_association" "a4" {
  subnet_id                 = azurerm_subnet.sub4_dbs.id
  network_security_group_id = azurerm_network_security_group.nsg_sub4.id
}
resource "azurerm_subnet_network_security_group_association" "a5" {
  subnet_id                 = azurerm_subnet.sub5_bastion_dbs.id
  network_security_group_id = azurerm_network_security_group.nsg_sub5.id
}
