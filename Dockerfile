FROM alpine:3.22 AS build
ARG VERSION=1.25.0

RUN apk add --no-cache autoconf autoconf-doc automake curl gcc libc-dev libevent-dev libtool make openssl-dev pkgconfig

RUN curl -sS -o /pgbouncer.tar.gz -L https://pgbouncer.github.io/downloads/files/$VERSION/pgbouncer-$VERSION.tar.gz && \
  tar -xzf /pgbouncer.tar.gz && mv /pgbouncer-$VERSION /pgbouncer

RUN cd /pgbouncer && ./configure --prefix=/usr && make pgbouncer

FROM alpine:3.22

RUN apk add --no-cache libevent && \
  mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer && \
  adduser -D -u 70 -g postgres postgres && \
  chown -R postgres /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer

COPY entrypoint.sh /entrypoint.sh
COPY --from=build /pgbouncer/pgbouncer /usr/bin

RUN chmod +x /entrypoint.sh

EXPOSE 5432
USER postgres
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
