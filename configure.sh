#!/usr/bin/env bash
# Подставляет пароли из .env в icecast.xml
set -euo pipefail

# Переходим в директорию самого скрипта, а не на уровень выше.
# Предыдущий вариант (cd "$(dirname "$0")/..") был рассчитан на размещение
# в scripts/ — из корня репо он уходил в родительскую директорию.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f .env ]; then
  echo "ERROR: .env не найден. Скопируй .env.example → .env и поменяй пароли"
  exit 1
fi

set -a
source .env
set +a

# Проверяем, что пароли не пустые — пустая подстановка оставит Icecast
# с пустым паролем и откроет source/admin без аутентификации.
for var in ICECAST_SOURCE_PASSWORD ICECAST_RELAY_PASSWORD ICECAST_ADMIN_PASSWORD; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var не задан или пустой в .env"
    exit 1
  fi
done

cp icecast.xml icecast.xml.bak

sed -i "s|SOURCE_PASS_PLACEHOLDER|${ICECAST_SOURCE_PASSWORD}|g" icecast.xml
sed -i "s|RELAY_PASS_PLACEHOLDER|${ICECAST_RELAY_PASSWORD}|g"   icecast.xml
sed -i "s|ADMIN_PASS_PLACEHOLDER|${ICECAST_ADMIN_PASSWORD}|g"   icecast.xml

echo "✓ icecast.xml обновлён (бэкап в icecast.xml.bak)"
