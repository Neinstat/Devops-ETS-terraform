#!/usr/bin/env bash

set -euo pipefail

# Script ini menjalankan rangkaian tes utama untuk database slave dan ProxySQL
# Jalankan dari WSL agar Ansible dan curl memakai path Linux.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/inventory.local.ini"
ENV_FILE="${SCRIPT_DIR}/.env"
ANSIBLE_CONFIG_FILE="${SCRIPT_DIR}/ansible.cfg"
PUBLIC_APP_URL="${PUBLIC_APP_URL:-http://4.193.169.181}"

run_step() {
  local title="$1"
  shift
  echo
  echo "============================================================"
  echo "${title}"
  echo "============================================================"
  "$@"
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File .env tidak ditemukan di ${ENV_FILE}" >&2
  exit 1
fi

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "File inventory.local.ini tidak ditemukan di ${INVENTORY_FILE}" >&2
  exit 1
fi

# Export semua variabel dari .env agar lookup('env', ...) di Ansible tetap bekerja.
set -a
source "${ENV_FILE}"
set +a

export ANSIBLE_CONFIG="${ANSIBLE_CONFIG_FILE}"

run_step "Cek konektivitas Ansible ke VM1" \
  ansible app_proxy -i "${INVENTORY_FILE}" -m ping

run_step "Cek konektivitas Ansible ke VM3" \
  ansible slave -i "${INVENTORY_FILE}" -m ping

run_step "Verifikasi topology non-destruktif" \
  ansible-playbook -i "${INVENTORY_FILE}" "${SCRIPT_DIR}/verify_topology.yml"

run_step "Uji end-to-end topology" \
  ansible-playbook -i "${INVENTORY_FILE}" "${SCRIPT_DIR}/topology_test.yml"

run_step "Cek endpoint /health" \
  curl -sS "${PUBLIC_APP_URL}/health"

echo

run_step "Cek endpoint /products" \
  curl -sS "${PUBLIC_APP_URL}/products"

echo

run_step "Cek distribusi query baca lewat ProxySQL" \
  ansible app_proxy -i "${INVENTORY_FILE}" -a 'docker exec ecommerce-app node -e "const mysql=require(\"mysql2/promise\"); (async()=>{ const result={}; for (let i=0; i<20; i++) { const c=await mysql.createConnection({host:process.env.DB_HOST,port:Number(process.env.DB_PORT),user:process.env.DB_USER,password:process.env.DB_PASSWORD,database:process.env.DB_NAME}); const [rows]=await c.query(\"SELECT @@hostname AS host, @@global.read_only AS global_ro\"); const key=String(rows[0].host)+\"|ro=\"+String(rows[0].global_ro); result[key]=(result[key]||0)+1; await c.end(); } console.log(JSON.stringify(result,null,2)); })().catch(e=>{ console.error(e.message); process.exit(1); })"'

echo
echo "Semua tes topology selesai."
