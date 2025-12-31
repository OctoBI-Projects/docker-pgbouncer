#!/bin/sh
set -e

PG_CONFIG_DIR=/etc/pgbouncer
PG_CONFIG_FILE="${PG_CONFIG_DIR}/pgbouncer.ini"
AUTH_FILE="${PG_CONFIG_DIR}/userlist.txt"

# =============================================================================
# ENVIRONMENT VARIABLES DOCUMENTATION
# =============================================================================
#
# REQUIRED:
# ---------
# DB_HOST                   - RDS cluster endpoint hostname
# AUTH_USER                 - PostgreSQL user for auth_query (must have SELECT on pg_shadow)
# AUTH_PASSWORD             - Password for AUTH_USER
#
# OPTIONAL - Connection:
# ----------------------
# DB_PORT                   - PostgreSQL port (default: 5432)
# SERVER_TLS_SSLMODE        - TLS mode for backend connections: disable|allow|prefer|require|verify-ca|verify-full
#                             (default: require)
# AUTH_DBNAME               - Database to connect for auth_query (default: postgres)
# AUTH_QUERY                - SQL query to authenticate users (default: SELECT usename, passwd FROM pg_shadow WHERE usename = $1)
#                             (for RDS/Aurora you will need to maintain a custom table with all username/passwords and query from there)
#
# OPTIONAL - Pooling:
# -------------------
# POOL_MODE                 - Pooling mode: session|transaction|statement (default: transaction)
# DEFAULT_POOL_SIZE         - Server connections per user/database pair (default: 20)
# MIN_POOL_SIZE             - Minimum server connections to keep open (default: 5)
# RESERVE_POOL_SIZE         - Extra connections for burst traffic (default: 5)
# RESERVE_POOL_TIMEOUT      - Seconds before using reserve pool (default: 3)
# MAX_DB_CONNECTIONS        - Max connections per database (default: 100)
# MAX_USER_CONNECTIONS      - Max connections per user (default: 100)
#
# OPTIONAL - Client Limits:
# -------------------------
# MAX_CLIENT_CONN           - Maximum client connections allowed (default: 1000)
# MAX_PREPARED_STATEMENTS   - Prepared statements per client, 0 to disable (default: 200)
#
# OPTIONAL - Timeouts:
# --------------------
# CLIENT_IDLE_TIMEOUT       - Seconds before closing idle client connection (default: 0 = disabled)
# CLIENT_LOGIN_TIMEOUT      - Seconds to wait for client auth (default: 60)
# SERVER_CONNECT_TIMEOUT    - Seconds to wait for server connection (default: 15)
# SERVER_IDLE_TIMEOUT       - Seconds before closing idle server connection (default: 600)
# SERVER_LIFETIME           - Max seconds a server connection can live (default: 3600)
# QUERY_TIMEOUT             - Max seconds a query can run, 0 = disabled (default: 0)
# QUERY_WAIT_TIMEOUT        - Max seconds client waits for server connection (default: 120)
#
# OPTIONAL - Logging:
# -------------------
# LOG_CONNECTIONS           - Log successful connections: 0|1 (default: 0)
# LOG_DISCONNECTIONS        - Log disconnections with reason: 0|1 (default: 0)
# LOG_POOLER_ERRORS         - Log pooler errors: 0|1 (default: 1)
# LOG_STATS                 - Log stats periodically: 0|1 (default: 1)
# STATS_PERIOD              - Seconds between stats logging (default: 60)
# VERBOSE                   - Verbosity level 0-2 (default: 0)
#
# OPTIONAL - Admin:
# -----------------
# ADMIN_USERS               - Comma-separated admin users (default: AUTH_USER)
# STATS_USERS               - Comma-separated users who can view stats (default: AUTH_USER)
#
# =============================================================================

# --- Validate required environment variables ---
missing_vars=""

if [ -z "${DB_HOST}" ]; then
  missing_vars="${missing_vars} DB_HOST"
fi

if [ -z "${AUTH_USER}" ]; then
  missing_vars="${missing_vars} AUTH_USER"
fi

if [ -z "${AUTH_PASSWORD}" ]; then
  missing_vars="${missing_vars} AUTH_PASSWORD"
fi

