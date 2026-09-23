#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "Create server/.env first"; exit 1; }
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
