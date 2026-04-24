#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=== SoloMoon's Club Health Check ==="
echo ""

if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker not installed"
  exit 1
fi

echo "Service Status:"
docker compose ps

echo ""
echo "Stream Availability:"
if curl -sf http://localhost:8000/status-json.xsl > /dev/null 2>&1; then
  echo "OK: Icecast API responding"
else
  echo "ERROR: Icecast API not responding"
fi

echo ""
echo "Music Files:"
MUSIC_COUNT=$(find ./music -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.ogg" -o -name "*.m4a" -o -name "*.wav" \) 2>/dev/null | wc -l)
echo "  Tracks: $MUSIC_COUNT"

echo ""
echo "Recent Logs:"
docker compose logs --tail 5 liquidsoap 2>/dev/null || echo "(logs not available)"

echo ""
echo "=== Health Check Complete ==="
