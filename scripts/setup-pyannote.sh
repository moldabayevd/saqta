#!/usr/bin/env bash
# setup-pyannote.sh — установка pyannote.audio v3 для diarization без 2 дорожек.
#
# Требует:
#   - Python 3.10+
#   - Apple Silicon (для MPS-ускорения, на CPU работает но медленнее)
#   - HuggingFace токен (бесплатный) — pyannote модели gated
#     https://huggingface.co/settings/tokens
#
# После установки в config.sh добавить:
#   HF_TOKEN="hf_..."

set -euo pipefail

VENV_DIR="$HOME/.config/saqta/.pyannote-venv"
SCRIPT_OUT="$HOME/.config/saqta/diarize.py"

echo "→ Создаю venv: $VENV_DIR"
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

pip install --quiet --upgrade pip
echo "→ Ставлю pyannote.audio (~5-10 мин)..."
pip install --quiet \
    "pyannote.audio>=3.1.0" \
    "torch" \
    "torchaudio" \
    "soundfile"

cat > "$SCRIPT_OUT" << 'PYEOF'
#!/usr/bin/env python3
"""diarize.py — speaker diarization через pyannote.audio v3.1+

Вход:  wav 16kHz mono
Выход: RTTM-формат разметки в stdout
       (start_time end_time SPEAKER_NN)
"""
import os
import sys
from pathlib import Path

import torch
from pyannote.audio import Pipeline

HF_TOKEN = os.environ.get("HF_TOKEN")
if not HF_TOKEN:
    print("[diarize] HF_TOKEN не задан в env. Pyannote модели gated.", file=sys.stderr)
    print("[diarize] https://huggingface.co/settings/tokens", file=sys.stderr)
    sys.exit(1)

DEVICE = "mps" if torch.backends.mps.is_available() else (
    "cuda" if torch.cuda.is_available() else "cpu"
)


def main():
    if len(sys.argv) < 2:
        print("Usage: diarize.py <audio.wav> [num_speakers]", file=sys.stderr)
        sys.exit(1)

    audio_path = Path(sys.argv[1])
    num_speakers = int(sys.argv[2]) if len(sys.argv) > 2 else None

    print(f"[diarize] loading pipeline on {DEVICE}...", file=sys.stderr)
    pipeline = Pipeline.from_pretrained(
        "pyannote/speaker-diarization-3.1",
        use_auth_token=HF_TOKEN,
    )
    pipeline.to(torch.device(DEVICE))

    print(f"[diarize] diarizing {audio_path}...", file=sys.stderr)
    kwargs = {}
    if num_speakers:
        kwargs["num_speakers"] = num_speakers

    diarization = pipeline(str(audio_path), **kwargs)

    # Печатаем в stdout простой формат для последующего парсинга
    for turn, _, speaker in diarization.itertracks(yield_label=True):
        print(f"{turn.start:.2f} {turn.end:.2f} {speaker}")


if __name__ == "__main__":
    main()
PYEOF

chmod +x "$SCRIPT_OUT"

echo ""
echo "✓ Готово!"
echo "  venv:    $VENV_DIR"
echo "  скрипт:  $SCRIPT_OUT"
echo ""
echo "Перед первым запуском:"
echo "  1. Получи бесплатный HF токен: https://huggingface.co/settings/tokens"
echo "  2. Прими условия gated модели:"
echo "     https://huggingface.co/pyannote/speaker-diarization-3.1"
echo "     https://huggingface.co/pyannote/segmentation-3.0"
echo "  3. Пропиши в ~/.config/saqta/config.sh:"
echo "     HF_TOKEN=\"hf_...\""
