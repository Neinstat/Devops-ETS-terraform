# variables.tf
# ============================================================
# Mendefinisikan semua variabel yang bisa dikustomisasi.
# Anggap ini seperti "daftar isian formulir" — bentuknya ada di sini,
# tapi isinya diisi di terraform.tfvars.
# ============================================================

variable "subscription_id" {
  description = "Azure Subscription ID kamu"
  type        = string
  # Tidak ada default — wajib diisi di tfvars
}

variable "resource_group_name" {
  description = "Nama resource group di Azure (folder pembungkus semua resource)"
  type        = string
  default     = "devops-ecommerce-rg"
}

variable "location" {
  description = "Region Azure tempat VM dibuat"
  type        = string
  # Southeast Asia = Singapore, terdekat dari Indonesia
  default     = "southeastasia"
}

variable "admin_username" {
  description = "Username untuk login ke semua VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Password untuk login ke semua VM"
  type        = string
  sensitive   = true  # Terraform tidak akan print nilai ini ke terminal
}

variable "vm_size" {
  description = "Ukuran/spesifikasi VM (CPU, RAM)"
  type        = string
  # Standard_B1s = 1 vCPU, 1GB RAM — cukup untuk project, hemat biaya
  default     = "Standard_B1s"
}