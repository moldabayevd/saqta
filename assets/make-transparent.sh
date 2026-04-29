#!/usr/bin/env bash
# make-transparent.sh — делает прозрачный вариант логотипа для README.
# Убирает кремовый фон #F5F0E1, оставляя только медальон + микрофон + завиток.
#
# Использование:
#   bash assets/make-transparent.sh
#
# Результат: assets/saqta-logo-transparent.png
# (используется в README, GitHub social preview и dark-theme контекстах)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="$SCRIPT_DIR/saqta-logo.png"
OUTPUT="$SCRIPT_DIR/saqta-logo-transparent.png"

[ -f "$INPUT" ] || { echo "✗ Не найден: $INPUT" >&2; exit 1; }

if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
    echo "✗ Нужен ImageMagick: brew install imagemagick" >&2
    exit 1
fi
MAGICK="magick"
command -v magick >/dev/null 2>&1 || MAGICK="convert"

echo "→ Удаляю кремовый фон, делаю прозрачный..."

# Fuzzy replace cream/ivory pixels (#F5F0E1, #FAF6E8, и близкие оттенки)
# с допуском 12% — захватывает мелкие отклонения градиента/JPG-артефакты
$MAGICK "$INPUT" \
        -fuzz 12% \
        -fill none \
        -draw 'matte 0,0 floodfill' \
        -draw 'matte 0,1023 floodfill' \
        -draw 'matte 1023,0 floodfill' \
        -draw 'matte 1023,1023 floodfill' \
        "$OUTPUT"

echo "✓ Готово: $OUTPUT"
echo ""
echo "Проверь визуально — должен остаться только дизайн без кремового фона."
echo "Если появились артефакты внутри (например, прозрачные пятна на микрофоне),"
echo "лучше перегенери через Nano Banano с явным указанием transparent background."
