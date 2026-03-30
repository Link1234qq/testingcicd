#!/bin/sh
set -eu

PG_VERSION="${PG_VERSION:-11}"
case "${1:-}" in
  11|12)
    PG_VERSION="$1"
    shift
    ;;
esac

case "$PG_VERSION" in
  11) PGROOT="/usr/local/pgsql/11" ;;
  12) PGROOT="/usr/local/pgsql/12" ;;
  *)
    echo "Unsupported PG_VERSION: $PG_VERSION (use 11 or 12)" >&2
    exit 1
    ;;
esac

export PATH="/bin:${PGROOT}/bin:${PATH}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"
TEMPLATE="/etc/postgresql/${PG_VERSION}/postgresql.conf.template"

# one-off команди без кластера (наприклад --version)
for arg in "$@"; do
  if [ "$arg" = "--version" ]; then
    exec postgres --version
  fi
done

# перший запуск: ініціалізація кластера
NEED_CONF=0
if [ ! -s "${PGDATA}/PG_VERSION" ]; then
  mkdir -p "$PGDATA"
  initdb -D "$PGDATA" --locale=C --encoding=UTF8 --username=postgres
  NEED_CONF=1
fi

# шаблон → postgresql.conf у PGDATA (postgres читає саме його за замовчуванням)
# копіюємо після initdb або якщо конфігу ще немає (не перезаписуємо ручні правки щоразу)
if [ -f "$TEMPLATE" ]; then
  if [ "$NEED_CONF" = 1 ] || [ ! -f "${PGDATA}/postgresql.conf" ]; then
    cp -f "$TEMPLATE" "${PGDATA}/postgresql.conf"
  fi
else
  echo "warning: missing $TEMPLATE" >&2
fi

exec postgres -D "$PGDATA" "$@"
