#!/usr/bin/env bash
# setup-qwen3.sh — установка Qwen3-ASR для казахско-русских встреч.
# Ставит зависимости в venv и кладёт рабочий скрипт в ~/.config/kt-recorder/qwen3_asr.py
#
# Требования: Python 3.10+, Apple Silicon (для MLX-ускорения). Работает и на CPU.

set -euo pipefail

VENV_DIR="$HOME/.config/kt-recorder/.qwen3-venv"
SCRIPT_OUT="$HOME/.config/kt-recorder/qwen3_asr.py"

mkdir -p "$(dirname "$SCRIPT_OUT")"

echo "→ Создаю venv: $VENV_DIR"
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

pip install --quiet --upgrade pip
echo "→ Ставлю зависимости (transformers, torch, soundfile)..."
pip install --quiet \
    "transformers>=4.45" \
    "torch" \
    "torchaudio" \
    "soundfile" \
    "librosa" \
    "accelerate"

cat > "$SCRIPT_OUT" << 'PYEOF'
#!/usr/bin/env python3
"""
qwen3_asr.py — обёртка над Qwen3-ASR для kt-recorder.

Вход:  wav 16kHz mono
Выход: plain text в stdout

Использование:
    python qwen3_asr.py <audio.wav> [lang]
"""
import os
import sys
from pathlib import Path

import soundfile as sf
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor
import torch

MODEL_ID = os.environ.get("QWEN3_ASR_MODEL", "Qwen/Qwen3-ASR-1.7B")
DEVICE = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
DTYPE = torch.float16 if DEVICE != "cpu" else torch.float32


def main():
    if len(sys.argv) < 2:
        print("Usage: qwen3_asr.py <audio.wav> [lang]", file=sys.stderr)
        sys.exit(1)

    audio_path = Path(sys.argv[1])
    lang = sys.argv[2] if len(sys.argv) > 2 else "kk"

    audio, sr = sf.read(str(audio_path))
    assert sr == 16000, f"expected 16kHz, got {sr}"

    print(f"[qwen3] loading {MODEL_ID} on {DEVICE}...", file=sys.stderr)
    processor = AutoProcessor.from_pretrained(MODEL_ID)
    model = AutoModelForSpeechSeq2Seq.from_pretrained(
        MODEL_ID, torch_dtype=DTYPE
    ).to(DEVICE)
    model.eval()

    # Qwen3-ASR поддерживает language ID внутри. Если передан конкретный
    # lang — подскажем его как hint, но модель может переключаться на лету
    # для code-switching (kk+ru).
    inputs = processor(
        audio=audio,
        sampling_rate=16000,
        language=lang if lang != "mix" else None,
        return_tensors="pt",
    ).to(DEVICE, dtype=DTYPE)

    with torch.no_grad():
        generated = model.generate(
            **inputs,
            max_new_tokens=440,
            do_sample=False,
        )

    text = processor.batch_decode(generated, skip_special_tokens=True)[0]
    print(text.strip())


if __name__ == "__main__":
    main()
PYEOF

chmod +x "$SCRIPT_OUT"

echo ""
echo "✓ Готово!"
echo "  venv:    $VENV_DIR"
echo "  скрипт:  $SCRIPT_OUT"
echo ""
echo "Первый запуск скачает модель Qwen3-ASR-1.7B (~4 GB) в ~/.cache/huggingface"
echo ""
echo "Пропиши в ~/.config/kt-recorder/config.sh:"
echo "  KK_BACKEND=\"qwen3\""
echo "  QWEN3_ASR_SCRIPT=\"$SCRIPT_OUT\""
echo ""
echo "И убедись что transcribe-kk.sh зовёт python из venv:"
echo "  export PATH=\"$VENV_DIR/bin:\$PATH\""
