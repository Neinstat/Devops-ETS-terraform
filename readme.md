# DevOps Project ETS Study Case #2

**Kelompok: 2**   
**Anggota Kelompok:** 
> 1. Muhammad Andrean Rizq Prasetio | 5027231052
> 2. Kevin Anugrah Faza | NRP
> 3. Nama | NRP
> 4.
> 5.
> 6.
> 7.  Tulis nama nrp ges

---

## Daftar Isi
1. [Studi Kasus](#1-studi-kasus)
2. [Overview Arsitektur](#2-overview-arsitektur)
3. [Pembagian Role & Jobdesk](#3-pembagian-role--jobdesk)
4. [IP Address & Cara SSH](#4-ip-address--cara-ssh)
5. [Aturan Firewall (NSG)](#5-aturan-firewall-nsg)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Studi Kasus
**Latar Belakang:** Sebuah perusahaan e-commerce menghadapi masalah kinerja dan skalabilitas pada basis data transaksionalnya yang saat ini berjalan pada satu instance. Selain itu, kurangnya enkripsi data in transit dan tidak adanya prosedur backup otomatis telah meningkatkan risiko keamanan data dan potensi downtime yang berkepanjangan. Anda, sebagai Lead DevOps Engineer, ditugaskan untuk merancang ulang arsitektur basis data agar memiliki high availability, mampu melakukan read/write splitting secara efisien, serta memenuhi standar keamanan industri melalui enkripsi, firewalling, dan otomatisasi pemulihan data.

**Tujuan:** Mahasiswa diharapkan memiliki kompetensi dalam merancang dan mengimplementasikan arsitektur basis data relasional secara highly available, mengamankan komunikasi data menggunakan SSL, mengotomatisasi manajemen akses dan backup, serta mengintegrasikan pemindaian keamanan kontainer dalam alur deployment.

**Arsitektur Sistem**
1. Node ProxySQL: Bertugas sebagai query router untuk mendistribusikan lalu lintas read ke Slave dan lalu lintas tulis write ke Master.
2. 3 Node Database: Terdiri dari 1 Node Master dan 2 Node Slave yang dihubungkan melalui Replikasi Master-Slave.
3. 1 Node Application: Menjalankan aplikasi yang terhubung ke ProxySQL.
4. Semua node berada dalam jaringan terisolasi dengan firewall yang membatasi akses eksternal.

**Spesifikasi & Ketentuan Teknis**
***Tahap 1: Kontainerisasi (Docker)***
1. Buat Dockerfile untuk aplikasi (aplikasi web sederhana yang terhubung ke basis data) dan image untuk ProxySQL.
2. Sebelum di-deploy, semua image Docker harus dipindai terhadap kerentanan menggunakan docker scout.
3. Output yang diharapkan: Bukti screenshot atau log hasil scanning image yang menunjukkan penanganan kerentanan tingkat Critical atau High.

***Tahap 2: Infrastructure as Code (Terraform)***
1. Gunakan Terraform untuk melakukan provisioning secara otomatis ke Azure Cloud Provider.
2. Terraform harus membuat:
a. 1 VM untuk ProxySQL.
b. 3 VM untuk Database Node (Master dan Slave).
c. 1 VM untuk Application Node.
d.  Jaringan yang terisolasi (VPC/Subnet) dan aturan firewall (Security Group) yang hanya mengizinkan lalu lintas antarnode yang diperlukan.
3. Output yang diharapkan: Source code .tf yang terstruktur.

***Tahap 3: Configuration as Code (Ansible)***
1. Susun Ansible Playbook untuk melakukan konfigurasi pada ke-4 VM yang telah di-provisioning oleh Terraform.
2. Tugas Ansible meliputi:
a. Melakukan instalasi dependencies (Docker Engine dan Basis Data MySQL/MariaDB) di node yang relevan.
b. Mengonfigurasi dan memulai replikasi Master-Slave pada Node Database.
c. Menginstal dan mengonfigurasi ProxySQL agar dapat membagi lalu lintas read/write secara otomatis.
d. Mengimplementasikan dan mengonfigurasi sertifikat SSL/TLS untuk koneksi aman antara aplikasi dan ProxySQL/Database.
e. Membuat akses user basis data dengan hak akses least privilege yang spesifik.
f. Mengonfigurasi skrip backup database automation dan menjadwalkannya (cronjob) pada node master.
3. Output yang diharapkan: Playbook dalam format .yaml serta struktur inventory yang dinamis atau terorganisir.

***Nilai Tambahan***
- Implementasi Health Check Database: Gunakan Ansible atau tools lain untuk mengimplementasikan mekanisme health check yang terintegrasi dengan ProxySQL untuk mendeteksi kegagalan Node Master/Slave secara otomatis.
- Zero Downtime Patching: Paparkan dalam laporan mengenai desain arsitektur basis data yang mendukung proses pembaruan (patching) sistem tanpa menyebabkan downtime pada layanan.

## 2. Overview Arsitektur

Infrastruktur project ini menggunakan **3 Virtual Machine** di Microsoft Azure.  
Arsitektur ini berdasarkan arahan dosen: App dan ProxySQL digabung dalam 1 VM agar sesuai dengan batas kuota **6 core** pada akun Azure Student (3 VM × 2 core = 6 core).

```
Internet
    │
    ▼
┌─────────────────────────────────┐
│  VM1 — vm-app-proxy             │  ← IP Publik: 4.193.169.181
│  • Aplikasi Web (FE + BE)       │    IP Privat: 10.0.1.10
│  • ProxySQL (query router)      │
└──────────────┬──────────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌─────────────┐  ┌─────────────┐
│ VM2         │  │ VM3         │
│ Master DB   │  │ Slave DB    │
│ (WRITE)     │  │ (READ)      │
│ 10.0.1.20   │  │ 10.0.1.21   │
└─────────────┘  └─────────────┘
       │                ▲
       └── replikasi ───┘

Semua VM berada dalam Azure VNet 10.0.0.0/16 yang terisolasi
```

### Spesifikasi VM

| VM | Nama Host | Spesifikasi | Isi / Fungsi |
|---|---|---|---|
| VM1 | `vm-app-proxy` | Standard_B2ps_v2 / 2 vCPU / 4GB RAM | Aplikasi Web (Docker) + ProxySQL |
| VM2 | `vm-master-db` | Standard_B2ps_v2 / 2 vCPU / 4GB RAM | MySQL/MariaDB Master (WRITE) + Backup |
| VM3 | `vm-slave-db` | Standard_B2ps_v2 / 2 vCPU / 4GB RAM | MySQL/MariaDB Slave (READ) + Replikasi |

> **Catatan:** SKU seri `B2ps_v2` adalah ARM64 processor. Image OS yang dipakai adalah  
> `Ubuntu 22.04 LTS ARM64` (`22_04-lts-arm64`), bukan yang gen2 biasa.

---

## 3. Pembagian Role & Jobdesk

| Role | Nama | Fokus | VM yang Dipakai |
|---|---|---|---|
| Role 1 | **Andre** | Infrastructure Lead | Terraform (provisioner semua VM) |
| Role 2 | **Nopi** | Container & Security Engineer | VM1 — `vm-app-proxy` |
| Role 3 | **Tarisa** | Database Master & Backup | VM2 — `vm-master-db` |
| Role 4 | **Dave** | Database Slave & HA | VM3 — `vm-slave-db` |
| Role 5 | **Kepin** | ProxySQL & Routing Engineer | VM1 — `vm-app-proxy` |
| Role 6 | **Winda** | Security & Encryption | VM1, VM2, VM3 (semua) |
| Role 7 | **Angel** | Integration, QA & Documentation | Semua VM (testing) |

---

## 4. IP Address & Cara SSH

### Tabel IP Address

| VM | Hostname | IP Privat | IP Publik | Untuk Siapa |
|---|---|---|---|---|
| VM1 | `vm-app-proxy` | `10.0.1.10` | `4.193.169.181` | Nopi, Kepin, Winda, Angel |
| VM2 | `vm-master-db` | `10.0.1.20` |  Tidak ada | Tarisa, Winda |
| VM3 | `vm-slave-db` | `10.0.1.21` |  Tidak ada | Dave, Winda |

### Cara SSH

**VM1** — punya IP publik, bisa langsung diakses:
```bash
ssh azureuser@4.193.169.181
```

**VM2 (Master DB)** — tidak ada IP publik, wajib lewat VM1 sebagai jump host:
```bash
ssh -J azureuser@4.193.169.181 azureuser@10.0.1.20
```

**VM3 (Slave DB)** — tidak ada IP publik, wajib lewat VM1 sebagai jump host:
```bash
ssh -J azureuser@4.193.169.181 azureuser@10.0.1.21
```

>  **Credential SSH** (sama untuk semua VM):  
> - Username: `azureuser`  
> - Password: tanyakan langsung ke **Andre** — tidak dibagikan di dokumen ini

---

## 5. Aturan Firewall (NSG)

Azure Network Security Group sudah dikonfigurasi dengan aturan berikut:

| Port | Protokol | Fungsi | Akses Dari |
|---|---|---|---|
| `22` | TCP | SSH — login ke VM | Mana saja (semua anggota tim) |
| `80` | TCP | HTTP — akses aplikasi web | Mana saja (internet) |
| `443` | TCP | HTTPS — akses aplikasi web (SSL) | Mana saja (internet) |
| `3306` | TCP | MySQL — koneksi database | Hanya dalam VNet `10.0.0.0/16` |
| `6032` | TCP | ProxySQL admin interface | Hanya dalam VNet `10.0.0.0/16` |
| `6033` | TCP | ProxySQL query port (dipakai App) | Hanya dalam VNet `10.0.0.0/16` |
| `*` | `*` | Semua traffic lain |  DIBLOKIR |

> Port 3306, 6032, dan 6033 **tidak bisa diakses dari internet**.  
> Hanya bisa diakses antar VM di dalam VNet. Ini disengaja untuk keamanan.

---

## 6. Troubleshooting

### SSH tidak bisa connect ke VM2 atau VM3
VM2 dan VM3 tidak punya IP publik. Wajib pakai jump host:
```bash
ssh -J azureuser@4.193.169.181 azureuser@10.0.1.20   # VM2
ssh -J azureuser@4.193.169.181 azureuser@10.0.1.21   # VM3
```

### Tidak bisa konek MySQL dari luar VM
Port 3306 hanya bisa diakses dari dalam VNet (`10.0.0.0/16`). Koneksi dari internet akan selalu diblokir NSG. Ini normal dan disengaja.

### Aplikasi tidak bisa konek ke ProxySQL
Gunakan `127.0.0.1:6033` bukan `10.0.1.10:6033`, karena App dan ProxySQL ada di VM yang sama (VM1).

### Perlu rebuild infrastruktur dari awal
Hubungi Andre, lalu jalankan dari folder `terraform/`:
```bash
terraform destroy   # hapus semua resource Azure
terraform apply     # buat ulang dari awal
```

### Lupa IP address
Jalankan dari folder `terraform/`:
```bash
terraform output
```

---