if [ -n "${missing_vars}" ]; then
  echo "ERROR: Missing required environment variables:${missing_vars}"
  echo ""
  echo "Required variables:"
  echo "  DB_HOST        - RDS cluster endpoint"
  echo "  AUTH_USER      - PostgreSQL user for authentication queries"
  echo "  AUTH_PASSWORD  - Password for AUTH_USER"
  exit 1
fi

# --- Set defaults ---

# Connection
DB_PORT="${DB_PORT:-5432}"
SERVER_TLS_SSLMODE="${SERVER_TLS_SSLMODE:-require}"
AUTH_DBNAME="${AUTH_DBNAME:-postgres}"
AUTH_QUERY="${AUTH_QUERY:-SELECT usename, passwd FROM pg_shadow WHERE usename = \$1}"

# Pooling
POOL_MODE="${POOL_MODE:-transaction}"
DEFAULT_POOL_SIZE="${DEFAULT_POOL_SIZE:-20}"
MIN_POOL_SIZE="${MIN_POOL_SIZE:-5}"
RESERVE_POOL_SIZE="${RESERVE_POOL_SIZE:-5}"
RESERVE_POOL_TIMEOUT="${RESERVE_POOL_TIMEOUT:-3}"
MAX_DB_CONNECTIONS="${MAX_DB_CONNECTIONS:-100}"
MAX_USER_CONNECTIONS="${MAX_USER_CONNECTIONS:-100}"

# Client limits
MAX_CLIENT_CONN="${MAX_CLIENT_CONN:-1000}"
MAX_PREPARED_STATEMENTS="${MAX_PREPARED_STATEMENTS:-200}"

# Timeouts
CLIENT_IDLE_TIMEOUT="${CLIENT_IDLE_TIMEOUT:-0}"
CLIENT_LOGIN_TIMEOUT="${CLIENT_LOGIN_TIMEOUT:-60}"
SERVER_CONNECT_TIMEOUT="${SERVER_CONNECT_TIMEOUT:-15}"
SERVER_IDLE_TIMEOUT="${SERVER_IDLE_TIMEOUT:-600}"
SERVER_LIFETIME="${SERVER_LIFETIME:-3600}"
QUERY_TIMEOUT="${QUERY_TIMEOUT:-0}"
QUERY_WAIT_TIMEOUT="${QUERY_WAIT_TIMEOUT:-120}"

# Logging
LOG_CONNECTIONS="${LOG_CONNECTIONS:-0}"
LOG_DISCONNECTIONS="${LOG_DISCONNECTIONS:-0}"
LOG_POOLER_ERRORS="${LOG_POOLER_ERRORS:-1}"
LOG_STATS="${LOG_STATS:-1}"
STATS_PERIOD="${STATS_PERIOD:-60}"
VERBOSE="${VERBOSE:-0}"

# Admin
ADMIN_USERS="${ADMIN_USERS:-${AUTH_USER}}"
STATS_USERS="${STATS_USERS:-${AUTH_USER}}"

# --- Log configuration ---
echo "=============================================="
echo "PgBouncer Configuration"
echo "=============================================="
echo ""
echo "Connection:"
echo "  DB_HOST                 = ${DB_HOST}"
echo "  DB_PORT                 = ${DB_PORT}"
echo "  SERVER_TLS_SSLMODE      = ${SERVER_TLS_SSLMODE}"
echo "  AUTH_USER               = ${AUTH_USER}"
echo "  AUTH_DBNAME             = ${AUTH_DBNAME}"
echo "  AUTH_QUERY              = ${AUTH_QUERY}"
echo ""
echo "Pooling:"
echo "  POOL_MODE               = ${POOL_MODE}"
echo "  DEFAULT_POOL_SIZE       = ${DEFAULT_POOL_SIZE}"
echo "  MIN_POOL_SIZE           = ${MIN_POOL_SIZE}"
echo "  RESERVE_POOL_SIZE       = ${RESERVE_POOL_SIZE}"
echo "  RESERVE_POOL_TIMEOUT    = ${RESERVE_POOL_TIMEOUT}s"
echo "  MAX_DB_CONNECTIONS      = ${MAX_DB_CONNECTIONS}"
echo "  MAX_USER_CONNECTIONS    = ${MAX_USER_CONNECTIONS}"
echo ""
echo "Client Limits:"
echo "  MAX_CLIENT_CONN         = ${MAX_CLIENT_CONN}"
echo "  MAX_PREPARED_STATEMENTS = ${MAX_PREPARED_STATEMENTS}"
echo ""
echo "Timeouts:"
echo "  CLIENT_IDLE_TIMEOUT     = ${CLIENT_IDLE_TIMEOUT}s"
echo "  CLIENT_LOGIN_TIMEOUT    = ${CLIENT_LOGIN_TIMEOUT}s"
echo "  SERVER_CONNECT_TIMEOUT  = ${SERVER_CONNECT_TIMEOUT}s"
echo "  SERVER_IDLE_TIMEOUT     = ${SERVER_IDLE_TIMEOUT}s"
echo "  SERVER_LIFETIME         = ${SERVER_LIFETIME}s"
echo "  QUERY_TIMEOUT           = ${QUERY_TIMEOUT}s"
echo "  QUERY_WAIT_TIMEOUT      = ${QUERY_WAIT_TIMEOUT}s"
echo ""
echo "=============================================="

