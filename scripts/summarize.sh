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
Usage: $(basename "$0") <meeting.md> [output.md] [--template <name>]

Конфиг в ~/.config/saqta/config.sh:
  SUMMARIZER_BACKEND  — ollama | claude (по умолчанию: ollama)
  SUMMARIZER_MODEL    — для ollama: qwen3:32b / qwen3:14b / gemma3:27b / ...
                        для claude: claude-sonnet-4-5 / claude-opus-4-7
  ANTHROPIC_API_KEY   — если backend=claude
  SUMMARIZER_TEMPLATE — protocol | 1on1 | interview | lecture | kazakh-formal
                        (по умолчанию: protocol)

Шаблоны лежат в \$REPO/templates/<name>.txt или
~/.config/saqta/templates/<name>.txt (приоритет — пользовательский).
EOF
    exit 1
fi

# Парсим аргументы
INPUT=""
OUTPUT=""
TEMPLATE_OVERRIDE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --template)
            TEMPLATE_OVERRIDE="$2"
            shift 2
            ;;
        --template=*)
            TEMPLATE_OVERRIDE="${1#*=}"
            shift
            ;;
        *)
            if [ -z "$INPUT" ]; then
                INPUT="$1"
            elif [ -z "$OUTPUT" ]; then
                OUTPUT="$1"
            fi
            shift
            ;;
    esac
done

[ -z "$OUTPUT" ] && OUTPUT="${INPUT%.md}-summary.md"

[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }

CONFIG_FILE="$HOME/.config/saqta/config.sh"
# shellcheck disable=SC1090
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

: "${SUMMARIZER_BACKEND:=ollama}"
: "${SUMMARIZER_MODEL:=qwen3:32b}"
: "${SUMMARIZER_PROMPT_FILE:=$HOME/.config/saqta/summarize_prompt.txt}"
: "${SUMMARIZER_TEMPLATE:=protocol}"

# Override из CLI
[ -n "$TEMPLATE_OVERRIDE" ] && SUMMARIZER_TEMPLATE="$TEMPLATE_OVERRIDE"

# Поиск шаблона: сначала пользовательская папка, потом репо
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_TEMPLATES="$SCRIPT_DIR/../templates"
USER_TEMPLATES="$HOME/.config/saqta/templates"

TEMPLATE_FILE=""
if [ -f "$USER_TEMPLATES/$SUMMARIZER_TEMPLATE.txt" ]; then
    TEMPLATE_FILE="$USER_TEMPLATES/$SUMMARIZER_TEMPLATE.txt"
elif [ -f "$REPO_TEMPLATES/$SUMMARIZER_TEMPLATE.txt" ]; then
    TEMPLATE_FILE="$REPO_TEMPLATES/$SUMMARIZER_TEMPLATE.txt"
fi

# Приоритет: явный SUMMARIZER_PROMPT_FILE > шаблон > встроенный
if [ -f "$SUMMARIZER_PROMPT_FILE" ] && [ -s "$SUMMARIZER_PROMPT_FILE" ]; then
    SYSTEM_PROMPT=$(cat "$SUMMARIZER_PROMPT_FILE")
    echo "→ Промпт: $SUMMARIZER_PROMPT_FILE (override)"
elif [ -n "$TEMPLATE_FILE" ]; then
    SYSTEM_PROMPT=$(cat "$TEMPLATE_FILE")
    echo "→ Шаблон: $SUMMARIZER_TEMPLATE ($TEMPLATE_FILE)"
