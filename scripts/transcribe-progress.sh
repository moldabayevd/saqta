#!/usr/bin/env bash
# transcribe-progress.sh — транскрибировать файл с visual progress bar
# Использование:
#   transcribe-progress.sh <file>           # язык из конфига
#   transcribe-progress.sh <file> <lang>

set -uo pipefail

CONFIG_FILE="$HOME/.config/saqta/config.sh"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

: "${WHISPER_MODEL:=$HOME/whisper-models/ggml-large-v3.bin}"
: "${WHISPER_LANG:=ru}"
: "${OUTPUT_FORMATS:=txt,vtt}"
: "${NOTIFY_SOUND:=Glass}"
: "${VAD_MODEL:=$HOME/whisper-models/ggml-silero-v5.1.2.bin}"
: "${PROMPT_FILE:=$HOME/.config/saqta/prompt.txt}"

if [ $# -eq 0 ]; then
    echo "Usage: $(basename "$0") <audio-or-video-file> [language]"
    exit 1
fi

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

# Если файл уже в meeting_dir — пользуемся им, иначе перемещаем
if [ "$dir" = "$meeting_dir" ] || [ "$(basename "$dir")" = "$name" ]; then
    meeting_dir="$dir"
else
    mkdir -p "$meeting_dir"
    if [ "$INPUT" != "$meeting_dir/$basename" ]; then
        cp "$INPUT" "$meeting_dir/$basename"
    fi
fi

audio_wav="$meeting_dir/_audio.wav"
SOURCE_FILE="$meeting_dir/$basename"
[ -f "$SOURCE_FILE" ] || SOURCE_FILE="$INPUT"

# --- Step 1: extract / mix audio ------------------------------------------

if [ -f "$audio_wav" ] && [ -s "$audio_wav" ]; then
    echo "✓ Аудио уже извлечено: $audio_wav"
else
    nstreams=$(ffprobe -v error -select_streams a -show_entries stream=index \
                       -of csv=p=0 "$SOURCE_FILE" | wc -l | tr -d ' ')
    if [ "$nstreams" -gt 1 ]; then
        echo "→ Микширую $nstreams аудио-дорожки..."
        ffmpeg -y -i "$SOURCE_FILE" \
               -filter_complex "amix=inputs=$nstreams:duration=longest:normalize=0" \
               -ar 16000 -ac 1 -c:a pcm_s16le "$audio_wav" 2>&1 | tail -2
    else
        echo "→ Извлекаю аудио..."
        ffmpeg -y -i "$SOURCE_FILE" -ar 16000 -ac 1 -c:a pcm_s16le \
               "$audio_wav" 2>&1 | tail -2
    fi
fi

# --- Step 2: whisper with progress bar ------------------------------------

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

# Длительность для ETA
duration_sec=$(ffprobe -v error -show_entries format=duration \
                       -of csv=p=0 "$audio_wav" 2>/dev/null | cut -d. -f1)
duration_sec=${duration_sec:-0}

START_TS=$(date +%s)
NOTIFIED_QUARTERS=""

draw_bar() {
    local pct=$1
    local width=40
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    local elapsed=$(( $(date +%s) - START_TS ))
    local eta_str="—"
    if [ "$pct" -gt 0 ]; then
        local total_est=$(( elapsed * 100 / pct ))
        local remaining=$(( total_est - elapsed ))
        if [ "$remaining" -gt 0 ]; then
            eta_str="$(( remaining / 60 ))m $(( remaining % 60 ))s"
        fi
    fi

    printf "\r\033[K  [%s] %3d%%  elapsed %dm%02ds  ETA %s" \
        "$bar" "$pct" "$((elapsed/60))" "$((elapsed%60))" "$eta_str"
}

notify_quarter() {
    local pct=$1
    local quarter=$(( pct / 25 ))
    if [ "$quarter" -gt 0 ] && [[ "$NOTIFIED_QUARTERS" != *"|$quarter|"* ]]; then
        NOTIFIED_QUARTERS+="|$quarter|"
        local milestone=$(( quarter * 25 ))
        terminal-notifier -title "Saqta" \
            -message "Транскрипция: ${milestone}%" \
            -sound default 2>/dev/null || true
    fi
}

echo ""
echo "→ Whisper: $name"
echo "  Аудио:    ${duration_sec}s ($(( duration_sec / 60 ))m)"
echo "  Модель:   $(basename "$WHISPER_MODEL")"
echo "  Язык:     $LANG"
echo ""

vad_args=()
[ -f "$VAD_MODEL" ] && vad_args=(--vad --vad-model "$VAD_MODEL")
prompt_args=()
[ -f "$PROMPT_FILE" ] && [ -s "$PROMPT_FILE" ] && prompt_args=(--prompt "$(cat "$PROMPT_FILE")")

# Pipe whisper stderr через парсер
{
    whisper-cli -m "$WHISPER_MODEL" -l "$LANG" -pp -mc 0 \
                "${vad_args[@]}" "${prompt_args[@]}" \
                -f "$audio_wav" \
                "${format_flags[@]}" \
                -of "$meeting_dir/_transcript" 2>&1
    echo "__WHISPER_DONE__:$?"
} | while IFS= read -r line; do
    if [[ "$line" =~ progress\ =\ +([0-9]+)% ]]; then
        pct="${BASH_REMATCH[1]}"
        draw_bar "$pct"
        notify_quarter "$pct"
    elif [[ "$line" =~ ^__WHISPER_DONE__:([0-9]+) ]]; then
        WSTATUS="${BASH_REMATCH[1]}"
        if [ "$WSTATUS" = "0" ]; then
            draw_bar 100
            echo ""
            echo ""
            echo "✓ Whisper завершён за $(( $(date +%s) - START_TS ))s"
        else
            echo ""
            echo "✗ Whisper упал с кодом $WSTATUS" >&2
            exit "$WSTATUS"
        fi
    fi
done

# --- Step 3: assemble markdown --------------------------------------------

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
    echo "**Источник:** [\`$basename\`]($basename)  "
    echo ""
    echo "## Транскрипт"
    echo ""
    [ -f "$meeting_dir/_transcript.txt" ] && cat "$meeting_dir/_transcript.txt"
} > "$md_file"

rm -f "$meeting_dir/_transcript.txt" "$audio_wav"

terminal-notifier -title "Saqta ✓" \
    -message "Готово: $name" \
    -sound "$NOTIFY_SOUND" \
    -execute "open '$meeting_dir'" 2>/dev/null || true

echo ""
echo "✓ Готово: $meeting_dir"
ls -lh "$meeting_dir/"
echo ""
echo "Открыть: open '$meeting_dir'"
