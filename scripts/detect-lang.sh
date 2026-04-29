#!/usr/bin/env bash
# detect-lang.sh — определить язык записи по первым 30 секундам.
# Печатает один из: ru, en, kk, mix, auto
#
# Использование:
#   detect-lang.sh <audio-or-video-file>

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $(basename "$0") <audio-or-video-file>" >&2
    exit 1
fi

INPUT="$1"
[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }

CONFIG_FILE="$HOME/.config/saqta/config.sh"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

: "${WHISPER_MODEL:=$HOME/whisper-models/ggml-large-v3.bin}"
: "${DETECT_SAMPLE_SECONDS:=30}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

sample_wav="$tmpdir/sample.wav"

# Берём первые N секунд, моно 16kHz
ffmpeg -y -v error -i "$INPUT" -t "$DETECT_SAMPLE_SECONDS" \
       -ar 16000 -ac 1 -c:a pcm_s16le "$sample_wav" >/dev/null 2>&1

# whisper-cli --detect-language печатает в stderr что-то вроде:
#   whisper_full_with_state: auto-detected language: ru (p = 0.98)
detect_out=$(whisper-cli -m "$WHISPER_MODEL" -f "$sample_wav" --detect-language 2>&1 || true)

lang=$(echo "$detect_out" | grep -oE "auto-detected language: [a-z]+" | awk '{print $3}' | head -1)

# Карта whisper-кодов в наши категории.
# kk → казахский (whisper.cpp поддерживает этот код).
# Если whisper ошибается между ru/kk в казахской речи — часто даёт "tt", "ba" или низкий confidence.
case "$lang" in
    ru|uk|be) echo "ru" ;;
    kk|tt|ky|uz|ba) echo "kk" ;;
    en) echo "en" ;;
    "") echo "auto" ;;
    *)  echo "$lang" ;;
esac
