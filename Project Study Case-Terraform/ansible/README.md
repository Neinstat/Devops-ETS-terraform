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

Validasi konektivitas ke VM1 sebelum menjalankan playbook:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible app_proxy -i inventory.local.ini -m ping
```
