#!/usr/bin/env bash
# transcribe-kk.sh — транскрибация казахского / kk+ru code-switching.
#
# Бэкенды (выбор через KK_BACKEND в config.sh):
#   qwen3     — Qwen3-ASR-1.7B через Python (лучше всего для kk+ru микса)
#   whisper-kk — whisper-base.kk (dotюн akuzdeuov/whisper-base.kk) для чистого казахского
#   whisper   — fallback на обычный whisper large-v3 с -l kk (baseline)
#
# Использование:
#   transcribe-kk.sh <file> [lang]
#
# Результат кладёт рядом с исходником в папку <name>/ с _transcript.txt и <name>.md
# — совместимо со всем проектом (transcribe-roles.sh и др.).

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $(basename "$0") <audio-or-video-file> [lang]" >&2
    exit 1
fi

INPUT="$1"
LANG="${2:-kk}"

[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }

CONFIG_FILE="$HOME/.config/kt-recorder/config.sh"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

: "${KK_BACKEND:=qwen3}"
: "${QWEN3_ASR_SCRIPT:=$HOME/.config/kt-recorder/qwen3_asr.py}"
: "${WHISPER_KK_MODEL:=$HOME/whisper-models/ggml-base-kk.bin}"
: "${WHISPER_MODEL:=$HOME/whisper-models/ggml-large-v3.bin}"
: "${VAD_MODEL:=$HOME/whisper-models/ggml-silero-v5.1.2.bin}"
: "${PROMPT_FILE:=$HOME/.config/kt-recorder/prompt.txt}"

basename=$(basename "$INPUT")
name="${basename%.*}"
dir=$(dirname "$INPUT")
meeting_dir="$dir/$name"
mkdir -p "$meeting_dir"
[ "$INPUT" != "$meeting_dir/$basename" ] && cp "$INPUT" "$meeting_dir/$basename"

audio_wav="$meeting_dir/_audio.wav"
echo "→ Извлекаю аудио (16 kHz mono)..."
ffmpeg -y -v error -i "$meeting_dir/$basename" \
       -ar 16000 -ac 1 -c:a pcm_s16le "$audio_wav"

transcript_txt="$meeting_dir/_transcript.txt"

case "$KK_BACKEND" in
    qwen3)
        if [ ! -f "$QWEN3_ASR_SCRIPT" ]; then
            echo "✗ Qwen3 скрипт не найден: $QWEN3_ASR_SCRIPT" >&2
            echo "  Запусти: bash scripts/setup-qwen3.sh" >&2
            exit 1
        fi
        echo "→ Qwen3-ASR (code-switching kk+ru)..."
        python3 "$QWEN3_ASR_SCRIPT" "$audio_wav" "$LANG" > "$transcript_txt"
        ;;
    whisper-kk)
        [ -f "$WHISPER_KK_MODEL" ] || {
            echo "✗ Казахская модель не найдена: $WHISPER_KK_MODEL" >&2
            echo "  Скачай: см. docs/custom-models.md секцию «Казахский»" >&2
            exit 1
        }
        echo "→ whisper-base.kk (чистый казахский)..."
        vad_args=()
        [ -f "$VAD_MODEL" ] && vad_args=(--vad --vad-model "$VAD_MODEL")
        whisper-cli -m "$WHISPER_KK_MODEL" -l kk -pp -mc 0 \
                    "${vad_args[@]}" \
                    -f "$audio_wav" \
                    --output-txt \
                    -of "$meeting_dir/_transcript"
        ;;
    whisper)
        echo "→ whisper large-v3 fallback (lang=$LANG)..."
        vad_args=()
        [ -f "$VAD_MODEL" ] && vad_args=(--vad --vad-model "$VAD_MODEL")
        prompt_args=()
        [ -f "$PROMPT_FILE" ] && [ -s "$PROMPT_FILE" ] && prompt_args=(--prompt "$(cat "$PROMPT_FILE")")
        whisper-cli -m "$WHISPER_MODEL" -l "$LANG" -pp -mc 0 \
                    "${vad_args[@]}" "${prompt_args[@]}" \
                    -f "$audio_wav" \
                    --output-txt \
                    -of "$meeting_dir/_transcript"
        ;;
    *)
        echo "✗ Неизвестный KK_BACKEND: $KK_BACKEND" >&2
        echo "  Допустимо: qwen3 | whisper-kk | whisper" >&2
        exit 1
        ;;
esac

rm -f "$audio_wav"

# Markdown
md_file="$meeting_dir/$name.md"
date_str=$(date '+%Y-%m-%d %H:%M')
date_iso=$(date '+%Y-%m-%d')
{
    echo "---"
    echo "title: \"$name\""
    echo "date: $date_iso"
    echo "source: kt-recorder"
    echo "language: $LANG"
    echo "backend: $KK_BACKEND"
    echo "tags:"
    echo "  - meeting"
    echo "  - transcript"
    echo "  - kazakh"
    echo "---"
    echo ""
    echo "# $name"
    echo ""
    echo "**Дата:** $date_str  "
    echo "**Видео:** [\`$basename\`]($basename)  "
    echo "**Язык:** $LANG (бэкенд: $KK_BACKEND)"
    echo ""
    echo "## Транскрипт"
    echo ""
    [ -f "$transcript_txt" ] && cat "$transcript_txt"
} > "$md_file"

rm -f "$transcript_txt"

echo ""
echo "✓ Готово: $meeting_dir"
