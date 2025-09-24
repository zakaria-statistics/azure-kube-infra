# variables.tf
variable "subscription_id" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "tenant_id" {
  type = string
}
variable "prefix" { type = string }
variable "location" {
  type = string
}
variable "resource_group" {
  type = string
}
variable "location" { default = "westeurope" }
variable "vnet_cidr" { default = "10.20.0.0/16" }

# Subnets (change if you like)
variable "subnet_cidrs" {
  type = object({
    sub1_bastion_kube = string
    sub2_controlplane = string
    sub3_workers      = string
    sub4_dbs          = string
    sub5_bastion_dbs  = string
  })
  default = {
    sub1_bastion_kube = "10.20.1.0/24"
    sub2_controlplane = "10.20.2.0/24"
    sub3_workers      = "10.20.3.0/24"
    sub4_dbs          = "10.20.4.0/24"
    sub5_bastion_dbs  = "10.20.5.0/24"
  }
}

# Access / ports
variable "admin_cidr" {
  description = "CIDR allowed to SSH to kube bastion"
  default     = "172.16.10.0/24"
}
variable "dba_cidr" {
  description = "CIDR allowed to SSH to DB bastion"
  default     = "172.16.20.0/24"
}
variable "db_ports" {
  description = "DB ports to allow from bastion/workers"
  type        = list(number)
  default     = [5432, 3306]
}
variable "nodeport_range" {
  description = "K8s NodePort range used by Ingress LB"
  default     = "30000-32767"
}

# Compute
variable "admin_username" { default = "azureuser" }
variable "ssh_public_key" {
  description = "Your SSH public key"
  type        = string
}

variable "cp_count" { default = 1 }
variable "worker_count" { default = 2 }
variable "db_count" { default = 2 }

# Sizes
variable "vm_size_bastion" { default = "Standard_B1ms" }
variable "vm_size_cp" { default = "Standard_B2s" }
variable "vm_size_worker" { default = "Standard_B2s" }
variable "vm_size_db" { default = "Standard_B2ms" }

