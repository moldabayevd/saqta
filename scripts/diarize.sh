#!/usr/bin/env bash
# diarize.sh — speaker diarization без двух дорожек.
# Берёт mp4/mp3/wav и .vtt транскрипт, склеивает в .md где каждый сегмент
# подписан спикером:
#
#   **Спикер 1:** Бла бла бла
#   **Спикер 2:** Ответ
#
# Использование:
#   diarize.sh <audio.mp4> <transcript.vtt> [num_speakers]
#
# Без num_speakers pyannote сам определит количество.

set -euo pipefail

if [ $# -lt 2 ]; then
    cat << EOF
Usage: $(basename "$0") <audio.mp4|wav> <transcript.vtt> [num_speakers]

Требует:
  - bash scripts/setup-pyannote.sh  (один раз)
  - HF_TOKEN в config.sh или env
EOF
    exit 1
fi

AUDIO="$1"
VTT="$2"
NUM_SPEAKERS="${3:-}"

[ -f "$AUDIO" ] || { echo "✗ Аудио не найдено: $AUDIO" >&2; exit 1; }
[ -f "$VTT" ]   || { echo "✗ VTT не найден: $VTT" >&2; exit 1; }

CONFIG_FILE="$HOME/.config/saqta/config.sh"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

VENV_DIR="$HOME/.config/saqta/.pyannote-venv"
DIARIZE_SCRIPT="$HOME/.config/saqta/diarize.py"

[ -d "$VENV_DIR" ] || { echo "✗ Pyannote не установлен. bash scripts/setup-pyannote.sh" >&2; exit 1; }
[ -n "${HF_TOKEN:-}" ] || { echo "✗ HF_TOKEN не задан" >&2; exit 1; }

# 1. Извлекаем wav из аудио
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
wav="$tmp/audio.wav"
echo "→ Извлекаю аудио..."
ffmpeg -y -v error -i "$AUDIO" -ar 16000 -ac 1 -c:a pcm_s16le "$wav"

# 2. Diarization
echo "→ Diarization (pyannote.audio v3.1)..."
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
export HF_TOKEN
rttm_file="$tmp/diarization.txt"
if [ -n "$NUM_SPEAKERS" ]; then
    python3 "$DIARIZE_SCRIPT" "$wav" "$NUM_SPEAKERS" > "$rttm_file"
else
    python3 "$DIARIZE_SCRIPT" "$wav" > "$rttm_file"
fi
deactivate

# 3. Склеиваем VTT с разметкой по спикерам
out_md="${VTT%.vtt}-diarized.md"
echo "→ Склеиваю с транскриптом..."

python3 << PYEOF > "$out_md"
import re
from pathlib import Path

# Парсим pyannote вывод: "start end SPEAKER_XX"
turns = []
with open("$rttm_file") as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 3:
            turns.append((float(parts[0]), float(parts[1]), parts[2]))

# Парсим VTT: cue блоки "00:01:23.456 --> 00:01:30.789\nText"
vtt_text = Path("$VTT").read_text()
cues = []
for m in re.finditer(r"(\d+):(\d+):(\d+)\.(\d+)\s*-->\s*(\d+):(\d+):(\d+)\.(\d+)\s*\n([^\n]+)", vtt_text):
    start = int(m.group(1))*3600 + int(m.group(2))*60 + int(m.group(3)) + int(m.group(4))/1000
    end   = int(m.group(5))*3600 + int(m.group(6))*60 + int(m.group(7)) + int(m.group(8))/1000
    cues.append((start, end, m.group(9).strip()))

# Для каждой VTT-фразы находим overlap с pyannote turns, выбираем доминирующего спикера
def speaker_for(start, end):
    best = None
    best_overlap = 0.0
    for ts, te, sp in turns:
        ov = max(0, min(end, te) - max(start, ts))
        if ov > best_overlap:
            best_overlap = ov
            best = sp
    return best or "UNKNOWN"

# Группируем подряд идущие фразы одного спикера
print("# Транскрипт с разделением по спикерам\n")
current_speaker = None
buffer = []
for s, e, txt in cues:
    sp = speaker_for(s, e)
    if sp != current_speaker:
        if buffer:
            print(f"**{current_speaker}:** " + " ".join(buffer) + "\n")
        current_speaker = sp
        buffer = [txt]
    else:
        buffer.append(txt)
if buffer:
    print(f"**{current_speaker}:** " + " ".join(buffer))
PYEOF

echo "✓ Готово: $out_md"
