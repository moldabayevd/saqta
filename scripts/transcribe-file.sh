#!/usr/bin/env bash
# transcribe-file.sh — транскрибировать конкретный файл без watcher
# Использование:
#   transcribe-file.sh <file>                # язык из конфига
#   transcribe-file.sh <file> <lang>         # с переопределением языка

set -euo pipefail

usage() {
    cat << EOF
Использование: $(basename "$0") <audio-or-video-file> [language]

Примеры:
  $(basename "$0") ~/Downloads/meeting.mp4
  $(basename "$0") ~/Recordings/old.m4a en

Языки: ru, en, de, fr, es, auto, ... (полный список — docs Whisper)
EOF
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

CONFIG_FILE="$HOME/.config/saqta/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "✗ Config not found: $CONFIG_FILE" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${WHISPER_MODEL:=$HOME/whisper-models/ggml-large-v3.bin}"
: "${WHISPER_LANG:=ru}"
: "${OUTPUT_FORMATS:=txt,vtt}"
: "${VAD_MODEL:=$HOME/whisper-models/ggml-silero-v5.1.2.bin}"
: "${PROMPT_FILE:=$HOME/.config/saqta/prompt.txt}"

INPUT="$1"
LANG="${2:-$WHISPER_LANG}"

if [ ! -f "$INPUT" ]; then
    echo "✗ Файл не найден: $INPUT" >&2
    exit 1
fi

basename=$(basename "$INPUT")
name="${basename%.*}"
dir=$(dirname "$INPUT")
meeting_dir="$dir/$name"

mkdir -p "$meeting_dir"
if [ "$INPUT" != "$meeting_dir/$basename" ]; then
    cp "$INPUT" "$meeting_dir/$basename"
fi

audio_wav="$meeting_dir/_audio.wav"
nstreams=$(ffprobe -v error -select_streams a -show_entries stream=index \
                   -of csv=p=0 "$meeting_dir/$basename" | wc -l | tr -d ' ')

if [ "$nstreams" -gt 1 ]; then
    echo "→ Извлекаю аудио (микширую $nstreams дорожки)..."
    ffmpeg -y -i "$meeting_dir/$basename" \
           -filter_complex "amix=inputs=$nstreams:duration=longest:normalize=0" \
           -ar 16000 -ac 1 -c:a pcm_s16le "$audio_wav" 2>&1 | tail -3
else
    echo "→ Извлекаю аудио..."
    ffmpeg -y -i "$meeting_dir/$basename" \
           -ar 16000 -ac 1 -c:a pcm_s16le "$audio_wav" 2>&1 | tail -3
fi

format_flags=()
IFS=',' read -ra FORMATS <<< "$OUTPUT_FORMATS"
for fmt in "${FORMATS[@]}"; do
    case "$fmt" in
        txt)  format_flags+=(--output-txt) ;;
        vtt)  format_flags+=(--output-vtt) ;;
        srt)  format_flags+=(--output-srt) ;;
        json) format_flags+=(--output-json) ;;
    esac
done

vad_args=()
[ -f "$VAD_MODEL" ] && vad_args=(--vad --vad-model "$VAD_MODEL")
prompt_args=()
[ -f "$PROMPT_FILE" ] && [ -s "$PROMPT_FILE" ] && prompt_args=(--prompt "$(cat "$PROMPT_FILE")")

echo "→ Транскрибирую (язык: $LANG)..."
whisper-cli -m "$WHISPER_MODEL" -l "$LANG" -pp -mc 0 \
            "${vad_args[@]}" "${prompt_args[@]}" \
            -f "$audio_wav" \
            "${format_flags[@]}" \
            -of "$meeting_dir/_transcript"

rm -f "$audio_wav"

# Generate Markdown
md_file="$meeting_dir/$name.md"
date_str=$(date '+%Y-%m-%d %H:%M')
date_iso=$(date '+%Y-%m-%d')

{
    echo "---"
    echo "title: \"$name\""
    echo "date: $date_iso"
    echo "source: saqta"
    echo "language: $LANG"
    echo "tags:"
    echo "  - meeting"
    echo "  - transcript"
    echo "---"
    echo ""
    echo "# $name"
    echo ""
    echo "**Дата:** $date_str  "
    echo "**Видео:** [\`$basename\`]($basename)  "
    echo ""
    echo "## Транскрипт"
    echo ""
    [ -f "$meeting_dir/_transcript.txt" ] && cat "$meeting_dir/_transcript.txt"
} > "$md_file"

rm -f "$meeting_dir/_transcript.txt"

echo ""
echo "✓ Готово: $meeting_dir"
ls -la "$meeting_dir"
