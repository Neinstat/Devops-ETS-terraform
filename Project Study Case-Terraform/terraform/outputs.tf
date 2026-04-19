# outputs.tf
# ============================================================
# Menampilkan informasi penting setelah infrastruktur selesai dibuat.
# Output ini dibagikan ke seluruh anggota tim.
# ============================================================

output "app_node_public_ip" {
  description = "IP Publik App Node — Bagikan ke Angel (QA) untuk testing"
  value       = azurerm_public_ip.app.ip_address
}

output "app_node_private_ip" {
  description = "IP Privat App Node"
  value       = azurerm_network_interface.app.private_ip_address
}

output "proxysql_private_ip" {
  description = "IP Privat ProxySQL — Bagikan ke Kepin"
  value       = azurerm_network_interface.proxysql.private_ip_address
}

output "master_db_private_ip" {
  description = "IP Privat Master DB — Bagikan ke Tarisa"
  value       = azurerm_network_interface.master_db.private_ip_address
}

output "slave_db1_private_ip" {
  description = "IP Privat Slave DB 1 — Bagikan ke Dave"
  value       = azurerm_network_interface.slave_db1.private_ip_address
}

output "slave_db2_private_ip" {
  description = "IP Privat Slave DB 2 — Bagikan ke Dave"
  value       = azurerm_network_interface.slave_db2.private_ip_address
}

output "ssh_command_app" {
  description = "Perintah SSH untuk masuk ke App Node"
  value       = "ssh azureuser@${azurerm_public_ip.app.ip_address}"
}

output "ringkasan_ip" {
  description = "Ringkasan semua IP untuk dibagikan ke tim"
  value = {
    app_node  = azurerm_public_ip.app.ip_address
    proxysql  = azurerm_network_interface.proxysql.private_ip_address
    master_db = azurerm_network_interface.master_db.private_ip_address
    slave_db1 = azurerm_network_interface.slave_db1.private_ip_address
    slave_db2 = azurerm_network_interface.slave_db2.private_ip_address
  }
}