#!/usr/bin/env bash
set -euo pipefail

MUSIC_DIR="${1:-./music}"

if [ ! -d "$MUSIC_DIR" ]; then
  echo "ERROR: Directory $MUSIC_DIR not found"
  exit 1
fi

if ! command -v r128gain &>/dev/null; then
  echo "Installing r128gain..."
  if command -v apt-get &>/dev/null; then
    apt-get update
    apt-get install -y python3-pip
  fi
  pip install --upgrade r128gain
fi

echo "Normalizing loudness in $MUSIC_DIR ..."
r128gain -r -a "$MUSIC_DIR"
echo "Done"
