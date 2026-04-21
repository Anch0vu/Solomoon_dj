#!/usr/bin/env bash
# Прогон один раз после заливки новой музыки.
# Записывает EBU R128 теги в файлы — liquidsoap'у не придётся нормализовать в реалтайме.
#
# Установка: pip install r128gain
set -euo pipefail

MUSIC_DIR="${1:-./music}"

if ! command -v r128gain &>/dev/null; then
  echo "Ставлю r128gain..."
  pip install --user r128gain
fi

echo "Нормализую loudness в $MUSIC_DIR ..."
r128gain -r -a "$MUSIC_DIR"
echo "✓ Готово"
