#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created server/.env. Edit secrets and DOMAIN, then run this script again."
  exit 1
fi
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
