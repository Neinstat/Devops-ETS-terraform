# main.tf — ARSITEKTUR BARU: 3 VM
# ============================================================
# VM 1 (vm-app-proxy): App Node + ProxySQL digabung
#   IP Privat : 10.0.1.10
#   IP Publik : Ya (agar bisa diakses dari luar untuk demo)
#
# VM 2 (vm-master-db): Master Database
#   IP Privat : 10.0.1.20
#   IP Publik : Tidak (hanya diakses dari dalam VNet)
#
# VM 3 (vm-slave-db): Slave Database
#   IP Privat : 10.0.1.21
#   IP Publik : Tidak
#
# Total core: 3 VM x 2 core = 6 core (pas dengan limit student)
# ============================================================


# ── 1. RESOURCE GROUP ────────────────────────────────────────
# Wadah pembungkus semua resource Azure di project ini.
# Menghapus Resource Group = menghapus SEMUA isinya sekaligus.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}


# ── 2. VIRTUAL NETWORK ───────────────────────────────────────
# Jaringan privat virtual di Azure.
# Semua VM berada di dalam sini dan bisa saling komunikasi
# menggunakan IP privat tanpa lewat internet.
resource "azurerm_virtual_network" "main" {
  name                = "devops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}


# ── 3. SUBNET ────────────────────────────────────────────────
# Sub-pembagian ruang IP dalam VNet.
# /24 artinya tersedia 254 IP: 10.0.1.1 sampai 10.0.1.254
resource "azurerm_subnet" "main" {
  name                 = "devops-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}


# ── 4. NETWORK SECURITY GROUP (Firewall) ─────────────────────
# Aturan firewall yang berlaku untuk semua VM dalam subnet.
# Prinsip: izinkan yang perlu, blokir sisanya.
resource "azurerm_network_security_group" "main" {
  name                = "devops-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # ── Rule 1: SSH dari luar (untuk kamu login ke VM) ──────────
  # Port 22 adalah port standar SSH.
  # Semua anggota tim butuh SSH ke VM masing-masing.
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── Rule 2: HTTP ke App Node (port 80) ──────────────────────
  # Agar user/tester bisa mengakses aplikasi dari browser.
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

  # ── Rule 3: HTTPS ke App Node (port 443) ────────────────────
  # Winda (Security) akan setup SSL, jadi port 443 perlu dibuka.
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 115
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── Rule 4: MySQL antar node (port 3306) ─────────────────────
  # App → ProxySQL → DB menggunakan port 3306 (MySQL).
  # Dibatasi hanya dari dalam VNet (10.0.0.0/16) saja,
  # tidak bisa diakses langsung dari internet.
  security_rule {
    name                       = "Allow-MySQL-Internal"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  # ── Rule 5: ProxySQL admin & query port ──────────────────────
  # Port 6032 = admin interface ProxySQL (untuk Kepin konfigurasi)
  # Port 6033 = port query yang dipakai App untuk kirim SQL ke ProxySQL
  # Keduanya hanya dari dalam VNet.
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

  # ── Rule 6: Blokir semua traffic lain dari internet ──────────
  # Priority 4000 = dijalankan paling terakhir.
  # Semua yang tidak cocok dengan rule di atas akan diblokir di sini.
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Terapkan NSG ke Subnet — semua VM dalam subnet otomatis kena aturan ini
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}


# ── 5. PUBLIC IP ─────────────────────────────────────────────
# Hanya VM 1 (App+ProxySQL) yang punya IP publik.
# VM 2 dan VM 3 (database) tidak punya IP publik —
# ini penting untuk keamanan, database tidak boleh diakses langsung dari internet.
resource "azurerm_public_ip" "app_proxy" {
  name                = "app-proxy-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"   # IP tidak berubah walau VM direstart
  sku                 = "Standard"
}


# ── 6. NETWORK INTERFACES (NIC) ──────────────────────────────
# Setiap VM butuh 1 NIC (kartu jaringan virtual).
# NIC = penghubung antara VM dan Subnet, sekaligus tempat assign IP.

# NIC VM 1 — App + ProxySQL (punya IP publik)
resource "azurerm_network_interface" "app_proxy" {
  name                = "app-proxy-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "app-proxy-ipconfig"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.app_proxy.id
  }
}

# NIC VM 2 — Master DB (hanya IP privat)
resource "azurerm_network_interface" "master_db" {
  name                = "master-db-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "master-db-ipconfig"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.20"
  }
}

# NIC VM 3 — Slave DB (hanya IP privat)
resource "azurerm_network_interface" "slave_db" {
  name                = "slave-db-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "slave-db-ipconfig"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.21"
  }
}


# ── 7. VIRTUAL MACHINES ───────────────────────────────────────
# Tiga VM dengan Ubuntu 22.04 LTS.
# Semua pakai Standard_B2s (2 core) → total 6 core = pas limit student.

# ── VM 1: App Node + ProxySQL (DIGABUNG) ─────────────────────
# VM ini akan menjalankan:
#   - Aplikasi web (Frontend + Backend) dalam Docker container
#   - ProxySQL untuk routing query read/write ke database
# Nopi akan setup Docker di sini, Kepin akan setup ProxySQL di sini.
resource "azurerm_linux_virtual_machine" "app_proxy" {
  name                            = "vm-app-proxy"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.app_proxy.id]

  os_disk {
    name                 = "app-proxy-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # 50GB — lebih besar karena akan menyimpan Docker images
    disk_size_gb         = 50
  }

# BARU — ARM64, kompatibel dengan Standard_B2ps_v2
source_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-arm64"
  version   = "latest"
}

  tags = {
    role        = "app-proxysql"
    project     = "devops-ecommerce"
    penanggung  = "Nopi-dan-Kepin"
  }
}

# ── VM 2: Master Database ─────────────────────────────────────
# VM ini akan menjalankan MySQL/MariaDB sebagai Master.
# Semua operasi WRITE (INSERT, UPDATE, DELETE) diarahkan ke sini.
# Tarisa (Database Master) akan konfigurasi VM ini.
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
    name                 = "master-db-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # 50GB untuk data database
    disk_size_gb         = 50
  }

# BARU — ARM64, kompatibel dengan Standard_B2ps_v2
source_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-arm64"
  version   = "latest"
}

  tags = {
    role       = "master-db"
    project    = "devops-ecommerce"
    penanggung = "Tarisa"
  }
}

# ── VM 3: Slave Database ──────────────────────────────────────
# VM ini menjalankan MySQL/MariaDB sebagai Slave.
# Data dari Master otomatis direplikasi ke sini.
# Semua operasi READ (SELECT) diarahkan ke sini oleh ProxySQL.
# Dave (Slave DB) akan konfigurasi VM ini.
resource "azurerm_linux_virtual_machine" "slave_db" {
  name                            = "vm-slave-db"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.slave_db.id]

  os_disk {
    name                 = "slave-db-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 50
  }

# BARU — ARM64, kompatibel dengan Standard_B2ps_v2
source_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-arm64"
  version   = "latest"
}

  tags = {
    role       = "slave-db"
    project    = "devops-ecommerce"
    penanggung = "Dave"
  }
}