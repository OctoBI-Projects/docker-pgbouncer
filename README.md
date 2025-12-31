# PgBouncer Docker Image

A lightweight, configurable PgBouncer Docker image optimized for Kubernetes deployments with PostgreSQL/RDS/Aurora.

## Features

- **Dynamic database routing** - Wildcard configuration allows connections to any database
- **Auth passthrough** - Credentials validated against PostgreSQL via `auth_query`
- **Transaction pooling** - Optimized for modern applications (configurable)
- **Prepared statement support** - PgBouncer 1.21+ native prepared statement handling
- **Fully configurable via environment variables** - No config file mounting required
- **Minimal image size** - Multi-stage Alpine build (~15MB)
- **Non-root execution** - Runs as `postgres` user (UID 70)

## Quick Start

```bash
docker run -d \
  -p 6432:6432 \
  -e DB_HOST=your-rds-cluster.xxx.region.rds.amazonaws.com \
  -e AUTH_USER=pgbouncer_auth \
  -e AUTH_PASSWORD=your-password \
  your-registry/pgbouncer:1.25.1
```

## Prerequisites

### PostgreSQL Setup

Before using PgBouncer, create an authentication user in your PostgreSQL/RDS database:

```sql
-- 1. Create the auth user
CREATE USER pgbouncer_auth WITH PASSWORD 'your-secure-password';

-- 2. Create authentication function (required for RDS/Aurora)
CREATE OR REPLACE FUNCTION public.pgbouncer_get_auth(p_usename TEXT)
RETURNS TABLE(usename name, passwd text) AS
$$
BEGIN
    RETURN QUERY
    SELECT u.usename, u.passwd
    FROM pg_catalog.pg_shadow u
    WHERE u.usename = p_usename;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Restrict access to the function
REVOKE ALL ON FUNCTION public.pgbouncer_get_auth(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pgbouncer_get_auth(TEXT) TO pgbouncer_auth;
```

> **Note**: The `SECURITY DEFINER` function is required for RDS/Aurora because direct access to `pg_shadow` is restricted.

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `DB_HOST` | PostgreSQL/RDS cluster endpoint hostname |
| `AUTH_USER` | PostgreSQL user for auth_query |
| `AUTH_PASSWORD` | Password for AUTH_USER |

### Connection

| Variable | Default                                                    | Description                                                                                                                               |
|----------|------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `DB_PORT` | `5432`                                                     | PostgreSQL port                                                                                                                           |
| `SERVER_TLS_SSLMODE` | `require`                                                  | TLS mode: `disable`, `allow`, `prefer`, `require`, `verify-ca`, `verify-full`                                                             |
| `AUTH_DBNAME` | `postgres`                                                 | Database to connect to for authentication                                                                                                   |
| `AUTH_QUERY` | `SELECT usename, passwd FROM pg_shadow WHERE usename = $1` | SQL query to authenticate users. For RDS/Aurora you will need to maintain a custom table with all username/passwords and query from there |

### Pooling

| Variable | Default | Description |
|----------|---------|-------------|
| `POOL_MODE` | `transaction` | Pooling mode: `session`, `transaction`, `statement` |
| `DEFAULT_POOL_SIZE` | `20` | Server connections per user/database pair |
| `MIN_POOL_SIZE` | `5` | Minimum server connections to keep open |
| `RESERVE_POOL_SIZE` | `5` | Extra connections for burst traffic |
| `RESERVE_POOL_TIMEOUT` | `3` | Seconds before using reserve pool |
| `MAX_DB_CONNECTIONS` | `100` | Maximum connections per database |
| `MAX_USER_CONNECTIONS` | `100` | Maximum connections per user |

### Client Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `MAX_CLIENT_CONN` | `1000` | Maximum client connections allowed |
| `MAX_PREPARED_STATEMENTS` | `200` | Prepared statements cached per client. Set to `0` to disable |

### Timeouts

