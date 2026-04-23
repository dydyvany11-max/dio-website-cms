#!/bin/sh
set -eu

# Скрипт восстановления данных из бэкапов.
# Примеры запуска из корня проекта:
#   docker compose stop web
#   docker compose --profile tools run --rm backup_restore sh /usr/local/bin/restore.sh list
#   docker compose --profile tools run --rm backup_restore sh /usr/local/bin/restore.sh db latest
#   docker compose --profile tools run --rm backup_restore sh /usr/local/bin/restore.sh media latest
#   docker compose --profile tools run --rm backup_restore sh /usr/local/bin/restore.sh all latest latest
#   docker compose up -d web

BACKUP_ROOT="${BACKUP_ROOT:-/backup}"
DB_PATH="${BACKUP_DB_PATH:-/app/data/db.sqlite3}"
MEDIA_PATH="${BACKUP_MEDIA_PATH:-/app/media}"

usage() {
  cat <<EOF
Использование:
  restore.sh list
  restore.sh db [latest|/backup/db/db-*.sqlite3.gz]
  restore.sh media [latest|/backup/media/media-*.tar.gz]
  restore.sh all [db_backup_or_latest] [media_backup_or_latest]

Важно:
  1) Перед восстановлением остановите 'web', чтобы SQLite не писался в момент restore.
  2) Команда 'media' полностью заменяет содержимое каталога ${MEDIA_PATH}.
  3) После восстановления запустите 'web' обратно: docker compose up -d web
EOF
}

latest_file() {
  dir="$1"
  pattern="$2"
  # Берем самый новый бэкап по имени (имя содержит UTC timestamp).
  latest="$(ls -1 "${dir}"/${pattern} 2>/dev/null | sort | tail -n 1 || true)"
  if [ -z "${latest}" ]; then
    echo "Бэкапы не найдены в ${dir}" >&2
    exit 1
  fi
  echo "${latest}"
}

resolve_backup_path() {
  kind="$1"
  value="$2"
  if [ "${kind}" = "db" ]; then
    if [ "${value}" = "latest" ]; then
      latest_file "${BACKUP_ROOT}/db" "db-*.sqlite3.gz"
      return
    fi
  fi

  if [ "${kind}" = "media" ]; then
    if [ "${value}" = "latest" ]; then
      latest_file "${BACKUP_ROOT}/media" "media-*.tar.gz"
      return
    fi
  fi

  echo "${value}"
}

restore_db() {
  backup_path="$(resolve_backup_path db "$1")"
  if [ ! -f "${backup_path}" ]; then
    echo "Файл бэкапа БД не найден: ${backup_path}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${DB_PATH}")"
  tmp_path="${DB_PATH}.restore.$$"
  # Распаковываем sqlite-бэкап во временный файл и атомарно подменяем БД.
  gunzip -c "${backup_path}" > "${tmp_path}"
  mv "${tmp_path}" "${DB_PATH}"
  echo "[restore] БД восстановлена: ${backup_path} -> ${DB_PATH}"
}

restore_media() {
  backup_path="$(resolve_backup_path media "$1")"
  if [ ! -f "${backup_path}" ]; then
    echo "Файл бэкапа медиа не найден: ${backup_path}" >&2
    exit 1
  fi

  mkdir -p "${MEDIA_PATH}"
  # Восстановление медиа выполняется с полной заменой текущего содержимого.
  find "${MEDIA_PATH}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  tar -xzf "${backup_path}" -C "${MEDIA_PATH}"
  echo "[restore] Медиа восстановлены: ${backup_path} -> ${MEDIA_PATH}"
}

list_backups() {
  echo "Бэкапы БД:"
  ls -1 "${BACKUP_ROOT}/db"/db-*.sqlite3.gz 2>/dev/null | sort || echo "(empty)"
  echo
  echo "Бэкапы медиа:"
  ls -1 "${BACKUP_ROOT}/media"/media-*.tar.gz 2>/dev/null | sort || echo "(empty)"
}

command="${1:-}"

case "${command}" in
  list)
    list_backups
    ;;
  db)
    restore_db "${2:-latest}"
    ;;
  media)
    restore_media "${2:-latest}"
    ;;
  all)
    restore_db "${2:-latest}"
    restore_media "${3:-latest}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
