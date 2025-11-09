#!/bin/sh
set -e

PG_CONFIG_DIR=/etc/pgbouncer
PG_CONFIG_FILE="${PG_CONFIG_DIR}/pgbouncer.ini"
AUTH_FILE="${PG_CONFIG_DIR}/userlist.txt"

# Validate required environment variables
if [ -z "${DB_HOST}" ]; then
  echo "ERROR: DB_HOST environment variable is required"
  exit 1
fi

if [ -z "${DB_USER}" ]; then
  echo "ERROR: DB_USER environment variable is required"
  exit 1
fi

if [ -z "${DB_PASSWORD}" ]; then
  echo "ERROR: DB_PASSWORD environment variable is required"
  exit 1
fi

if [ -z "${DB_NAME}" ]; then
  echo "ERROR: DB_NAME environment variable is required"
  exit 1
fi

# Set defaults
DB_PORT="${DB_PORT:-5432}"
MAX_CLIENT_CONN="${MAX_CLIENT_CONN:-1000}"
POOL_SIZE="${POOL_SIZE:-20}"

echo "Configuring PgBouncer..."
echo "  Database: ${DB_NAME}"
echo "  Host: ${DB_HOST}:${DB_PORT}"
echo "  User: ${DB_USER}"
echo "  Max Client Connections: ${MAX_CLIENT_CONN}"
echo "  Pool Size: ${POOL_SIZE}"

# Create userlist.txt with plain text password
# Format: "username" "password"
# The file is only readable by the postgres user, so plain text is secure
cat > "${AUTH_FILE}" <<EOF
"${DB_USER}" "${DB_PASSWORD}"
EOF

echo "Created authentication file"

# Create pgbouncer.ini
cat > "${PG_CONFIG_FILE}" <<EOF
[databases]
${DB_NAME} = host=${DB_HOST} port=${DB_PORT} dbname=${DB_NAME} user=${DB_USER} pool_size=${POOL_SIZE}

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 5432
auth_type = plain
auth_file = ${AUTH_FILE}
pool_mode = transaction
max_client_conn = ${MAX_CLIENT_CONN}
default_pool_size = ${POOL_SIZE}
ignore_startup_parameters = extra_float_digits
admin_users = ${DB_USER}
EOF

echo "Created PgBouncer configuration (written to ${PG_CONFIG_FILE})"

echo ""
echo "Starting PgBouncer..."
exec "$@"
