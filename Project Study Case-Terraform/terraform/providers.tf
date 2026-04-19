# providers.tf
# ============================================================
# File ini mendaftarkan "plugin" Azure ke Terraform.
# Ibarat: kamu install driver supaya laptop bisa konek ke printer.
# ============================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # Versi minimum plugin Azure yang dipakai
      version = "~> 3.0"
    }
  }
  # Versi minimum Terraform yang diperlukan
  required_version = ">= 1.3.0"
}

# Konfigurasi koneksi ke Azure
# "features {}" wajib ada meski kosong — ini syarat dari plugin Azure
provider "azurerm" {
  features {}
  # subscription_id dibaca dari file terraform.tfvars
  subscription_id = var.subscription_id
}