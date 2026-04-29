# Contributing to Saqta

Спасибо, что хочешь помочь! Тут всё про то, как контрибьютить в проект.

## Что нужно для локальной разработки

- macOS 13+ (либо Linux с bash для линтинга)
- [shellcheck](https://www.shellcheck.net) — `brew install shellcheck`
- [shfmt](https://github.com/mvdan/sh) — `brew install shfmt` (опционально)
- Все зависимости проекта (проще всего — просто прогнать `./install.sh`)

## Процесс

1. **Форкни** репу и склонируй свой форк
2. Создай ветку: `git checkout -b feat/cool-thing` или `fix/annoying-bug`
3. Внеси изменения, прогони локально
4. **Прогони линтер:**
   ```bash
   shellcheck install.sh uninstall.sh scripts/*.sh launchagents/*.sh
   ```
   Чисто? Отлично.
5. Коммить по [Conventional Commits](https://www.conventionalcommits.org/ru):
   ```
   feat: добавил поддержку srt-экспорта
   fix: watcher падал на файлах с кириллицей в имени
   docs: обновил FAQ по Intel Mac
   ```
6. Запушь и открой PR. В описании:
   - Что именно меняется
   - Как это тестировал
   - Скриншоты/логи если уместно

## Стиль кода

**Bash:**
- `#!/usr/bin/env bash` + `set -euo pipefail`
- Все переменные в `"$quotes"` — safety first
- Функции с `local` для локальных переменных
- Комменты на русском или английском, главное — читаемо
- Форматирование: `shfmt -i 4 -ci -w file.sh` (4 пробела, отступы в case)

**Markdown:**
- Доки на русском (основная аудитория)
- Code blocks с явным указанием языка: ` ```bash `
- Ссылки относительные (`[docs](docs/file.md)`) а не абсолютные

## Что хочется добавить

Смотри [README#roadmap](README.md#️-roadmap) и [Issues](../../issues). Особенно приветствуется:

- **Диаризация** — разметка «кто говорит» из раздельных треков QuickRecorder
- **Swift menu bar app** — замена LaunchAgent'а на явное приложение с меню
- **Ollama-интеграция** — опциональный шаг саммаризации после транскрипта
- **Homebrew tap** — чтобы `brew install saqta`
- **Диаризация через pyannote** — для обычных записей без раздельных треков

## Как протестировать изменения

```bash
# 1. Локальная установка (не перезаписывает уже установленное)
./install.sh

# 2. Записать тестовую 30-секундную встречу через QuickRecorder

# 3. Или транскрибировать готовый файл:
~/bin/saqta/transcribe-file.sh path/to/test.m4a

# 4. Смотреть логи watcher:
tail -f /tmp/saqta.log /tmp/saqta.err
```

## Code of Conduct

Будь человеком. Оскорбления, дискриминация, токсичность → PR не приму, комменты удалю, забаню.

## Лицензия

Отправляя PR, ты соглашаешься что твой код публикуется под [MIT](LICENSE).
