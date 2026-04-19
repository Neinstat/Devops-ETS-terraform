# main.tf
# ============================================================
# File utama infrastruktur. Urutan pembuatan resource:
# 1. Resource Group (folder pembungkus)
# 2. Virtual Network + Subnet (jaringan virtual)
# 3. Network Security Group (firewall rules)
# 4. Public IP (hanya untuk App Node)
# 5. Network Interface (kartu jaringan virtual tiap VM)
# 6. 5 Virtual Machine
# ============================================================


# ── 1. RESOURCE GROUP ────────────────────────────────────────
# Resource Group = "folder" di Azure yang menampung semua resource.
# Memudahkan pengelolaan dan penghapusan (hapus RG = hapus semua isinya).
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}


# ── 2. VIRTUAL NETWORK (VNet) ────────────────────────────────
# VNet = jaringan virtual privat di Azure.
# Semua VM akan berada di dalam VNet ini → terisolasi dari internet.
# 10.0.0.0/16 = range IP privat yang tersedia: 10.0.0.0 – 10.0.255.255
resource "azurerm_virtual_network" "main" {
  name                = "devops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}


# ── 3. SUBNET ────────────────────────────────────────────────
# Subnet = pembagian ruang IP di dalam VNet.
# Kita pakai 1 subnet untuk semua VM agar semua bisa saling berkomunikasi.
# 10.0.1.0/24 = range: 10.0.1.0 – 10.0.1.255 (254 IP tersedia)
resource "azurerm_subnet" "main" {
  name                 = "devops-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}


# ── 4. NETWORK SECURITY GROUP (NSG) ──────────────────────────
# NSG = firewall di Azure. Mengontrol traffic masuk dan keluar.
# Kita buat aturan: hanya traffic tertentu yang diizinkan antar node.
resource "azurerm_network_security_group" "main" {
  name                = "devops-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # ── Aturan 1: SSH dari luar (untuk admin/kamu login ke VM) ──
  # Port 22 = port standar SSH
  # Hanya izinkan dari IP laptop kamu saja (lebih aman)
  # Untuk development, kita buka dari mana saja dulu (*)
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100        # Angka kecil = prioritas lebih tinggi
    direction                  = "Inbound"  # Traffic masuk
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"        # Biarkan * agar bisa diakses semua orang/tim
    destination_address_prefix = "*"
  }

  # ── Aturan 2: HTTP dari internet ke App Node ──
  # Port 80 = HTTP, untuk akses aplikasi web
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── Aturan 3: MySQL antar node dalam VNet ──
  # Port 3306 = MySQL/MariaDB
  # Hanya dari dalam VNet (10.0.0.0/16), bukan dari internet
  security_rule {
    name                       = "Allow-MySQL-Internal"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.0.0.0/16"  # Hanya dari dalam VNet
    destination_address_prefix = "*"
  }

  # ── Aturan 4: ProxySQL port (6032 = admin, 6033 = query) ──
  security_rule {
    name                       = "Allow-ProxySQL-Internal"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6032-6033"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  # ── Aturan 5: Blokir semua traffic lain dari internet ──
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000       # Prioritas terendah = dijalankan terakhir
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Hubungkan NSG ke Subnet (terapkan firewall ke semua VM di subnet)
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}


# ── 5. PUBLIC IP (hanya untuk App Node) ──────────────────────
# Hanya App Node yang punya IP publik — supaya user bisa akses aplikasi.
# Node lain (ProxySQL, DB) tidak punya IP publik = lebih aman.
resource "azurerm_public_ip" "app" {
  name                = "app-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"   # IP tidak berubah-ubah
  sku                 = "Standard"
}


# ── 6. NETWORK INTERFACES (NIC) ──────────────────────────────
# NIC = kartu jaringan virtual. Setiap VM butuh 1 NIC.
# NIC menghubungkan VM ke Subnet dan memberikan IP privat.

# NIC untuk App Node (dengan IP publik)
resource "azurerm_network_interface" "app" {
  name                = "app-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "app-ip-config"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"   # IP privat tetap untuk App Node
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

# NIC untuk ProxySQL Node (hanya IP privat)
resource "azurerm_network_interface" "proxysql" {
  name                = "proxysql-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "proxysql-ip-config"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.20"   # IP privat tetap untuk ProxySQL
  }
}

# NIC untuk Master DB Node
resource "azurerm_network_interface" "master_db" {
  name                = "master-db-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "master-db-ip-config"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.30"   # IP privat untuk Master DB
  }
}

# NIC untuk Slave DB 1
resource "azurerm_network_interface" "slave_db1" {
  name                = "slave-db1-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "slave-db1-ip-config"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.31"
  }
}

# NIC untuk Slave DB 2
resource "azurerm_network_interface" "slave_db2" {
  name                = "slave-db2-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "slave-db2-ip-config"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.32"
  }
}


# ── 7. VIRTUAL MACHINES ───────────────────────────────────────
# Sekarang buat 5 VM. Semuanya pakai Ubuntu 22.04 LTS.

# ── VM 1: App Node ──
resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-app-node"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false  # Izinkan login pakai password

  # Hubungkan VM ke NIC yang sudah dibuat
  network_interface_ids = [azurerm_network_interface.app.id]

  # Spesifikasi OS Disk (storage untuk OS)
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  # HDD standar, lebih murah
  }

  # Image OS yang dipakai: Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    role = "app-node"
    project = "devops-ecommerce"
  }
}

# ── VM 2: ProxySQL Node ──
resource "azurerm_linux_virtual_machine" "proxysql" {
  name                            = "vm-proxysql-node"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.proxysql.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    role = "proxysql-node"
    project = "devops-ecommerce"
  }
}

# ── VM 3: Master DB Node ──
resource "azurerm_linux_virtual_machine" "master_db" {
  name                            = "vm-master-db"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.master_db.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    role = "master-db"
    project = "devops-ecommerce"
  }
}

# ── VM 4: Slave DB 1 ──
resource "azurerm_linux_virtual_machine" "slave_db1" {
  name                            = "vm-slave-db1"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.slave_db1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    role = "slave-db-1"
    project = "devops-ecommerce"
  }
}

# ── VM 5: Slave DB 2 ──
resource "azurerm_linux_virtual_machine" "slave_db2" {
  name                            = "vm-slave-db2"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.slave_db2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    role = "slave-db-2"
    project = "devops-ecommerce"
  }
}