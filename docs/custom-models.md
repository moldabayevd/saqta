# Кастомные модели Whisper

По умолчанию Saqta использует `ggml-large-v3.bin` — универсальную модель от OpenAI. Для улучшения качества на конкретных языках, доменах или ускорения можно подключить другую.

## Официальные ggml-модели

Все совместимые с whisper.cpp модели лежат в [ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main) на HuggingFace.

| Модель | Размер | Когда использовать |
|--------|--------|-------------------|
| `ggml-large-v3.bin` | 3.1 ГБ | Универсальная, хороший русский (по умолчанию) |
| `ggml-large-v3-turbo.bin` | 1.6 ГБ | В 2-3× быстрее, качество чуть ниже |
| `ggml-medium.bin` | 1.5 ГБ | Компромисс для 8 ГБ RAM |
| `ggml-large-v3-q5_0.bin` | 1.1 ГБ | Квантованная, ~95% качества Large-v3 |
| `ggml-small.bin` | 488 МБ | Для быстрых черновых расшифровок |

Скачать любую:

```bash
cd ~/whisper-models
curl -L -O https://huggingface.co/ggerganov/whisper.cpp/resolve/main/MODEL_NAME.bin
```

Потом в `~/.config/saqta/config.sh`:

```bash
WHISPER_MODEL="$HOME/whisper-models/MODEL_NAME.bin"
```

## Русский fine-tune (рекомендуется для рус. встреч)

[`antony66/whisper-large-v3-russian`](https://huggingface.co/antony66/whisper-large-v3-russian) — заточен под русский, WER ~6% на Common Voice против ~10% у базового Large-v3. Особенно хорош на разговорной речи и именах собственных.

GGML-версия для whisper.cpp:

```bash
cd ~/whisper-models
curl -L -o ggml-large-v3-russian.bin \
  https://huggingface.co/Limtech/whisper-large-v3-russian-ggml/resolve/main/ggml-model.bin
```

Обнови конфиг:

```bash
WHISPER_MODEL="$HOME/whisper-models/ggml-large-v3-russian.bin"
```

Перезапусти watcher:

```bash
launchctl kickstart -k gui/$(id -u)/com.saqta.autotranscribe
```

## Другие языки

В `~/.config/saqta/config.sh` меняешь `WHISPER_LANG`:

- `en` — английский
- `de` — немецкий
- `fr` — французский
- `es` — испанский
- `zh` — китайский
- `auto` — автодетект (не рекомендуется для смешанной речи, Whisper часто промахивается)

Полный список — [в документации Whisper](https://github.com/openai/whisper#available-models-and-languages).

## 🇰🇿 Казахский / kk+ru code-switching

Если встречи идут на казахском, или смешиваются kk+ru в одной фразе — vanilla
`ggml-large-v3` выдаёт WER 30-77% (подтверждено свежими бенчмарками MDPI 2025).
Не юзабельно. Решение: отдельный бэкенд только для казахских записей, русские
встречи остаются на текущем whisper-пайплайне без изменений.

### Роутер

`scripts/transcribe-auto.sh` автодетектит язык по первым 30 сек и кидает файл
на нужный бэкенд:

```
ru / en / de / fr / ...  → transcribe-file.sh (whisper large-v3, без изменений)
kk / mix / tt / ky / uz  → transcribe-kk.sh  (Qwen3-ASR или whisper-base.kk)
```

### Вариант A — Qwen3-ASR-1.7B (рекомендуется для kk+ru микса)

Специально умеет code-switching (переключение языка внутри фразы). Лучший
выбор если на встрече реально говорят «қазақша сөйлеп тұрып кинули английское
слово».

```bash
bash scripts/setup-qwen3.sh
# поставит venv в ~/.config/saqta/.qwen3-venv
# и qwen3_asr.py в ~/.config/saqta/

# в config.sh:
KK_BACKEND="qwen3"
```

Первый запуск скачает модель (~4 GB) в `~/.cache/huggingface`. На M4 Pro
работает быстрее реалтайма.

### Вариант B — whisper-base.kk (чистый казахский)

Если встречи **только** на казахском, без русских вставок — быстрее и точнее
Qwen3.

```bash
# скачать и сконвертить в ggml
git lfs install
git clone https://huggingface.co/akuzdeuov/whisper-base.kk /tmp/kk-model
python ~/whisper.cpp/models/convert-h5-to-ggml.py \
       /tmp/kk-model \
       ~/whisper-models/ggml-base-kk.bin

# в config.sh:
KK_BACKEND="whisper-kk"
```

WER 15.36% на KSC2 test set. Русские слова мангалит — не для смешанных встреч.

### Вариант C — baseline (ничего не ставить)

В `config.sh`:
```bash
KK_BACKEND="whisper"
```

Будет использовать твой основной `WHISPER_MODEL` с флагом `-l kk`. Качество
слабое, но работает прямо сейчас без лишних зависимостей.

### Использование

```bash
# автодетект — сам выберет бэкенд
./scripts/transcribe-auto.sh ~/Recordings/meeting.mp4

# форснуть казахский
./scripts/transcribe-auto.sh ~/Recordings/meeting.mp4 kk

# форснуть русский (пойдёт по старому пайплайну)
./scripts/transcribe-auto.sh ~/Recordings/meeting.mp4 ru
```

## CoreML-ускорение (опционально)

На Apple Silicon whisper.cpp может использовать Apple Neural Engine через CoreML-обёртки моделей — это даёт прирост ~3× к Metal.

```bash
cd ~/whisper-models
curl -L -O https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-encoder.mlmodelc.zip
unzip ggml-large-v3-encoder.mlmodelc.zip
rm ggml-large-v3-encoder.mlmodelc.zip
```

CoreML-файл должен лежать рядом с ggml-бинарником и называться так же (с суффиксом `-encoder.mlmodelc`). whisper.cpp подхватит автоматически при первом запуске.

> ⚠️ При первом запуске с CoreML macOS будет компилировать модель под твой чип — это займёт 2-5 минут. Следующие запуски моментально.
