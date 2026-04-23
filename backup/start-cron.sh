#!/bin/sh
set -eu

BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * 0}"
BACKUP_ROOT="${BACKUP_ROOT:-/backup}"
BACKUP_DB_PATH="${BACKUP_DB_PATH:-/app/data/db.sqlite3}"
BACKUP_MEDIA_PATH="${BACKUP_MEDIA_PATH:-/app/media}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
RUN_BACKUP_ON_START="${RUN_BACKUP_ON_START:-true}"

mkdir -p "${BACKUP_ROOT}/db" "${BACKUP_ROOT}/media"
touch /var/log/backup.log

if [ "${RUN_BACKUP_ON_START}" = "true" ]; then
  echo "[backup] Running one backup on startup"
  BACKUP_ROOT="${BACKUP_ROOT}" \
  BACKUP_DB_PATH="${BACKUP_DB_PATH}" \
  BACKUP_MEDIA_PATH="${BACKUP_MEDIA_PATH}" \
  RETENTION_DAYS="${RETENTION_DAYS}" \
  sh /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1
fi

printf "%s BACKUP_ROOT=%s BACKUP_DB_PATH=%s BACKUP_MEDIA_PATH=%s RETENTION_DAYS=%s sh /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1\n" \
  "${BACKUP_SCHEDULE}" \
  "${BACKUP_ROOT}" \
  "${BACKUP_DB_PATH}" \
  "${BACKUP_MEDIA_PATH}" \
  "${RETENTION_DAYS}" \
  > /etc/crontabs/root

echo "[backup] Cron schedule installed: ${BACKUP_SCHEDULE}"
echo "[backup] Backup path: ${BACKUP_ROOT}"

exec crond -f -l 8
