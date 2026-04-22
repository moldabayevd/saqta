# 🖥️ Продолжить работу на Mac

Короткая шпаргалка — что сделать завтра, когда сядешь за мак.

## 1. Склонировать репо

```bash
cd ~/Projects   # или куда удобно
git clone https://github.com/moldabayevd/kt-recorder.git
cd kt-recorder
```

## 2. Настроить git (если ещё не)

```bash
git config user.name "moldabayevd"
git config user.email "moldabayevd@users.noreply.github.com"
```

Проверь что `gh` авторизован:

```bash
gh auth status
# если нет:
gh auth login
```

## 3. Установить зависимости

Нужны: **Homebrew**, **ffmpeg**, **whisper.cpp**, **BlackHole** (для захвата системного звука).

```bash
# Homebrew (если нет)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Зависимости
brew install ffmpeg
brew install --cask blackhole-2ch

# whisper.cpp
git clone https://github.com/ggml-org/whisper.cpp ~/whisper.cpp
cd ~/whisper.cpp && make -j && bash ./models/download-ggml-model.sh large-v3
```

## 4. Запустить установщик проекта

```bash
cd ~/Projects/kt-recorder
./install.sh
```

Скрипт настроит пути, launchagent и хоткеи. Если что-то сломается — см. [docs/troubleshooting.md](docs/troubleshooting.md).

## 5. Проверить что работает

```bash
# тестовая транскрибация любого аудио
./scripts/transcribe-file.sh path/to/test.m4a
```

## 6. Рабочий цикл

```bash
git pull                    # подтянуть изменения (если правил с другой машины)
# ... правишь код ...
git add -A
git commit -m "описание"
git push
```

## 🇰🇿 Казахские / смешанные kk+ru встречи

Роутер уже добавлен — `scripts/transcribe-auto.sh` автодетектит язык и
раскидывает по бэкендам: русские записи остаются на твоём `whisper large-v3`
как сейчас, казахские/смешанные уходят на Qwen3-ASR.

Установка Qwen3-ASR (один раз):

```bash
bash scripts/setup-qwen3.sh
# скачает transformers + torch в venv
# первая транскрибация подтянет модель Qwen3-ASR-1.7B (~4 GB)
```

Использование:

```bash
./scripts/transcribe-auto.sh ~/Recordings/meeting.mp4
# сам определит язык и выберет бэкенд
```

Подробности и альтернативы (whisper-base.kk для чистого казахского) — в
[docs/custom-models.md](docs/custom-models.md#-казахский--kkru-code-switching).

## 📝 Саммаризация встреч

Новый скрипт `scripts/summarize.sh` делает из транскрипта структурированный
протокол — участники, проекты с деталями, цитаты, таблицы, action items.

### Локально через Ollama (рекомендуется)

```bash
brew install ollama
ollama pull qwen3:32b        # ~20 GB, для M4 Pro 24GB идеально
# или для лёгкого старта:
ollama pull qwen3:14b        # ~9 GB

# в config.sh:
SUMMARIZER_BACKEND="ollama"
SUMMARIZER_MODEL="qwen3:32b"
```

### Через Anthropic API (топовое качество)

```bash
# в config.sh:
SUMMARIZER_BACKEND="claude"
SUMMARIZER_MODEL="claude-sonnet-4-5-20250514"
ANTHROPIC_API_KEY="sk-ant-..."
```

### Использование

```bash
# после того как transcribe-auto.sh закончил:
./scripts/summarize.sh ~/Recordings/meeting-2026-04-22/meeting-2026-04-22.md
# результат: meeting-2026-04-22-summary.md рядом с исходником
```

## 📌 Что ещё на потом

- [ ] Записать демо-гифку → `assets/demo.gif` (см. TODO в README)
- [ ] Добавить скриншоты в `assets/`
- [ ] Прогнать `./install.sh` на чистой системе для проверки

## 🔗 Полезные ссылки

- Репо: https://github.com/moldabayevd/kt-recorder
- Архитектура: [docs/architecture.md](docs/architecture.md)
- Траблшутинг: [docs/troubleshooting.md](docs/troubleshooting.md)
- whisper.cpp: https://github.com/ggml-org/whisper.cpp
