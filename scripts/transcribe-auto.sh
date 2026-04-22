#!/usr/bin/env bash
# transcribe-auto.sh — умный роутер: автодетект языка и выбор бэкенда.
#
#   ru / en      → transcribe-file.sh   (whisper large-v3, как раньше)
#   kk / mix     → transcribe-kk.sh     (Qwen3-ASR / whisper-base.kk)
#
# Использование:
#   transcribe-auto.sh <file>           # автодетект
#   transcribe-auto.sh <file> <lang>    # форснуть язык
#
# Русские встречи идут строго по существующему пайплайну — ничего не меняется.

set -euo pipefail

if [ $# -eq 0 ]; then
    cat << EOF
Usage: $(basename "$0") <audio-or-video-file> [lang]

Языки:
  ru, en   → whisper large-v3 (обычный пайплайн)
  kk, mix  → Qwen3-ASR / whisper-base.kk (казахский / kk+ru смесь)
  auto     → автодетект по первым 30 сек (по умолчанию)
EOF
    exit 1
fi

INPUT="$1"
LANG="${2:-auto}"

[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$LANG" = "auto" ]; then
    echo "→ Определяю язык (первые 30 сек)..."
    LANG=$("$SCRIPT_DIR/detect-lang.sh" "$INPUT")
    echo "  ⟹ определён: $LANG"
fi

case "$LANG" in
    ru|en|de|fr|es|zh|ja)
        echo "→ Роутинг: whisper large-v3 ($LANG)"
        exec "$SCRIPT_DIR/transcribe-file.sh" "$INPUT" "$LANG"
        ;;
    kk|mix|tt|ky|uz|ba)
        echo "→ Роутинг: казахский бэкенд ($LANG)"
        exec "$SCRIPT_DIR/transcribe-kk.sh" "$INPUT" "$LANG"
        ;;
    *)
        echo "⚠ Неизвестный язык '$LANG' — fallback на whisper" >&2
        exec "$SCRIPT_DIR/transcribe-file.sh" "$INPUT" "$LANG"
        ;;
esac
