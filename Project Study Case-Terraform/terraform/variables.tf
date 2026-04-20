# variables.tf
# ============================================================
# Mendefinisikan semua variabel yang bisa dikustomisasi.
# Anggap ini seperti "daftar isian formulir" — bentuknya ada di sini,
# tapi isinya diisi di terraform.tfvars.
# ============================================================

variable "subscription_id" {
  description = "Azure Subscription ID kamu"
  type        = string
}

variable "resource_group_name" {
  description = "Nama resource group Azure"
  type        = string
  default     = "devops-ecommerce-rg"
}

variable "location" {
  description = "Region Azure — Southeast Asia = Singapore"
  type        = string
  default     = "southeastasia"
}

variable "admin_username" {
  description = "Username untuk SSH ke semua VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Password SSH semua VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Ukuran VM — 2 core agar tersedia di Azure Student"
  type        = string
  # Standard_B2s = 2 vCPU, 4GB RAM
  # 3 VM x 2 core = 6 core = pas dengan limit student
  default     = "Standard_B2s"
}