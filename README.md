# PgBouncer Docker Image

A simple PgBouncer connection pooler Docker image configured for transaction pooling.

## Environment Variables

Required:
- `DB_HOST` - PostgreSQL server hostname
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password
- `DB_NAME` - Database name

Optional (with defaults):
- `DB_PORT` - PostgreSQL server port (default: 5432)
- `MAX_CLIENT_CONN` - Maximum client connections (default: 1000)
- `POOL_SIZE` - Connection pool size (default: 20)

## Usage

```bash
docker build -t pgbouncer .

docker run -d \
  -e DB_HOST=postgres.example.com \
  -e DB_PORT=5432 \
  -e DB_USER=myuser \
  -e DB_PASSWORD=mypassword \
  -e DB_NAME=mydb \
  -e MAX_CLIENT_CONN=1000 \
  -e POOL_SIZE=20 \
  -p 5432:5432 \
  pgbouncer
```

## Configuration

- **Pool Mode**: Transaction (best for most applications)
- **Authentication**: MD5
- **Port**: 5432

Connect to PgBouncer using the same credentials (`DB_USER` and `DB_PASSWORD`) to access the `DB_NAME` database.
