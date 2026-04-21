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

# Поддерживаем оба layout:
# 1) flat (icecast.xml в корне проекта)
# 2) tree (icecast/icecast.xml)
if [ -f icecast.xml ]; then
  ICECAST_XML_PATH="icecast.xml"
elif [ -f icecast/icecast.xml ]; then
  ICECAST_XML_PATH="icecast/icecast.xml"
else
  echo "ERROR: не найден icecast.xml (ни ./icecast.xml, ни ./icecast/icecast.xml)"
  exit 1
fi

cp "$ICECAST_XML_PATH" "${ICECAST_XML_PATH}.bak"

sed -i "s|SOURCE_PASS_PLACEHOLDER|${ICECAST_SOURCE_PASSWORD}|g" "$ICECAST_XML_PATH"
sed -i "s|RELAY_PASS_PLACEHOLDER|${ICECAST_RELAY_PASSWORD}|g"   "$ICECAST_XML_PATH"
sed -i "s|ADMIN_PASS_PLACEHOLDER|${ICECAST_ADMIN_PASSWORD}|g"   "$ICECAST_XML_PATH"

echo "✓ $ICECAST_XML_PATH обновлён (бэкап в ${ICECAST_XML_PATH}.bak)"
