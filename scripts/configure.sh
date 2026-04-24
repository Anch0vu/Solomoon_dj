#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example -> .env and set passwords"
  exit 1
fi

set -a
source .env
set +a

for var in ICECAST_SOURCE_PASSWORD ICECAST_RELAY_PASSWORD ICECAST_ADMIN_PASSWORD; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set or empty in .env"
    exit 1
  fi
done

cp icecast/icecast.xml icecast/icecast.xml.bak 2>/dev/null || true

sed -i "s|SOURCE_PASS_PLACEHOLDER|${ICECAST_SOURCE_PASSWORD}|g" icecast/icecast.xml
sed -i "s|RELAY_PASS_PLACEHOLDER|${ICECAST_RELAY_PASSWORD}|g" icecast/icecast.xml
sed -i "s|ADMIN_PASS_PLACEHOLDER|${ICECAST_ADMIN_PASSWORD}|g" icecast/icecast.xml

echo "OK: icecast/icecast.xml updated"
