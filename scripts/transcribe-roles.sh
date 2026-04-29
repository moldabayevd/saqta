#!/usr/bin/env bash
# transcribe-roles.sh — транскрибировать с разделением по спикерам.
# Берёт две аудио-дорожки из mp4 (mic + system) и собирает диалог:
#   **Я:** ...
#   **Собеседники:** ...

set -uo pipefail

CONFIG_FILE="$HOME/.config/saqta/config.sh"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

: "${WHISPER_MODEL:=$HOME/whisper-models/ggml-large-v3.bin}"
: "${WHISPER_LANG:=ru}"
: "${VAD_MODEL:=$HOME/whisper-models/ggml-silero-v5.1.2.bin}"
: "${PROMPT_FILE:=$HOME/.config/saqta/prompt.txt}"
: "${NOTIFY_SOUND:=Glass}"

# По умолчанию: 0 — system, 1 — microphone (как пишет QuickRecorder
# с включённым "Separate audio tracks"). Перебить переменной MIC_TRACK.
: "${MIC_TRACK:=1}"
: "${SYS_TRACK:=0}"

if [ $# -eq 0 ]; then
    echo "Usage: $(basename "$0") <video-file> [language]"
    exit 1
fi

INPUT="$1"
LANG="${2:-$WHISPER_LANG}"

[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }

basename=$(basename "$INPUT")
name="${basename%.*}"
dir=$(dirname "$INPUT")
if [ "$(basename "$dir")" = "$name" ]; then
    meeting_dir="$dir"
else
    meeting_dir="$dir/$name"
    mkdir -p "$meeting_dir"
    [ "$INPUT" != "$meeting_dir/$basename" ] && cp "$INPUT" "$meeting_dir/$basename"
fi
SOURCE="$meeting_dir/$basename"

nstreams=$(ffprobe -v error -select_streams a -show_entries stream=index \
                   -of csv=p=0 "$SOURCE" | wc -l | tr -d ' ')
if [ "$nstreams" -lt 2 ]; then
    echo "✗ В файле только $nstreams аудио-дорожка. Для ролей нужно 2." >&2
    echo "   Включи в QuickRecorder: Output → Record Microphone to Main Track = OFF" >&2
    exit 1
fi

mic_wav="$meeting_dir/_mic.wav"
sys_wav="$meeting_dir/_sys.wav"

extract_track() {
    local idx="$1"; local out="$2"
    if [ -f "$out" ] && [ -s "$out" ]; then
        echo "✓ $(basename "$out") уже извлечён"
    else
        echo "→ Извлекаю дорожку $idx → $(basename "$out")"
        ffmpeg -y -i "$SOURCE" -map "0:a:$idx" \
               -ar 16000 -ac 1 -c:a pcm_s16le "$out" 2>&1 | tail -2
    fi
}

extract_track "$MIC_TRACK" "$mic_wav"
extract_track "$SYS_TRACK" "$sys_wav"

vad_args=()
[ -f "$VAD_MODEL" ] && vad_args=(--vad --vad-model "$VAD_MODEL")
prompt_args=()
[ -f "$PROMPT_FILE" ] && [ -s "$PROMPT_FILE" ] && prompt_args=(--prompt "$(cat "$PROMPT_FILE")")

run_whisper() {
    local in_wav="$1"; local out_prefix="$2"; local label="$3"
    echo ""
    echo "→ Whisper [$label] $(basename "$in_wav")"
    whisper-cli -m "$WHISPER_MODEL" -l "$LANG" -pp -mc 0 \
                "${vad_args[@]}" "${prompt_args[@]}" \
                -f "$in_wav" --output-vtt -of "$out_prefix" 2>&1 \
        | grep -E "progress|whisper_print_timings:    total" \
        | sed "s/^/  [$label] /"
}

START=$(date +%s)
run_whisper "$mic_wav" "$meeting_dir/_mic" "MIC"
run_whisper "$sys_wav" "$meeting_dir/_sys" "SYS"
echo ""
echo "✓ Whisper закончил за $(( ($(date +%s) - START) / 60 ))m"

# --- Merge two VTT files into a single timestamped dialog ----------------

python3 - "$meeting_dir/_mic.vtt" "$meeting_dir/_sys.vtt" \
         "$meeting_dir/$name.md" "$name" "$LANG" "$basename" <<'PYEOF'
import re, sys, datetime

mic_vtt, sys_vtt, out_md, name, lang, basename = sys.argv[1:7]

def parse_vtt(path, label):
    if not path or not __import__("os").path.exists(path):
        return []
    text = open(path, encoding="utf-8").read()
    blocks = re.split(r"\n\s*\n", text.strip())
    out = []
    for b in blocks:
        m = re.search(r"(\d\d:\d\d:\d\d\.\d+)\s+-->\s+(\d\d:\d\d:\d\d\.\d+)\s*\n(.+)",
                      b, re.DOTALL)
        if not m: continue
        t = m.group(1)
        h, mn, s = t.split(":")
        secs = int(h) * 3600 + int(mn) * 60 + float(s)
        line = " ".join(x.strip() for x in m.group(3).splitlines() if x.strip())
        if line:
            out.append((secs, label, line))
    return out

segments = parse_vtt(mic_vtt, "Я") + parse_vtt(sys_vtt, "Собеседники")
segments.sort(key=lambda x: x[0])

date_iso  = datetime.date.today().isoformat()
date_full = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

with open(out_md, "w", encoding="utf-8") as f:
    f.write(f"---\ntitle: \"{name}\"\ndate: {date_iso}\nsource: saqta\n")
    f.write(f"language: {lang}\nspeakers: 2\ntags:\n  - meeting\n  - transcript\n")
    f.write(f"  - diarized\n---\n\n")
    f.write(f"# {name}\n\n**Дата:** {date_full}  \n")
    f.write(f"**Источник:** [`{basename}`]({basename})  \n")
    f.write(f"**Дорожки:** микрофон (Я) + системный звук (Собеседники)\n\n")
    f.write("## Диалог\n\n")
    last_label = None
    for secs, label, line in segments:
        ts = f"{int(secs//3600):02d}:{int(secs%3600//60):02d}:{int(secs%60):02d}"
        if label != last_label:
            if last_label is not None:
                f.write("\n")
            f.write(f"**[{ts}] {label}:** {line}\n")
            last_label = label
        else:
            f.write(f"{line}\n")

print(f"✓ Markdown собран: {out_md}")
PYEOF

# Cleanup intermediate
rm -f "$meeting_dir/_mic.wav" "$meeting_dir/_sys.wav"
rm -f "$meeting_dir/_mic.vtt" "$meeting_dir/_sys.vtt"

terminal-notifier -title "Saqta ✓" \
    -message "Готов диалог: $name" \
    -sound "$NOTIFY_SOUND" \
    -execute "open '$meeting_dir'" 2>/dev/null || true

echo ""
echo "✓ Готово: $meeting_dir/$name.md"
echo ""
echo "Если роли перепутаны (системный звук — это ты, а микрофон — собеседник),"
echo "перезапусти с MIC_TRACK=0 SYS_TRACK=1 $(basename "$0") '$INPUT'"
