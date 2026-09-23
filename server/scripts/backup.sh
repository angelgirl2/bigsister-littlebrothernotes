#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
[ -f .env ] && . ./.env
set +a
mkdir -p backups
timestamp="$(date +%Y%m%d_%H%M%S)"

docker compose -f docker-compose.prod.yml exec -T db pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > "backups/big_sister_${timestamp}.sql"

MEDIA_VOL="$(docker volume ls -q --filter label=com.docker.compose.volume=media_data | head -n 1)"
if [ -n "${MEDIA_VOL}" ]; then
  MEDIA_MOUNT="$(docker volume inspect -f '{{.Mountpoint}}' "${MEDIA_VOL}")"
  tar -czf "backups/big_sister_media_${timestamp}.tar.gz" -C "${MEDIA_MOUNT}" .
else
  echo "Warning: media_data Docker volume was not found; database backup was still created." >&2
fi

find backups -type f -name 'big_sister_*.sql' -mtime +14 -delete
find backups -type f -name 'big_sister_media_*.tar.gz' -mtime +14 -delete
echo "Database backup: backups/big_sister_${timestamp}.sql"
if [ -f "backups/big_sister_media_${timestamp}.tar.gz" ]; then
  echo "Media backup: backups/big_sister_media_${timestamp}.tar.gz"
fi