# --- Create userlist.txt with only the auth_user ---
# All other users are authenticated via auth_query against PostgreSQL
cat > "${AUTH_FILE}" <<EOF
"${AUTH_USER}" "${AUTH_PASSWORD}"
EOF
chmod 600 "${AUTH_FILE}"

echo "Created authentication file with auth_user"

# --- Create pgbouncer.ini ---
cat > "${PG_CONFIG_FILE}" <<EOF
;; ===========================================
;; PgBouncer Configuration
;; Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
;; ===========================================

[databases]
; Wildcard - allows any database name, passes through to RDS
; Credentials are validated via auth_query
* = host=${DB_HOST} port=${DB_PORT}

[pgbouncer]
; --- Network ---
listen_addr = 0.0.0.0
listen_port = 6432

; --- Authentication ---
; Use auth_query to validate credentials against PostgreSQL
auth_type   = plain
auth_file   = ${AUTH_FILE}
auth_user   = ${AUTH_USER}
auth_dbname = ${AUTH_DBNAME}
auth_query  = ${AUTH_QUERY}

; --- TLS ---
server_tls_sslmode = ${SERVER_TLS_SSLMODE}

; --- Pooling ---
pool_mode = ${POOL_MODE}
default_pool_size = ${DEFAULT_POOL_SIZE}
min_pool_size = ${MIN_POOL_SIZE}
reserve_pool_size = ${RESERVE_POOL_SIZE}
reserve_pool_timeout = ${RESERVE_POOL_TIMEOUT}
max_db_connections = ${MAX_DB_CONNECTIONS}
max_user_connections = ${MAX_USER_CONNECTIONS}

; --- Client Limits ---
max_client_conn = ${MAX_CLIENT_CONN}
max_prepared_statements = ${MAX_PREPARED_STATEMENTS}

; --- Timeouts ---
client_idle_timeout = ${CLIENT_IDLE_TIMEOUT}
client_login_timeout = ${CLIENT_LOGIN_TIMEOUT}
server_connect_timeout = ${SERVER_CONNECT_TIMEOUT}
server_idle_timeout = ${SERVER_IDLE_TIMEOUT}
server_lifetime = ${SERVER_LIFETIME}
query_timeout = ${QUERY_TIMEOUT}
query_wait_timeout = ${QUERY_WAIT_TIMEOUT}

; --- Logging ---
log_connections = ${LOG_CONNECTIONS}
log_disconnections = ${LOG_DISCONNECTIONS}
log_pooler_errors = ${LOG_POOLER_ERRORS}
log_stats = ${LOG_STATS}
stats_period = ${STATS_PERIOD}
verbose = ${VERBOSE}

; --- Admin ---
admin_users = ${ADMIN_USERS}
stats_users = ${STATS_USERS}

; --- Misc ---
; Required for some clients/ORMs
ignore_startup_parameters = extra_float_digits,options
EOF

echo "Created PgBouncer configuration"
echo ""
echo "Starting PgBouncer..."
echo ""

exec "$@"
