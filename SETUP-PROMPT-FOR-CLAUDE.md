# 🤖 Setup Brief для Claude Code на Mac

> Это инструкция для Claude Code, запущенного на свежем Mac mini / MacBook
> пользователя **moldabayevd**. Цель: полностью установить saqta с
> поддержкой казахского языка и красивым меню за одну сессию без участия
> пользователя (user выходит покурить, возвращается — всё работает).

---

## Контекст

**Железо:** Mac M4 Pro, 24 GB unified memory, macOS 14+ (Sonoma).
**Пользователь:** знает bash, комфортно в терминале, НО не хочет разбираться
в деталях — хочет чтобы ты поставил и отчитался.
**Цель проекта:** приватная локальная транскрибация рабочих встреч на
казахском + русском + смеси (code-switching). С саммаризацией. Без облаков.

**Репо:** https://github.com/moldabayevd/saqta (уже публичный, не надо
создавать).

---

## Твоя задача (пошагово)

### 0. Проверь окружение

```bash
sw_vers                 # macOS версия
uname -m                # arm64 ожидается
echo $SHELL             # /bin/zsh скорее всего
which brew              # если нет — см. шаг 1
```

### 1. Homebrew (если ещё нет)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

После установки добавить brew в PATH (Apple Silicon):
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. Системные зависимости

```bash
brew install ffmpeg fswatch terminal-notifier jq gum whisper-cpp git git-lfs
brew install --cask blackhole-2ch quickrecorder
```

**Проверка:**
```bash
whisper-cli --help | head -3
ffmpeg -version | head -1
gum --version
```

### 3. Клонирование репо

```bash
mkdir -p ~/Projects
cd ~/Projects
git clone https://github.com/moldabayevd/saqta.git
cd saqta
git config user.name "moldabayevd"
git config user.email "moldabayevd@users.noreply.github.com"
```

### 4. Whisper модели

```bash
mkdir -p ~/whisper-models
cd ~/whisper-models

# Основная — large-v3-turbo (быстрее large-v3, качество то же)
# whisper.cpp download helper нужен — клонируем репо один раз ради скриптов
git clone https://github.com/ggml-org/whisper.cpp /tmp/whisper.cpp 2>/dev/null || true
bash /tmp/whisper.cpp/models/download-ggml-model.sh large-v3-turbo
mv ggml-large-v3-turbo.bin ~/whisper-models/

# Silero VAD — режет тишину, важно для качества
bash /tmp/whisper.cpp/models/download-vad-model.sh silero-v5.1.2
mv ggml-silero-v5.1.2.bin ~/whisper-models/ 2>/dev/null || true

# Опционально: русский fine-tune (WER лучше на ru)
# curl -L -O https://huggingface.co/antony66/whisper-large-v3-russian/resolve/main/ggml-model.bin
# mv ggml-model.bin ~/whisper-models/ggml-large-v3-russian.bin
```

### 5. Основная установка saqta

```bash
cd ~/Projects/saqta
./install.sh
```

Когда спросит про LaunchAgent — **ответь `n`** (пользователь хочет on-demand
режим через ярлычок, не watcher).

Когда спросит про модель — выбирай `large-v3-turbo` если есть вариант, иначе
`large-v3`.

### 6. Qwen3-ASR для казахского / kk+ru code-switching

```bash
cd ~/Projects/saqta
bash scripts/setup-qwen3.sh
```

Это создаст venv в `~/.config/saqta/.qwen3-venv`, поставит `transformers`,
`torch`, `soundfile`. **Pip займёт ~5-10 мин**, будь терпелив.

**Проверка:**
```bash
source ~/.config/saqta/.qwen3-venv/bin/activate
python -c "import torch; print('MPS:', torch.backends.mps.is_available())"
deactivate
```

Должно вывести `MPS: True` — иначе MPS не работает, Qwen3 пойдёт на CPU
(медленно, но работает).

### 7. Ollama для саммаризации

```bash
brew install ollama
brew services start ollama   # автозапуск сервиса
sleep 5

# Основная модель для саммари — Qwen3:32B (лучший баланс качества/размера
# для 24 GB Mac). Скачивание ~20 GB, 10-30 мин в зависимости от сети.
ollama pull qwen3:32b

# Бэкап: Qwen3:14B — если 32B тормозит или мало свободной памяти.
ollama pull qwen3:14b
```

**Проверка:**
```bash
ollama list
# должен показать qwen3:32b и qwen3:14b

# Быстрый тест:
echo "Ответь одним словом на казахском: привет" | ollama run qwen3:14b --nowordwrap
```

### 8. Конфиг saqta

Создай/обнови `~/.config/saqta/config.sh`:

```bash
cat > ~/.config/saqta/config.sh << 'EOF'
# Saqta configuration

# Папка записей QuickRecorder
RECORDINGS_DIR="$HOME/Recordings"

# Основная модель whisper (для ru/en)
WHISPER_MODEL="$HOME/whisper-models/ggml-large-v3-turbo.bin"
WHISPER_LANG="ru"

# VAD
VAD_MODEL="$HOME/whisper-models/ggml-silero-v5.1.2.bin"

# Казахский бэкенд
KK_BACKEND="qwen3"
QWEN3_ASR_SCRIPT="$HOME/.config/saqta/qwen3_asr.py"
WHISPER_KK_MODEL="$HOME/whisper-models/ggml-base-kk.bin"

# Саммаризатор
SUMMARIZER_BACKEND="ollama"
SUMMARIZER_MODEL="qwen3:32b"

# Разное
OUTPUT_FORMATS="txt,vtt"
OPEN_FINDER_ON_DONE=true
NOTIFY_SOUND="Glass"
PROMPT_FILE="$HOME/.config/saqta/prompt.txt"
EOF
```

