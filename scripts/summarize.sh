#!/usr/bin/env bash
# summarize.sh — превращает транскрипт встречи в структурированный саммари
# с участниками, проектами, цитатами, таблицами и action items.
#
# Поддерживает два бэкенда (выбор через SUMMARIZER_BACKEND):
#   ollama  — локально через Ollama (Qwen3:32B / Qwen3:14B / Gemma / ...)
#   claude  — через Anthropic API (лучшее качество, платно но копейки)
#
# Использование:
#   summarize.sh <meeting.md>              # перезаписывает исходник
#   summarize.sh <meeting.md> <output.md>  # в отдельный файл
#
# Результат кладёт рядом с транскриптом — с расширенным frontmatter
# и секциями: Участники, Проекты, Action items, Общие замечания.

set -euo pipefail

if [ $# -eq 0 ]; then
    cat << EOF
Usage: $(basename "$0") <meeting.md> [output.md]

Конфиг в ~/.config/kt-recorder/config.sh:
  SUMMARIZER_BACKEND  — ollama | claude (по умолчанию: ollama)
  SUMMARIZER_MODEL    — для ollama: qwen3:32b / qwen3:14b / gemma3:27b / ...
                        для claude: claude-sonnet-4-5 / claude-opus-4-7
  ANTHROPIC_API_KEY   — если backend=claude
EOF
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.md}-summary.md}"

[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }

CONFIG_FILE="$HOME/.config/kt-recorder/config.sh"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

: "${SUMMARIZER_BACKEND:=ollama}"
: "${SUMMARIZER_MODEL:=qwen3:32b}"
: "${SUMMARIZER_PROMPT_FILE:=$HOME/.config/kt-recorder/summarize_prompt.txt}"

# Если кастомного промпта нет — используем встроенный (ниже в heredoc)
if [ -f "$SUMMARIZER_PROMPT_FILE" ] && [ -s "$SUMMARIZER_PROMPT_FILE" ]; then
    SYSTEM_PROMPT=$(cat "$SUMMARIZER_PROMPT_FILE")
