#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y postgresql
fi

# Values are injected by Terraform templatefile.
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"

sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${DB_USER}', '${DB_PASSWORD}');
  END IF;

  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I', '${DB_NAME}', '${DB_USER}');
  END IF;
END
$$;
SQL

# Allow app subnet access (security group still applies).
PG_HBA="/etc/postgresql/$(ls /etc/postgresql | head -n1)/main/pg_hba.conf"
PG_CONF="/etc/postgresql/$(ls /etc/postgresql | head -n1)/main/postgresql.conf"

if ! grep -q "${APP_CIDR}" "$PG_HBA"; then
  echo "host all all ${APP_CIDR} md5" >>"$PG_HBA"
fi

sed -i.bak "s/^#\?listen_addresses\s*=.*/listen_addresses = '*'/" "$PG_CONF"
systemctl restart postgresql
