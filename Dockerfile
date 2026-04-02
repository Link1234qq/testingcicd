FROM debian:stable-slim AS builder

RUN apt-get update && apt-get install -y \
    gcc make flex bison \
    zlib1g-dev libreadline-dev libssl-dev libxml2-dev \
    ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -eu; \
    curl -sSL "https://ftp.postgresql.org/pub/source/v11.6/postgresql-11.6.tar.gz" -o "postgresql-11.6.tar.gz"; \
    curl -sSL "https://ftp.postgresql.org/pub/source/v12.19/postgresql-12.19.tar.gz" -o "postgresql-12.19.tar.gz"; \
    tar xzf "postgresql-11.6.tar.gz"; \
    tar xzf "postgresql-12.19.tar.gz"; \
    mkdir -p /usr/local/pgsql/11 /usr/local/pgsql/12 /var/lib/postgresql/data; \
    cd "postgresql-11.6"; \
    ./configure --prefix=/usr/local/pgsql/11 --without-icu; \
    make -j"$(nproc)"; \
    make install; \
    cd ..; \
    cd "postgresql-12.19"; \
    ./configure --prefix=/usr/local/pgsql/12 --without-icu; \
    make -j"$(nproc)"; \
    make install; \
    cd ..; \
    rm -rf postgresql-11.6 postgresql-12.19 \
        postgresql-11.6.tar.gz postgresql-12.19.tar.gz


RUN \
    mkdir -p /runtime/usr/local/pgsql; \
    mkdir -p /runtime/lib/x86_64-linux-gnu; \
    mkdir -p /runtime/usr/lib/x86_64-linux-gnu; \
    mkdir -p /runtime/bin; \
    mkdir -p /runtime/var/lib/postgresql/data; \
    mkdir -p /runtime/lib64; \
    mkdir -p /runtime/etc; \
    mkdir -p /runtime/tmp && chmod 1777 /runtime/tmp; \
    mkdir -p /runtime/etc/postgresql; 

RUN \
    echo 'postgres:x:10001:10001:PostgreSQL:/var/lib/postgresql:/bin/sh' > /runtime/etc/passwd; \
    echo 'postgres:x:10001:' > /runtime/etc/group; \
    chown -R 10001:10001 /runtime/var/lib/postgresql; \
    chmod 1777 /runtime/var/lib/postgresql/data;

RUN \
    cp -a /usr/local/pgsql/11 /runtime/usr/local/pgsql/11; \
    cp -a /usr/local/pgsql/12 /runtime/usr/local/pgsql/12; \
    cp -a /lib/x86_64-linux-gnu/libssl.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libcrypto.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /usr/lib/x86_64-linux-gnu/libpq.so.* /runtime/usr/lib/x86_64-linux-gnu/; \
    cp -a /usr/lib/x86_64-linux-gnu/libxml2.so.* /runtime/usr/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /runtime/lib64/; \
    cp -a /lib/x86_64-linux-gnu/libm.so.* /runtime/lib/x86_64-linux-gnu/; \
        # glibc runtime (must-have for almost any dynamic binary)
    cp -a /lib/x86_64-linux-gnu/libc.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libm.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libpthread.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libdl.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/librt.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libgcc_s.so.* /runtime/lib/x86_64-linux-gnu/; \
    # postgres common deps
    cp -a /lib/x86_64-linux-gnu/libz.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libreadline.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp -a /lib/x86_64-linux-gnu/libtinfo.so.* /runtime/lib/x86_64-linux-gnu/; \
    cp /bin/sh /runtime/bin/sh; \
    cp /bin/cp /runtime/bin/cp; \
    cp -a /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /runtime/lib64/

COPY postgresql-11.conf /runtime/etc/postgresql/11/postgresql.conf.template
COPY postgresql-12.conf /runtime/etc/postgresql/12/postgresql.conf.template

COPY --chmod=0755 entrypoint.sh /runtime/entrypoint.sh

FROM scratch AS runtime

ENV PGDATA=/var/lib/postgresql/data

COPY --from=builder /runtime/ /

USER 10001:10001

EXPOSE 5432


VOLUME ["/var/lib/postgresql/data"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["11"]
