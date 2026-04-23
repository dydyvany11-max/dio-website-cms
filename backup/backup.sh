#!/bin/sh
set -eu

BACKUP_ROOT="${BACKUP_ROOT:-/backup}"
DB_PATH="${BACKUP_DB_PATH:-/app/data/db.sqlite3}"
MEDIA_PATH="${BACKUP_MEDIA_PATH:-/app/media}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DB_BACKUP_DIR="${BACKUP_ROOT}/db"
MEDIA_BACKUP_DIR="${BACKUP_ROOT}/media"

mkdir -p "${DB_BACKUP_DIR}" "${MEDIA_BACKUP_DIR}"

if [ -f "${DB_PATH}" ]; then
  DB_DUMP_PATH="${DB_BACKUP_DIR}/db-${TIMESTAMP}.sqlite3"
  DB_DUMP_TMP_PATH="${DB_DUMP_PATH}.tmp"
  DB_BACKUP_SUCCESS="false"
  ATTEMPT=1
  MAX_ATTEMPTS=5

  while [ "${ATTEMPT}" -le "${MAX_ATTEMPTS}" ]; do
    rm -f "${DB_DUMP_TMP_PATH}"
    if sqlite3 "${DB_PATH}" ".timeout 5000" ".backup '${DB_DUMP_TMP_PATH}'"; then
      mv "${DB_DUMP_TMP_PATH}" "${DB_DUMP_PATH}"
      gzip -f "${DB_DUMP_PATH}"
      DB_BACKUP_SUCCESS="true"
      echo "[backup] DB backup created: ${DB_DUMP_PATH}.gz"
      break
    fi

    echo "[backup] DB backup attempt ${ATTEMPT}/${MAX_ATTEMPTS} failed (possibly locked), retrying..."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
  done

  rm -f "${DB_DUMP_TMP_PATH}"
  if [ "${DB_BACKUP_SUCCESS}" != "true" ]; then
    echo "[backup] DB backup failed after ${MAX_ATTEMPTS} attempt(s)"
  fi
else
  echo "[backup] DB file not found at ${DB_PATH}, skipping DB backup"
fi

if [ -d "${MEDIA_PATH}" ]; then
  MEDIA_ARCHIVE_PATH="${MEDIA_BACKUP_DIR}/media-${TIMESTAMP}.tar.gz"
  tar -C "${MEDIA_PATH}" -czf "${MEDIA_ARCHIVE_PATH}" .
  echo "[backup] Media backup created: ${MEDIA_ARCHIVE_PATH}"
else
  echo "[backup] Media directory not found at ${MEDIA_PATH}, skipping media backup"
fi

find "${DB_BACKUP_DIR}" -type f -mtime +"${RETENTION_DAYS}" -delete
find "${MEDIA_BACKUP_DIR}" -type f -mtime +"${RETENTION_DAYS}" -delete
echo "[backup] Old backups older than ${RETENTION_DAYS} day(s) were removed"
