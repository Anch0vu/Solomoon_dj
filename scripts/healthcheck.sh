#!/usr/bin/env bash
# Health check script for SoloMoon's Club
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=== SoloMoon's Club Health Check ==="
echo ""

# Check if docker compose is accessible
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker not installed"
  exit 1
fi

# Check service status
echo "Service Status:"
docker compose ps

echo ""
echo "Port Accessibility:"
nc -zv localhost 8000 2>&1 | grep -q "open" && echo "✓ Icecast (8000)" || echo "✗ Icecast (8000)"
nc -zv localhost 8080 2>&1 | grep -q "open" && echo "✓ Radio API (8080)" || echo "✗ Radio API (8080)"

echo ""
echo "Stream Availability:"
if curl -sf http://localhost:8000/status-json.xsl > /dev/null 2>&1; then
  echo "✓ Icecast API responding"
  curl -s http://localhost:8000/status-json.xsl | grep -q "stream" && echo "✓ Stream active" || echo "✗ Stream inactive"
else
  echo "✗ Icecast API not responding"
fi

echo ""
echo "Music Files:"
MUSIC_COUNT=$(find ./music -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.ogg" -o -name "*.m4a" -o -name "*.wav" \) 2>/dev/null | wc -l)
echo "  Tracks: $MUSIC_COUNT"

echo ""
echo "Resource Usage:"
docker compose stats --no-stream 2>/dev/null || echo "  (docker stats not available)"

echo ""
echo "Recent Logs (liquidsoap):"
docker compose logs --tail 3 liquidsoap | tail -3

echo ""
echo "=== Health Check Complete ==="
