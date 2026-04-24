#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=== SoloMoon's Club Deployment ==="
echo "Project: $PROJECT_DIR"
echo ""

if [ ! -f .env ]; then
  echo "ERROR: .env not found"
  echo "Please copy .env.example to .env and configure it"
  exit 1
fi

if [ ! -d music ] || [ -z "$(ls -A music 2>/dev/null || true)" ]; then
  echo "WARNING: music/ directory is empty"
  echo "Please upload music files first (120+ minutes recommended)"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "Configuring Icecast..."
./scripts/configure.sh

echo "Building Docker images..."
docker compose build

echo "Starting services..."
docker compose up -d

echo ""
echo "=== Deployment Complete ==="
echo ""
docker compose ps
echo ""
echo "Access:"
echo "  Icecast:   http://localhost:8000/"
echo "  Stream:    http://localhost:8000/stream.mp3"
echo ""
