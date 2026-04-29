# Changelog

Все значимые изменения проекта документируются в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
проект следует [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-04-23

### Added
- **Speaker diarization без 2 дорожек** — `scripts/diarize.sh` через
  pyannote.audio v3.1+, поддержка MPS/CUDA/CPU. Auto-detect числа спикеров.
- **PDF / DOCX / HTML экспорт** — `scripts/export.sh` через pandoc + XeLaTeX
  (кириллица + казахские буквы из коробки). Кастомные шаблоны через
  `~/.config/saqta/export/`.
- **Custom summary templates** — 5 встроенных (`protocol`, `1on1`,
  `interview`, `lecture`, `kazakh-formal`) + пользовательские. Флаг
  `--template <name>` или `SUMMARIZER_TEMPLATE` в config.
- **4 новых LLM-бэкенда** в `summarize.sh`: **Groq** (бесплатно, Llama 3.3 70B,
  ~12 сек), **OpenRouter** (200+ моделей), **vLLM**/**LM Studio**
  (OpenAI-compatible эндпоинты для корпоративных GPU-кластеров).
- `scripts/setup-pyannote.sh` — installer для diarization окружения
- `RELEASES/v0.2.0.md` — полные release notes
- `marketing/linkedin/*.md` — драфты LinkedIn постов для продвижения

### Changed
- ROADMAP перепланирован: v0.2 теперь = "Pro features (bash)", v0.3 = Tauri UI,
  v0.4 = Live, v0.5 = Public release. Сначала добиваем фичи, потом UI.

## [0.1.0] - 2026-04-22

### Added
- **On-demand режим через ярлычок на десктоп** —
  `launchagents/create-desktop-shortcut.sh` создаёт `Saqta.command`
  на рабочем столе. Двойной клик → открывается меню, никакого фонового
  процесса который греет Mac. Обработка запускается только когда пользователь
  сам выбрал запись.
- **Список записей со статусами** в TUI-меню — скан `$RECORDINGS_DIR`,
  показывает дата / время / длительность / размер / статус (🔴 raw /
  🟡 transcribed / 🟢 summarized) / имя. Адаптивное меню действий в
  зависимости от статуса выбранной записи.
- **Интерактивное TUI меню** — `scripts/saqta` красивая менюшка на базе
  `gum` (Charmbracelet). Спиннеры, превью файлов (размер, длительность),
  file picker, подтверждения, открытие результата в Finder, просмотр
  через pager. Действия: транскрибация, саммари, полный пайплайн,
  редактирование конфига. Работает и как CLI (`saqta full <file>`).
- **Саммаризация транскриптов** — `scripts/summarize.sh` превращает сырой
  транскрипт в структурированный протокол (участники, проекты с деталями,
  цитаты, таблицы с цифрами, action items, общие замечания).
  Два бэкенда: Ollama (локально, рекомендуется `qwen3:32b` для M4 Pro 24GB,
  `qwen3:14b` для лёгких машин) или Anthropic API (`claude-sonnet-4-5`,
  ~$0.02-0.05 за часовую встречу).
  Продакшн-промпт встроен, кастомизируется через `SUMMARIZER_PROMPT_FILE`.
- **Казахский язык и kk+ru code-switching** — новый роутер
  `scripts/transcribe-auto.sh` автодетектит язык по первым 30 сек и раскидывает
  записи по бэкендам: ru/en остаются на whisper large-v3 (без изменений),
  kk/mix уходят на Qwen3-ASR-1.7B (умеет переключаться между языками внутри
  фразы)
- `scripts/detect-lang.sh` — определение языка через whisper language detection
- `scripts/transcribe-kk.sh` — бэкенд для казахского с тремя режимами
  (`qwen3` / `whisper-kk` / `whisper`)
- `scripts/setup-qwen3.sh` — установщик Qwen3-ASR в изолированный venv
- Секция «Казахский / kk+ru code-switching» в `docs/custom-models.md` со
  сравнением WER для разных вариантов

### Planned

См. [ROADMAP.md](ROADMAP.md) для полного плана. Кратко по релизам:

**v0.2 — Native UI:**
- Tauri-приложение (двойной клик в Dock вместо терминала)
- Auto-detect Zoom/Meet/Teams встреч
- DMG-installer

**v0.3 — Pro-фичи бесплатно** (то за что Meetily берёт деньги):
- Speaker diarization через pyannote (без 2 дорожек)
- PDF/DOCX экспорт через pandoc
- Custom summary templates (protocol / 1on1 / interview / lecture)
- Гибкие LLM-провайдеры (Groq, OpenRouter, vLLM, LM Studio)

**v0.4 — Live режим:**
- Streaming transcription для ru/en через whisper-stream
- Live preview во время записи + быстрые заметки/маркеры с таймкодом

**v0.5 — Public release:**
- Cross-platform (Windows + Linux)
- Локализация UI (ru/kk/en)
- Homebrew tap, MSI, AppImage, auto-update
- Подписанный DMG

**v0.6 — Personal LoRA:**
- Сбор обучающих данных из исправленных пользователем `.md`
- LoRA fine-tune на 4070 / Apple Silicon
- Continuous learning с A/B сравнением

## [0.1.0] - 2026-04-22

### Added
- Автоматическая транскрибация через watcher на `fswatch`
- One-command установка через `install.sh`
- LaunchAgent для автозапуска при логине
- Поддержка Whisper Large-v3 с Metal-ускорением
- Экспорт в Markdown с YAML frontmatter (Obsidian-совместимо)
- Генерация VTT-субтитров с таймкодами
- Нативные уведомления macOS на каждом этапе
- Ручная транскрибация через `transcribe-file.sh`
- Конфигурационный файл `~/.config/saqta/config.sh`
- Документация: `custom-models.md`, `troubleshooting.md`
- CI через GitHub Actions: shellcheck для всех скриптов

### Security
- Полная офлайн-работа после первичной загрузки модели
- Никаких внешних API-вызовов в runtime

[Unreleased]: https://github.com/YOUR_USERNAME/saqta-with-stt/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/YOUR_USERNAME/saqta-with-stt/releases/tag/v0.1.0
