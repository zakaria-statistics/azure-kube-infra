# variables.tf
# variable "subscription_id" {
#   type = string
# }
# variable "client_id" {
#   type = string
# }
# variable "client_secret" {
#   type      = string
#   sensitive = true
# }
# variable "tenant_id" {
#   type = string
# }


variable "location" {
  type = string
}
variable "resource_group" {
  type = string
}


variable "vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
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
  #default     = "196.115.99.85/32"
  default = "0.0.0.0/0"
}
variable "dba_cidr" {
  description = "CIDR allowed to SSH to DB bastion"
  #default     = "196.115.99.85/32"
  default = "0.0.0.0/0"
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
variable "admin_username" {
  default = "azureuser"
}
variable "ssh_public_key" {
  type    = string
  default = null
}

variable "ssh_private_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "cp_count" { default = 1 }
variable "worker_count" { default = 2 }
variable "db_count" { default = 2 }

# Sizes
variable "vm_size_bastion" { default = "Standard_B1ms" }
variable "vm_size_cp" { default = "Standard_A2_v2" }
variable "vm_size_worker" { default = "Standard_A2_v2" }
variable "vm_size_db" { default = "Standard_B2ms" }


# ================= Vault =================
variable "vault_addr" {
  type = string
}
variable "vault_role_id" {
  type = string
}
variable "vault_secret_id" {
  type      = string
  sensitive = true
}

variable "vault_kv_mount" { default = "kv" }
variable "vault_ssh_path" { default = "cloud/ssh/kube" }

