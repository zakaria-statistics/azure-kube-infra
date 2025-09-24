output "bastion_kube_public_ip" {
  value = azurerm_public_ip.pip_bastion_kube.ip_address
}
output "bastion_dbs_public_ip" {
  value = azurerm_public_ip.pip_bastion_dbs.ip_address
}
output "cp_private_ips" {
  value = [for n in azurerm_network_interface.nic_cp : n.ip_configuration[0].private_ip_address]
}
output "worker_private_ips" {
  value = [for n in azurerm_network_interface.nic_worker : n.ip_configuration[0].private_ip_address]
}
output "db_private_ips" {
  value = [for n in azurerm_network_interface.nic_db : n.ip_configuration[0].private_ip_address]
}
