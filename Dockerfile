FROM alpine:3.23.2 AS build
ARG PGBOUNCER_VERSION=1.25.1

RUN apk add --no-cache \
    autoconf \
    autoconf-doc \
    automake \
    curl \
    gcc \
    libc-dev \
    libevent-dev \
    libtool \
    make \
    openssl-dev \
    pkgconfig

RUN curl -sS -o /pgbouncer.tar.gz -L \
    https://pgbouncer.github.io/downloads/files/${PGBOUNCER_VERSION}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz && \
    tar -xzf /pgbouncer.tar.gz && \
    mv /pgbouncer-${PGBOUNCER_VERSION} /pgbouncer

WORKDIR /pgbouncer
RUN ./configure --prefix=/usr && make pgbouncer

# --- Runtime stage ---
FROM alpine:3.23.2

RUN apk add --no-cache libevent openssl netcat-openbsd && \
    mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer && \
    adduser -D -u 70 -g postgres postgres && \
    chown -R postgres:postgres /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer

COPY --from=build /pgbouncer/pgbouncer /usr/bin/pgbouncer
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 6432

USER postgres

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD printf "SHOW VERSION;\n" | nc -w 1 127.0.0.1 6432 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