Создай пустой словарь промпта (пользователь потом заполнит):
```bash
touch ~/.config/saqta/prompt.txt
```

### 9. Ярлычок на рабочий стол

```bash
cd ~/Projects/saqta
bash launchagents/create-desktop-shortcut.sh
```

После этого на рабочем столе появится **`Saqta.command`** — двойной
клик запускает TUI меню.

### 10. Первая проверка

```bash
mkdir -p ~/Recordings
cd ~/Projects/saqta
./scripts/saqta
```

Должно открыться красивое меню с пунктами:
- 📋 Мои записи
- 🎬 Транскрибировать произвольный файл
- 📝 Сделать саммари из .md транскрипта
- ⚡ Полный пайплайн
- ⚙️ Настройки
- 🚪 Выход

Выйди через "🚪 Выход".

### 11. Smoke-test на реальной записи (ОПЦИОНАЛЬНО)

Если у пользователя на маке уже есть какая-то запись в `~/Recordings/` или
`~/Downloads/` — прогони **короткий** файл (< 5 минут) через полный пайплайн:

```bash
./scripts/saqta full ~/Recordings/test.mp4
```

Если нет — пропусти, юзер сам протестит.

### 12. Отчёт пользователю

Напиши summary того что сделал, в формате:

```
✅ Homebrew              — установлен / уже был
✅ Зависимости           — ffmpeg, whisper-cpp, gum, ollama, ...
✅ Whisper модели        — large-v3-turbo (XX GB), silero-vad
✅ saqta клонирован — ~/Projects/saqta
✅ Qwen3-ASR venv        — готов, MPS: True
✅ Ollama модели         — qwen3:32b (20GB), qwen3:14b (9GB)
✅ Конфиг                — ~/.config/saqta/config.sh
✅ Ярлычок на десктопе   — Saqta.command
⚠️ Смоук-тест            — пропущен, нет тестовой записи (или "прошёл за 2мин")

Что делать дальше:
  1. ⌘⇧R → запиши тестовую встречу (любую, 1-2 мин)
  2. Двойной клик по 'Saqta' на рабочем столе
  3. Выбери запись → ⚡ Полный пайплайн
  4. Дождись спиннеров → откроется Finder с результатом
```

---

## Возможные проблемы и как их решить

### `whisper-cli: command not found`
```bash
brew install whisper-cpp
# если всё ещё нет — whisper-cpp может лежать как ggml.cpp:
brew install ggml.cpp 2>/dev/null || true
```

### `gum: command not found`
```bash
brew install charmbracelet/tap/gum   # если обычный brew install не нашёл
```

### Qwen3 `torch` падает при установке (Apple Silicon specific)
```bash
source ~/.config/saqta/.qwen3-venv/bin/activate
pip install --pre torch torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu
deactivate
```

### Ollama не стартует
```bash
brew services stop ollama
brew services start ollama
sleep 10
ollama list
```

### Qwen3:32b не помещается в память (OOM)
Переключи в конфиге на 14B:
```bash
sed -i '' 's/qwen3:32b/qwen3:14b/' ~/.config/saqta/config.sh
```

### Ярлычок на десктопе требует "Open" через правый клик
Это нормально при первом запуске (Gatekeeper). Скажи пользователю: правый
клик → Open → Open. Дальше без подтверждений.

### QuickRecorder пишет только системный звук без микрофона
- Открой QuickRecorder → Settings → Audio
- Включи `Record Microphone`
- Включи `Separate audio tracks` (для `transcribe-roles.sh`)

---

## Что НЕ делать

- ❌ **Не включай LaunchAgent** — пользователь явно просил on-demand режим
- ❌ **Не ставь whisper-base.kk** по умолчанию — сначала пусть пользователь
  попробует Qwen3 на своих встречах, потом решит
- ❌ **Не трогай ANTHROPIC_API_KEY** — пользователь его не давал, бэкенд
  саммари по умолчанию локальный (ollama)
- ❌ **Не коммить изменения в config.sh** в git — он в .gitignore (должен быть)
- ❌ **Не запускай тренировку моделей** — это для будущего, не сейчас

---

## Ссылки для справки

- [Основной README](README.md)
- [Гайд продолжения работы](CONTINUE-ON-MAC.md)
- [Казахский и code-switching](docs/custom-models.md#-казахский--kkru-code-switching)
- [Архитектура](docs/architecture.md)
- [Траблшутинг](docs/troubleshooting.md)

---

## Финальный чеклист перед тем как сдать задачу

- [ ] `./scripts/saqta` открывает меню без ошибок
- [ ] `ollama list` показывает qwen3:32b и qwen3:14b
- [ ] `~/.config/saqta/config.sh` существует и корректен
- [ ] `Saqta.command` на рабочем столе и кликается
- [ ] Qwen3-ASR venv создан, MPS доступен
- [ ] Все модели whisper на месте в `~/whisper-models/`
- [ ] В отчёте указал сколько диска занято (`du -sh ~/whisper-models ~/.ollama`)

---

**Готово? Отлично. Теперь пользователь может записывать встречи и кликать
ярлычок на рабочем столе.**