| Variable | Default | Description |
|----------|---------|-------------|
| `CLIENT_IDLE_TIMEOUT` | `0` | Seconds before closing idle client connection (`0` = disabled) |
| `CLIENT_LOGIN_TIMEOUT` | `60` | Seconds to wait for client authentication |
| `SERVER_CONNECT_TIMEOUT` | `15` | Seconds to wait for server connection |
| `SERVER_IDLE_TIMEOUT` | `600` | Seconds before closing idle server connection |
| `SERVER_LIFETIME` | `3600` | Maximum seconds a server connection can live |
| `QUERY_TIMEOUT` | `0` | Maximum seconds a query can run (`0` = disabled) |
| `QUERY_WAIT_TIMEOUT` | `120` | Maximum seconds client waits for available server connection |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_CONNECTIONS` | `0` | Log successful connections (`0` or `1`) |
| `LOG_DISCONNECTIONS` | `0` | Log disconnections with reason (`0` or `1`) |
| `LOG_POOLER_ERRORS` | `1` | Log pooler errors (`0` or `1`) |
| `LOG_STATS` | `1` | Log statistics periodically (`0` or `1`) |
| `STATS_PERIOD` | `60` | Seconds between statistics logging |
| `VERBOSE` | `0` | Verbosity level (`0`, `1`, or `2`) |

### Admin

| Variable | Default | Description |
|----------|---------|-------------|
| `ADMIN_USERS` | `${AUTH_USER}` | Comma-separated list of admin users |
| `STATS_USERS` | `${AUTH_USER}` | Comma-separated list of users who can view stats |

## Pool Mode Selection

| Mode | Description | Use When |
|------|-------------|----------|
| `session` | Connection held until client disconnects | App uses session features (LISTEN/NOTIFY, session variables) |
| `transaction` | Connection returned after each transaction | **Recommended for most apps**. Stateless web services, APIs |
| `statement` | Connection returned after each statement | Simple queries only, no multi-statement transactions |

### Transaction Mode Compatibility

Transaction mode is incompatible with:
- `SET` commands / session variables
- `LISTEN` / `NOTIFY`
- Session-level advisory locks (`pg_advisory_lock`)
- Temporary tables that span transactions
- `WITH HOLD` cursors

Transaction-scoped advisory locks (`pg_advisory_xact_lock`) work fine.

## Kubernetes Deployment

### Basic Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pgbouncer
  template:
    metadata:
      labels:
        app: pgbouncer
    spec:
      containers:
        - name: pgbouncer
          image: your-registry/pgbouncer:1.25.1
          ports:
            - containerPort: 6432
          env:
            - name: DB_HOST
              value: "your-rds-cluster.xxx.region.rds.amazonaws.com"
            - name: AUTH_USER
              valueFrom:
                secretKeyRef:
                  name: pgbouncer-auth
                  key: username
            - name: AUTH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pgbouncer-auth
                  key: password
            - name: AUTH_DBNAME
              value: "postgres"
            - name: AUTH_QUERY
              value: "SELECT usename, passwd FROM pg_shadow WHERE usename = $1"
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
          livenessProbe:
            tcpSocket:
              port: 6432
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            tcpSocket:
              port: 6432
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: pgbouncer
spec:
  ports:
    - port: 5432
      targetPort: 6432
  selector:
    app: pgbouncer
```

### Replica Recommendations

| Cluster Size | Replicas | Notes |
|--------------|----------|-------|
| Small (< 10 app pods) | 2 | Minimum for HA |
| Medium (10-50 pods) | 2-3 | Add zone spreading |
| Large (50+ pods) | 3-5 | Use HPA |

### Pod Disruption Budget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pgbouncer
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: pgbouncer
```

## Application Configuration

Update your application connection strings to point to PgBouncer:

```
# Before (direct to RDS)
postgresql://user:pass@rds-cluster.xxx.rds.amazonaws.com:5432/mydb

# After (through PgBouncer)
postgresql://user:pass@pgbouncer.namespace.svc.cluster.local:5432/mydb
```

### Connection Pool Sizing

When using PgBouncer, reduce your application's connection pool size:

```typescript
// Before PgBouncer - app manages pooling
const pool = new Pool({ max: 20 });

// After PgBouncer - minimal app pool, PgBouncer handles multiplexing
const pool = new Pool({ max: 2 });
```

## Monitoring

### Admin Console

Connect to the PgBouncer admin console:

```bash
psql -h pgbouncer-host -p 6432 -U pgbouncer_auth pgbouncer
```

Useful commands:

```sql
SHOW POOLS;              -- Pool statistics
SHOW STATS;              -- General statistics  
SHOW SERVERS;            -- Backend server connections
SHOW CLIENTS;            -- Client connections
SHOW DATABASES;          -- Database configuration
SHOW CONFIG;             -- Current configuration
SHOW PREPARED_STATEMENTS; -- Cached prepared statements (1.21+)
```

### Prometheus Metrics

Deploy [pgbouncer_exporter](https://github.com/prometheus-community/pgbouncer_exporter) as a sidecar for Prometheus metrics.

## Connection Math

Calculate your total backend connections:

```
Total RDS connections = replicas × default_pool_size × unique_user_db_pairs

Example:
  2 replicas × 20 pool_size × 5 databases × 2 users = 400 connections
```

Ensure this doesn't exceed your RDS instance's `max_connections` limit:

| RDS Instance | RAM | ~max_connections |
|--------------|-----|------------------|
| db.t3.micro | 1 GB | 85 |
| db.t3.small | 2 GB | 170 |
| db.r5.large | 16 GB | 1,600 |
| db.r5.xlarge | 32 GB | 3,300 |

## Building

```bash
# Build the image
docker build -t pgbouncer:1.25.1 .

# Build with different PgBouncer version
docker build --build-arg PGBOUNCER_VERSION=1.25.0 -t pgbouncer:1.25.0 .
```

## Troubleshooting

### Connection Refused

```
psql: error: connection refused
```

- Verify `DB_HOST` is correct and reachable from the container
- Check security groups allow traffic on port 5432 from PgBouncer pods

### Authentication Failed

```
ERROR: password authentication failed
```

- Ensure `AUTH_USER` exists in PostgreSQL
- Verify `pgbouncer_get_auth` function is created and accessible
- Check `AUTH_PASSWORD` matches the database user's password

### No More Connections Allowed

```
ERROR: no more connections allowed
```

- Increase `MAX_CLIENT_CONN` or `MAX_DB_CONNECTIONS`
- Check for connection leaks in your application
- Review pool statistics with `SHOW POOLS`

### Prepared Statement Errors

```
ERROR: prepared statement "xxx" does not exist
```

- Ensure `MAX_PREPARED_STATEMENTS` is set (default: 200)
- Requires PgBouncer 1.21+

## License

PgBouncer is released under the ISC License.
