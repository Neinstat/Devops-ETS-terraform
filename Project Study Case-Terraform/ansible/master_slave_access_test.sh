#!/usr/bin/env bash

set -euo pipefail

# Script ini membuktikan perbedaan akses antara master dan slave:
# master harus writable, slave harus read-only, dan data uji dihapus lagi.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="${SCRIPT_DIR}/inventory.local.ini"
ENV_FILE="${SCRIPT_DIR}/.env"
ANSIBLE_CONFIG_FILE="${SCRIPT_DIR}/ansible.cfg"
TEST_PRODUCT_NAME="TEST-ACCESS-$(date +%s)"
APP_CONTAINER_NAME="ecommerce-app"

run_step() {
  local title="$1"
  shift
  echo
  echo "============================================================"
  echo "${title}"
  echo "============================================================"
  "$@"
}

extract_last_line() {
  awk 'NF { line=$0 } END { print line }'
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "File .env tidak ditemukan di ${ENV_FILE}" >&2
  exit 1
fi

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  INVENTORY_FILE="${SCRIPT_DIR}/inventory.ini"
fi

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "File inventory.local.ini atau inventory.ini tidak ditemukan di ${SCRIPT_DIR}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

export ANSIBLE_CONFIG="${ANSIBLE_CONFIG_FILE}"

if [[ -z "${DB_APP_PASSWORD:-}" ]]; then
  echo "DB_APP_PASSWORD belum terisi di .env" >&2
  exit 1
fi

if [[ -z "${DB_ROOT_PASSWORD:-}" ]]; then
  echo "DB_ROOT_PASSWORD belum terisi di .env" >&2
  exit 1
fi

run_step "Cek mode read_only di master" \
  ansible master -i "${INVENTORY_FILE}" -m shell -a "mariadb -u root -p'${DB_ROOT_PASSWORD}' -Nse \"SELECT @@hostname, @@global.read_only;\""

MASTER_MODE_OUTPUT="$(ansible master -i "${INVENTORY_FILE}" -m shell -a "mariadb -u root -p'${DB_ROOT_PASSWORD}' -Nse \"SELECT @@hostname, @@global.read_only;\"" | tr -d '\r' | extract_last_line)"
if [[ "${MASTER_MODE_OUTPUT}" != *$'\t0' && "${MASTER_MODE_OUTPUT}" != *" 0" ]]; then
  echo "Master tidak berada pada mode writable. Output: ${MASTER_MODE_OUTPUT}" >&2
  exit 1
fi

run_step "Cek mode read_only di slave" \
  ansible slave -i "${INVENTORY_FILE}" -m shell -a "mariadb -u root -p'${DB_ROOT_PASSWORD}' -Nse \"SELECT @@hostname, @@global.read_only;\""

SLAVE_MODE_OUTPUT="$(ansible slave -i "${INVENTORY_FILE}" -m shell -a "mariadb -u root -p'${DB_ROOT_PASSWORD}' -Nse \"SELECT @@hostname, @@global.read_only;\"" | tr -d '\r' | extract_last_line)"
if [[ "${SLAVE_MODE_OUTPUT}" != *$'\t1' && "${SLAVE_MODE_OUTPUT}" != *" 1" && "${SLAVE_MODE_OUTPUT}" != *$'\tON' && "${SLAVE_MODE_OUTPUT}" != *" ON" && "${SLAVE_MODE_OUTPUT}" != *$'\ton' && "${SLAVE_MODE_OUTPUT}" != *" on" ]]; then
  echo "Slave tidak berada pada mode read-only. Output: ${SLAVE_MODE_OUTPUT}" >&2
  exit 1
fi

run_step "Uji write ke master dengan user aplikasi" \
  ansible app_proxy -i "${INVENTORY_FILE}" -m shell -a "docker exec ${APP_CONTAINER_NAME} node -e \"const mysql=require('mysql2/promise'); (async()=>{ const c=await mysql.createConnection({host:'10.0.1.20',port:3306,user:'app_user',password:'${DB_APP_PASSWORD}',database:'ecommerce'}); await c.execute('INSERT INTO products (name, price, stock) VALUES (?, ?, ?)', ['${TEST_PRODUCT_NAME}', 1, 1]); const [rows]=await c.execute('SELECT id, name FROM products WHERE name = ?', ['${TEST_PRODUCT_NAME}']); console.log(JSON.stringify(rows)); await c.end(); })().catch(e=>{ console.error(e.message); process.exit(1); })\""

MASTER_WRITE_OUTPUT="$(ansible master -i "${INVENTORY_FILE}" -m shell -a "mariadb -u root -p'${DB_ROOT_PASSWORD}' -D ecommerce -Nse \"SELECT COUNT(*) FROM products WHERE name='${TEST_PRODUCT_NAME}';\"" | tr -d '\r' | extract_last_line)"
if [[ "${MASTER_WRITE_OUTPUT}" != "1" ]]; then
  echo "Write ke master tidak menghasilkan data uji yang diharapkan. Output: ${MASTER_WRITE_OUTPUT}" >&2
  exit 1
fi

run_step "Uji write ke slave yang seharusnya ditolak" \
  ansible app_proxy -i "${INVENTORY_FILE}" -m shell -a "docker exec ${APP_CONTAINER_NAME} node -e \"const mysql=require('mysql2/promise'); (async()=>{ const c=await mysql.createConnection({host:'10.0.1.21',port:3306,user:'app_user',password:'${DB_APP_PASSWORD}',database:'ecommerce'}); await c.execute('INSERT INTO products (name, price, stock) VALUES (?, ?, ?)', ['${TEST_PRODUCT_NAME}-SLAVE', 1, 1]); await c.end(); })().catch(e=>{ console.error(e.message); process.exit(1); })\"" || true

SLAVE_WRITE_OUTPUT="$(ansible app_proxy -i "${INVENTORY_FILE}" -m shell -a "docker exec ${APP_CONTAINER_NAME} node -e \"const mysql=require('mysql2/promise'); (async()=>{ const c=await mysql.createConnection({host:'10.0.1.21',port:3306,user:'app_user',password:'${DB_APP_PASSWORD}',database:'ecommerce'}); await c.execute('INSERT INTO products (name, price, stock) VALUES (?, ?, ?)', ['${TEST_PRODUCT_NAME}-SLAVE', 1, 1]); await c.end(); })().catch(e=>{ console.error(e.message); process.exit(1); })\"" 2>&1 || true)"
echo "${SLAVE_WRITE_OUTPUT}"
if [[ "${SLAVE_WRITE_OUTPUT}" != *"read-only"* && "${SLAVE_WRITE_OUTPUT}" != *"ERROR 1290"* && "${SLAVE_WRITE_OUTPUT}" != *"The MariaDB server is running with the --read-only option"* ]]; then
  echo "Write ke slave tidak gagal dengan indikasi read-only yang diharapkan." >&2
  exit 1
fi

run_step "Cleanup data uji di master" \
  ansible master -i "${INVENTORY_FILE}" -m shell -a "mariadb -u root -p'${DB_ROOT_PASSWORD}' -D ecommerce -e \"DELETE FROM products WHERE name='${TEST_PRODUCT_NAME}';\""

echo
echo "Perbedaan akses master/slave terverifikasi:"
echo "- Master writable"
echo "- Slave read-only"
echo "- Write ke slave ditolak"