else
    SYSTEM_PROMPT=$(cat << 'PROMPT'
Ты — опытный ассистент, превращающий сырые транскрипты встреч
в структурированные протоколы для Obsidian / корпоративных вики.

Входные данные: транскрипт встречи (может быть на русском, казахском или
смеси kk+ru). Транскрипт сырой, с ошибками ASR и размытыми фразами.

Твоя задача — выдать **Markdown-документ** со следующей структурой:

---
```
---
title: "<Название встречи — дата>"
date: YYYY-MM-DD
source: kt-recorder
tags:
  - meeting
  - protocol
---

# <Название>

**Дата:** <дата и время>
**Длительность:** ~<X> часов
**Источник:** [`<имя файла>`](<имя файла>)

## Участники

- **<Имя>** — <роль / должность / что делал на встрече>
- ...

## Проект 1. <Название> (<автор/докладчик>)

**Суть:** <1-2 предложения>
**Контекст:** <если нужно>
**Детали:**
- <буллеты с конкретикой>

**Цифры** (если были, в таблице):
| Колонка | Колонка |
|---|---|
| ... | ... |

**Цитаты** (важные реплики, сохрани дословно):
> «<цитата>» — <кто сказал>

**Обратная связь / решения:**
- <что согласовали, что отклонили>

**Решение:** <что делать дальше>

---

## Проект 2. ...
(повторяй структуру для каждой обсуждённой темы/проекта)

## Action items

| # | Кому | Что | Когда |
|---|---|---|---|
| 1 | <имя> | <задача> | <срок или —> |
| ... |

## Общие замечания

- <сквозные мысли, принципы, правила которые озвучил ключевой человек>
- <замечания про подачу, процесс, ресурсы>
```
---

ВАЖНЫЕ ПРАВИЛА:
1. **Не выдумывай** — если в транскрипте нет цифры, не пиши её. Если нет
   срока — ставь «—».
2. **Сохраняй имена как в транскрипте**, даже если кажутся неправильными
   (whisper мог ошибиться, но пользователь знает свой контекст).
3. **Цитаты копируй дословно** с кавычками «...» и ссылкой на автора.
4. **Цифры, суммы, проценты, названия систем (Smallworld, SAP, QlikSense,
   и т.п.)** выноси в таблицы или жирным — это ключевое.
5. **Код проектов / приказов / документов** (типа «№ 236», «ДСА-11») сохраняй
   точь-в-точь.
6. **Не добавляй воду** — «в ходе конструктивной дискуссии участники
   обменялись мнениями» это мусор. Только факты.
7. **Action items только если реально что-то поручили.** Не выдумывай задачи.
8. **Язык вывода** — русский, даже если транскрипт частично на казахском
   (казахские имена/термины сохраняй как есть).
9. Если встреча на **казахском** — саммари тоже на казахском, структура та же.
10. **Первый блок** — всегда YAML frontmatter в тройных дефисах, потом
    заголовок H1, потом остальное.

Выдавай чистый Markdown, без оборачивания в ```md блоки.
PROMPT
)
fi

TRANSCRIPT_CONTENT=$(cat "$INPUT")

echo "→ Бэкенд: $SUMMARIZER_BACKEND ($SUMMARIZER_MODEL)"
echo "→ Вход:  $INPUT ($(wc -c < "$INPUT") байт)"

case "$SUMMARIZER_BACKEND" in
    ollama)
        command -v ollama >/dev/null || {
            echo "✗ Ollama не установлена. brew install ollama" >&2
            exit 1
        }
        # проверяем что модель есть
        if ! ollama list 2>/dev/null | grep -q "^${SUMMARIZER_MODEL%%:*}"; then
            echo "→ Модель $SUMMARIZER_MODEL не найдена, тяну..."
            ollama pull "$SUMMARIZER_MODEL"
        fi

        echo "→ Генерация саммари..."
        # Передаём system prompt + transcript; num_ctx большой чтобы часовая
        # встреча влезла целиком
        {
            printf '%s\n\n---TRANSCRIPT---\n\n%s\n' "$SYSTEM_PROMPT" "$TRANSCRIPT_CONTENT"
        } | ollama run "$SUMMARIZER_MODEL" --nowordwrap > "$OUTPUT"
        ;;

    claude)
        command -v curl >/dev/null || { echo "✗ curl нужен" >&2; exit 1; }
        [ -n "${ANTHROPIC_API_KEY:-}" ] || {
            echo "✗ ANTHROPIC_API_KEY не задан в config.sh или env" >&2
            exit 1
        }
        : "${SUMMARIZER_MODEL:=claude-sonnet-4-5-20250514}"

        echo "→ Запрос к Anthropic API ($SUMMARIZER_MODEL)..."
        tmp=$(mktemp)
        # jq нужен для корректного экранирования
        command -v jq >/dev/null || { echo "✗ jq нужен: brew install jq" >&2; exit 1; }

        jq -n \
            --arg model "$SUMMARIZER_MODEL" \
            --arg system "$SYSTEM_PROMPT" \
            --arg user "$TRANSCRIPT_CONTENT" \
            '{
                model: $model,
                max_tokens: 8192,
                system: $system,
                messages: [{ role: "user", content: $user }]
            }' > "$tmp"

        curl -s https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d @"$tmp" \
            | jq -r '.content[0].text' > "$OUTPUT"

        rm -f "$tmp"
        ;;

    *)
        echo "✗ Неизвестный SUMMARIZER_BACKEND: $SUMMARIZER_BACKEND" >&2
        echo "  Допустимо: ollama | claude" >&2
        exit 1
        ;;
esac

if [ ! -s "$OUTPUT" ]; then
    echo "✗ Пустой результат — что-то пошло не так" >&2
    exit 1
fi

echo ""
echo "✓ Готово: $OUTPUT ($(wc -c < "$OUTPUT") байт)"
