# outputs.tf
# ============================================================
# Menampilkan informasi penting setelah infrastruktur selesai dibuat.
# Output ini dibagikan ke seluruh anggota tim.
# ============================================================

# outputs.tf — Disesuaikan dengan 3 VM baru

output "vm1_app_proxy_public_ip" {
  description = "IP Publik VM1 (App+ProxySQL) — untuk akses dari browser & SSH"
  value       = azurerm_public_ip.app_proxy.ip_address
}

output "vm1_app_proxy_private_ip" {
  description = "IP Privat VM1 (App+ProxySQL)"
  value       = azurerm_network_interface.app_proxy.private_ip_address
}

output "vm2_master_db_private_ip" {
  description = "IP Privat VM2 (Master DB) — bagikan ke Tarisa"
  value       = azurerm_network_interface.master_db.private_ip_address
}

output "vm3_slave_db_private_ip" {
  description = "IP Privat VM3 (Slave DB) — bagikan ke Dave"
  value       = azurerm_network_interface.slave_db.private_ip_address
}

output "ssh_ke_vm1" {
  description = "Perintah SSH untuk masuk ke VM1 (App+ProxySQL)"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.app_proxy.ip_address}"
}

output "ssh_ke_vm2_via_vm1" {
  description = "SSH ke VM2 Master DB — harus lewat VM1 dulu (jump host)"
  value       = "ssh -J ${var.admin_username}@${azurerm_public_ip.app_proxy.ip_address} ${var.admin_username}@${azurerm_network_interface.master_db.private_ip_address}"
}

output "ssh_ke_vm3_via_vm1" {
  description = "SSH ke VM3 Slave DB — harus lewat VM1 dulu (jump host)"
  value       = "ssh -J ${var.admin_username}@${azurerm_public_ip.app_proxy.ip_address} ${var.admin_username}@${azurerm_network_interface.slave_db.private_ip_address}"
}

output "ringkasan_ip_untuk_tim" {
  description = "Ringkasan semua IP — copy dan bagikan ke seluruh tim"
  value = {
    "VM1_App_ProxySQL_PublicIP"  = azurerm_public_ip.app_proxy.ip_address
    "VM1_App_ProxySQL_PrivateIP" = azurerm_network_interface.app_proxy.private_ip_address
    "VM2_MasterDB_PrivateIP"     = azurerm_network_interface.master_db.private_ip_address
    "VM3_SlaveDB_PrivateIP"      = azurerm_network_interface.slave_db.private_ip_address
  }
}