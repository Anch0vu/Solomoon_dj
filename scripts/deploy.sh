#!/usr/bin/env bash
# Automated deployment script for Ubuntu 24.04.4
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=== SoloMoon's Club Deployment ==="
echo "Project: $PROJECT_DIR"
echo ""

# Check .env exists
if [ ! -f .env ]; then
  echo "ERROR: .env not found"
  echo "Please copy .env.example to .env and configure it"
  exit 1
fi

# Check music directory
if [ ! -d music ] || [ -z "$(ls -A music 2>/dev/null || true)" ]; then
  echo "WARNING: music/ directory is empty"
  echo "Please upload music files first (≥ 120 minutes recommended)"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Configure Icecast
echo "Configuring Icecast..."
./scripts/configure.sh

# Build and start
echo "Building Docker images..."
docker compose build

echo "Starting services..."
docker compose up -d

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Status: $(docker compose ps --services --filter "status=running" | wc -l)/3 services running"
echo ""
echo "Access points:"
echo "  • Icecast:   http://localhost:8000/ (admin + password from .env)"
echo "  • Stream:    http://localhost:8000/stream.mp3"
echo "  • Radio API: ws://localhost:8080/dj?token=YOUR_DJ_TOKEN"
echo ""
echo "Check logs:"
echo "  docker compose logs -f liquidsoap"
echo "  docker compose logs -f icecast"
echo "  docker compose logs -f radio-api"
echo ""
