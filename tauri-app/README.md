# 🎙️ Saqta Tauri App (v0.3.0-dev)

Native macOS приложение поверх существующих bash-скриптов проекта.

> **Статус:** v0.3.0-dev — каркас. Запускается, видит записи, кнопки работают.
> Polish (drag-drop, прогресс-бары с парсингом stdout, menu bar индикатор)
> и DMG-сборка — следующий шаг.

## Архитектура

```
┌────────────────────────────────────────────────────────────┐
│  Frontend (Svelte + TypeScript)                            │
│   ├─ App.svelte ─── список записей + статусы               │
│   ├─ Recording.svelte ─── карточка с кнопками              │
│   └─ lib/api.ts ─── invoke() в Rust                         │
├────────────────────────────────────────────────────────────┤
│  Rust backend (src-tauri/src/lib.rs)                       │
│   ├─ list_recordings — сканирует RECORDINGS_DIR            │
│   ├─ get_config — парсит ~/.config/saqta/config.sh   │
│   ├─ transcribe → bash scripts/transcribe-auto.sh           │
│   ├─ summarize  → bash scripts/summarize.sh --template ... │
│   ├─ export_file → bash scripts/export.sh --format pdf     │
│   └─ open_in_finder → open -R                               │
├────────────────────────────────────────────────────────────┤
│  ../scripts (существующие bash скрипты, не меняем)         │
│   ├─ transcribe-auto.sh                                     │
│   ├─ summarize.sh                                           │
│   ├─ export.sh                                              │
│   └─ ...                                                    │
└────────────────────────────────────────────────────────────┘
```

**Ключевая идея:** UI — тонкая обёртка. Вся логика остаётся в bash, что
позволяет в любой момент менять её без пересборки приложения.

## Запуск (на macOS, с Rust + Node 20+)

```bash
# Один раз:
cd tauri-app
npm install

# Иконки (нужно один раз перед первой сборкой):
# 1. Сделай PNG 1024×1024 (см. src-tauri/icons/README.md)
# 2. Сгенерь размеры:
npm run tauri icon ~/path/to/icon-1024.png

# Dev-режим (горячая перезагрузка):
npm run tauri:dev

# Production-сборка → .dmg:
npm run tauri:build
# результат: src-tauri/target/release/bundle/dmg/Saqta_0.3.0_x64.dmg
```

## Зависимости

### Build-time
- Node.js 20+ (npm)
- Rust 1.77+ (`brew install rustup` + `rustup-init`)
- Xcode Command Line Tools (`xcode-select --install`)

### Runtime
- bash скрипты из `../scripts/` (само собой)
- ffmpeg, whisper-cpp, ollama и т.д. — как обычно для проекта
- Конфиг в `~/.config/saqta/config.sh`

## Что уже работает

- ✅ Список записей со статусами (raw / transcribed / summarized)
- ✅ Парсинг `config.sh` для отображения текущих настроек
- ✅ Кнопка «Транскрибировать» (raw → transcribed)
- ✅ Кнопка «Саммари» (transcribed → summarized)
- ✅ Кнопка «PDF» (summarized → экспорт)
- ✅ «Открыть в Finder» через `open -R`
- ✅ Тёмная / светлая тема (auto по системе)
- ✅ Транспарентный titleBar в стиле macOS Big Sur+

## Что в TODO для production

- [ ] Прогресс-бары с реальными процентами (парсинг stdout whisper-cli)
- [ ] Drag-and-drop файлов на окно
- [ ] Menu bar индикатор (NSStatusItem)
- [ ] Auto-detect Zoom/Meet/Teams окон
- [ ] Settings UI (вместо ручной правки config.sh)
- [ ] Иконка приложения
- [ ] Подписание DMG (Apple Developer account, $99/year)
- [ ] Auto-update через Tauri updater
- [ ] Локализация (i18n) для UI

## Стек

- **[Tauri 2.x](https://v2.tauri.app/)** — Rust backend + system webview
- **[Svelte 4](https://svelte.dev/)** — простой реактивный UI
- **[Vite](https://vitejs.dev/)** — dev server и сборка фронта
- **TypeScript** — типы для api.ts

Размер итогового бинарника: ожидается ~5-10 MB (Tauri использует системный
WebKit вместо bundled Chromium как Electron).