else
    echo "→ Шаблон: встроенный (protocol fallback)"
    SYSTEM_PROMPT=$(cat << 'PROMPT'
Ты — опытный ассистент, превращающий сырые транскрипты встреч
в структурированные протоколы для Obsidian / корпоративных вики.

Входные данные: транскрипт встречи (может быть на русском, казахском или
смеси kk+ru). Транскрипт сырой, с ошибками ASR и размытыми фразами.

Твоя задача — выдать **Markdown-документ** со следующей структурой:

---
---
title: "<Название встречи — дата>"
date: YYYY-MM-DD
source: saqta
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

Выдавай чистый Markdown, без оборачивания в код-блоки.
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
        # проверяем что модель есть (grep -q + pipefail ломается через SIGPIPE)
        MODEL_LIST=$(ollama list 2>/dev/null || true)
        if ! echo "$MODEL_LIST" | grep -q "^${SUMMARIZER_MODEL%%:*}"; then
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

    groq)
        # Groq — бесплатный быстрый Llama 3.3 70B / Mixtral / DeepSeek
        # https://console.groq.com  → API key
        command -v jq >/dev/null || { echo "✗ jq нужен: brew install jq" >&2; exit 1; }
        [ -n "${GROQ_API_KEY:-}" ] || {
            echo "✗ GROQ_API_KEY не задан" >&2; exit 1; }
        : "${SUMMARIZER_MODEL:=llama-3.3-70b-versatile}"

        echo "→ Groq API ($SUMMARIZER_MODEL)..."
        tmp=$(mktemp)
        jq -n --arg model "$SUMMARIZER_MODEL" \
              --arg system "$SYSTEM_PROMPT" \
              --arg user "$TRANSCRIPT_CONTENT" \
              '{model: $model, max_tokens: 8192, temperature: 0.3,
                messages: [{role:"system", content:$system},
                           {role:"user", content:$user}]}' > "$tmp"

        curl -s https://api.groq.com/openai/v1/chat/completions \
            -H "Authorization: Bearer $GROQ_API_KEY" \
            -H "content-type: application/json" \
            -d @"$tmp" | jq -r '.choices[0].message.content' > "$OUTPUT"
        rm -f "$tmp"
        ;;

    openrouter)
        # OpenRouter — gateway к 200+ моделям, можно платно или бесплатные тиры
        # https://openrouter.ai  → API key
        command -v jq >/dev/null || { echo "✗ jq нужен: brew install jq" >&2; exit 1; }
        [ -n "${OPENROUTER_API_KEY:-}" ] || {
            echo "✗ OPENROUTER_API_KEY не задан" >&2; exit 1; }
        : "${SUMMARIZER_MODEL:=meta-llama/llama-3.3-70b-instruct}"

        echo "→ OpenRouter ($SUMMARIZER_MODEL)..."
        tmp=$(mktemp)
        jq -n --arg model "$SUMMARIZER_MODEL" \
              --arg system "$SYSTEM_PROMPT" \
              --arg user "$TRANSCRIPT_CONTENT" \
              '{model: $model, max_tokens: 8192, temperature: 0.3,
                messages: [{role:"system", content:$system},
                           {role:"user", content:$user}]}' > "$tmp"

        curl -s https://openrouter.ai/api/v1/chat/completions \
            -H "Authorization: Bearer $OPENROUTER_API_KEY" \
            -H "HTTP-Referer: https://github.com/moldabayevd/saqta" \
            -H "X-Title: Saqta" \
            -H "content-type: application/json" \
            -d @"$tmp" | jq -r '.choices[0].message.content' > "$OUTPUT"
        rm -f "$tmp"
        ;;

    vllm|lmstudio|openai-compat)
        # vLLM / LM Studio / любой OpenAI-compatible эндпоинт
        # Полезно для корпоративных GPU-кластеров (например H200 в Казахтелеком)
        # Конфиг:
        #   VLLM_URL=http://gpu-cluster.internal/v1
        #   VLLM_API_KEY=optional
        command -v jq >/dev/null || { echo "✗ jq нужен" >&2; exit 1; }
        : "${VLLM_URL:?VLLM_URL не задан (например http://localhost:8000/v1)}"
        : "${SUMMARIZER_MODEL:=meta-llama/Llama-3.3-70B-Instruct}"

        auth_header=""
        [ -n "${VLLM_API_KEY:-}" ] && auth_header="Authorization: Bearer $VLLM_API_KEY"

        echo "→ $SUMMARIZER_BACKEND endpoint: $VLLM_URL ($SUMMARIZER_MODEL)..."
        tmp=$(mktemp)
        jq -n --arg model "$SUMMARIZER_MODEL" \
              --arg system "$SYSTEM_PROMPT" \
              --arg user "$TRANSCRIPT_CONTENT" \
              '{model: $model, max_tokens: 8192, temperature: 0.3,
                messages: [{role:"system", content:$system},
                           {role:"user", content:$user}]}' > "$tmp"

        if [ -n "$auth_header" ]; then
            curl -s "$VLLM_URL/chat/completions" \
                -H "$auth_header" \
                -H "content-type: application/json" \
                -d @"$tmp" | jq -r '.choices[0].message.content' > "$OUTPUT"
        else
            curl -s "$VLLM_URL/chat/completions" \
                -H "content-type: application/json" \
                -d @"$tmp" | jq -r '.choices[0].message.content' > "$OUTPUT"
        fi
        rm -f "$tmp"
        ;;

    *)
        echo "✗ Неизвестный SUMMARIZER_BACKEND: $SUMMARIZER_BACKEND" >&2
        echo "  Допустимо: ollama | claude | groq | openrouter | vllm | lmstudio" >&2
        exit 1
        ;;
esac

if [ ! -s "$OUTPUT" ]; then
    echo "✗ Пустой результат — что-то пошло не так" >&2
    exit 1
fi

echo ""
echo "✓ Готово: $OUTPUT ($(wc -c < "$OUTPUT") байт)"
