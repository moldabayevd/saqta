# Changelog

Все значимые изменения проекта документируются в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
проект следует [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
- Диаризация спикеров (v0.2)
- Локальная саммаризация через Ollama + Sherkala-8B (v0.3)
- Swift menu bar app (v0.4)

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
- Конфигурационный файл `~/.config/kt-recorder/config.sh`
- Документация: `custom-models.md`, `troubleshooting.md`
- CI через GitHub Actions: shellcheck для всех скриптов

### Security
- Полная офлайн-работа после первичной загрузки модели
- Никаких внешних API-вызовов в runtime

[Unreleased]: https://github.com/YOUR_USERNAME/kt-recorder-with-stt/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/YOUR_USERNAME/kt-recorder-with-stt/releases/tag/v0.1.0
