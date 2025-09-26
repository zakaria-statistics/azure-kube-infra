data "vault_kv_secret_v2" "ssh_key" {
  mount = var.vault_kv_mount
  name  = var.vault_ssh_path
}

locals {
  # ssh public key
  ssh_pubkey_from_vault = try(data.vault_kv_secret_v2.ssh_key.data["public_key"], null)
  effective_ssh_pubkey  = coalesce(local.ssh_pubkey_from_vault, var.ssh_public_key)
  # ssh private key
  ssh_privkey_from_vault = try(data.vault_kv_secret_v2.ssh_key.data["private_key"], null)
  effective_ssh_privkey  = coalesce(local.ssh_privkey_from_vault, var.ssh_private_key)
}

