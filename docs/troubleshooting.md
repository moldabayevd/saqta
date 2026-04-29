# Troubleshooting

## QuickRecorder не пишет системный звук

macOS 13+ требует отдельного разрешения на захват системного аудио через ScreenCaptureKit.

1. System Settings → Privacy & Security → **Screen Recording** → включи QuickRecorder
2. Перезапусти QuickRecorder
3. При первой записи macOS спросит разрешение на system audio — согласись

Если после этого всё равно нет звука — проверь, что в настройках QuickRecorder в секции Audio включён «System Audio» чекбокс.

## Watcher не ловит файлы

Проверь логи:

```bash
tail -f /tmp/saqta.log
tail -f /tmp/saqta.err
```

### Типичные причины

**`command not found: whisper-cli`** — LaunchAgent не видит путь к Homebrew. Проверь `install-launchagent.sh` — там автоопределение `/opt/homebrew/bin` vs `/usr/local/bin`. Если у тебя нестандартная установка — поправь `EnvironmentVariables` в `~/Library/LaunchAgents/com.saqta.autotranscribe.plist`.

**Watcher запущен, но не реагирует** — возможно, QuickRecorder сохраняет в другую папку. Проверь `RECORDINGS_DIR` в `~/.config/saqta/config.sh` и реальный путь в настройках QuickRecorder.

**Файлы сохраняются в подпапки** — watcher по дизайну игнорирует изменения в подпапках (там уже обработанные встречи). Если QuickRecorder пишет в подпапку — настрой его на плоскую структуру, либо измени логику фильтрации в `auto-transcribe.sh`.

### Перезапуск watcher

```bash
launchctl kickstart -k gui/$(id -u)/com.saqta.autotranscribe
```

Или полностью:

```bash
launchctl unload ~/Library/LaunchAgents/com.saqta.autotranscribe.plist
launchctl load ~/Library/LaunchAgents/com.saqta.autotranscribe.plist
```

## Транскрипт — бред

**Язык не тот:** проверь `WHISPER_LANG=ru` в конфиге (не `auto`). Auto-detect на первых секундах молчания может уехать в английский.

**Звук тихий или шумный:** Whisper плохо работает с низким битрейтом. Убедись что QuickRecorder пишет в 128 kbps+ или PCM.

**Галлюцинации в тишине** («Спасибо за просмотр» и т.п.) — известная проблема Whisper, он обучался на YouTube-субтитрах. Решения:

1. Использовать fine-tune под русский (`antony66/whisper-large-v3-russian`) — в нём галлюцинаций намного меньше
2. Добавить VAD в whisper-cli: открой `~/bin/saqta/auto-transcribe.sh` и дополни вызов флагом `--vad --vad-model ~/whisper-models/ggml-silero-v5.1.2.bin`. Модель VAD скачивается с [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp/blob/main/ggml-silero-v5.1.2.bin).

## Транскрибация медленная

Проверь что используется Metal — в логе whisper-cli должна быть строка:

```text
whisper_backend_init: using Metal backend
```

Если нет — whisper-cli собран без Metal. Перестанови:

```bash
brew reinstall whisper-cpp
```

Если ты на Intel Mac — Metal недоступен в принципе. Попробуй квантованную модель (см. [custom-models.md](custom-models.md)) или `ggml-medium.bin` вместо Large.

## Уведомления не показываются

Проверь что terminal-notifier работает:

```bash
terminal-notifier -title "Test" -message "Hello" -sound Glass
```

Если ничего — System Settings → Notifications → найди terminal-notifier в списке и разреши баннеры.

На некоторых версиях macOS terminal-notifier требует переподписи — `brew reinstall terminal-notifier` обычно чинит.

## Ошибка whisper.cpp: `failed to allocate buffer`

Нехватка памяти. Попробуй:

1. Закрой лишние приложения
2. Переключись на квантованную модель: `ggml-large-v3-q5_0.bin` вместо `ggml-large-v3.bin`
3. Или перейди на `ggml-medium.bin` (требует ~2.5 ГБ RAM vs ~4 ГБ у Large)

## Как посмотреть, что watcher сейчас делает

```bash
# Запущен ли процесс
ps aux | grep auto-transcribe

# Логи в реальном времени
tail -f /tmp/saqta.log /tmp/saqta.err

# Статус LaunchAgent
launchctl list | grep saqta
```

## Полный сброс

```bash
# Убить watcher
launchctl unload ~/Library/LaunchAgents/com.saqta.autotranscribe.plist

# Снести всё
./uninstall.sh

# Переустановить
./install.sh
```
