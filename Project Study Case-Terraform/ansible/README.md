# Ansible Usage

This folder contains shared playbooks and automation for the Azure study case.

## Local Setup

1. Copy `.env.example` to `.env` and fill the real passwords.
2. Copy `inventory.local.example.ini` to `inventory.local.ini`.
3. Run Ansible from WSL/Linux so `ansible.cfg` is honored consistently.

## ProxySQL

Render the ProxySQL configuration for VM1:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini proxysql.yml
```

Deploy the managed ProxySQL container after the config has been rendered:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini proxysql_runtime.yml
```

Deploy the existing app container with the managed DB connection environment:

```bash
set -a
source .env
set +a
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.local.ini app_runtime_integration.yml
```

Validate connectivity to VM1 before running the playbook:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible app_proxy -i inventory.local.ini -m ping
```
