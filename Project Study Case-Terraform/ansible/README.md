# Penggunaan Ansible

Folder ini berisi playbook dan automation bersama untuk studi kasus Azure.

## Setup Lokal

1. Salin `.env.example` menjadi `.env` lalu isi password yang benar.
2. Salin `inventory.local.example.ini` menjadi `inventory.local.ini`.
3. Jalankan Ansible dari WSL/Linux agar `ansible.cfg` terbaca konsisten.

## ProxySQL

Render konfigurasi ProxySQL untuk VM1:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini proxysql.yml
```

Deploy container ProxySQL terkelola setelah konfigurasi berhasil dirender:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini proxysql_runtime.yml
```

Deploy ulang container app yang ada dengan environment koneksi DB terkelola:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini app_runtime_integration.yml
```

Inisialisasi schema aplikasi dan seed data produk contoh di database master:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini app_schema.yml
```

Konfigurasi MariaDB slave, sinkronisasi data awal dari master bila slave belum siap, lalu aktifkan replikasi:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini db_slave.yml
```

`db_slave.yml` sekarang aman untuk rerun normal:
- bila slave sehat dan tabel aplikasi sudah ada, playbook hanya memverifikasi state penting seperti user DB, `read_only`, dan status replikasi
- reseed dari master hanya dilakukan saat bootstrap awal atau saat slave memang belum siap

Verifikasi topology database dan ProxySQL dalam satu playbook:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini verify_topology.yml
```

Playbook ini memeriksa:
- kesehatan replikasi slave
- status `read_only` dan data aplikasi di slave
- kesehatan endpoint `/health` dan `/products`
- koneksi langsung aplikasi ke slave
- jalur baca lewat ProxySQL benar-benar mencapai slave

Uji end-to-end yang lebih menyeluruh untuk topology database dan ProxySQL:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini topology_test.yml
```

Playbook ini akan:
- menjalankan verifikasi topology dasar lebih dulu
- membuat produk uji sementara lewat endpoint aplikasi
- memastikan data uji tereplikasi ke slave
- memastikan aplikasi bisa membaca data uji langsung dari slave
- membersihkan lagi data uji dari master dan slave setelah test selesai

Validasi konektivitas ke VM1 sebelum menjalankan playbook:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible app_proxy -i inventory.local.ini -m ping
```
