#!/usr/bin/env bash
# Подставляет пароли из .env в icecast.xml
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERROR: .env не найден. Скопируй .env.example → .env и поменяй пароли"
  exit 1
fi

set -a
source .env
set +a

cp icecast/icecast.xml icecast/icecast.xml.bak

sed -i "s|SOURCE_PASS_PLACEHOLDER|${ICECAST_SOURCE_PASSWORD}|g" icecast/icecast.xml
sed -i "s|RELAY_PASS_PLACEHOLDER|${ICECAST_RELAY_PASSWORD}|g"   icecast/icecast.xml
sed -i "s|ADMIN_PASS_PLACEHOLDER|${ICECAST_ADMIN_PASSWORD}|g"   icecast/icecast.xml

echo "✓ icecast.xml обновлён (бэкап в icecast.xml.bak)"
