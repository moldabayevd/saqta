#!/usr/bin/env bash
# export.sh — экспорт .md транскриптов/протоколов в PDF, DOCX, HTML.
#
# Требует: pandoc (brew install pandoc), basictex или mactex для PDF
#          (brew install --cask basictex)
#
# Использование:
#   export.sh <file.md>                    # дефолт: pdf
#   export.sh <file.md> --format pdf
#   export.sh <file.md> --format docx
#   export.sh <file.md> --format html
#   export.sh <file.md> --output ~/path.pdf

set -euo pipefail

if [ $# -eq 0 ]; then
    cat << EOF
Usage: $(basename "$0") <file.md> [--format pdf|docx|html] [--output <path>]

Зависимости:
  brew install pandoc
  brew install --cask basictex   # для PDF (~80 MB вместо 4 GB mactex)

Шаблоны (опционально):
  ~/.config/saqta/export/template.tex      # для PDF
  ~/.config/saqta/export/reference.docx    # для DOCX (стили)
EOF
    exit 1
fi

INPUT=""
FORMAT="pdf"
OUTPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --format)        FORMAT="$2"; shift 2 ;;
        --format=*)      FORMAT="${1#*=}"; shift ;;
        --output|-o)     OUTPUT="$2"; shift 2 ;;
        --output=*)      OUTPUT="${1#*=}"; shift ;;
        *)               [ -z "$INPUT" ] && INPUT="$1"; shift ;;
    esac
done

[ -f "$INPUT" ] || { echo "✗ Файл не найден: $INPUT" >&2; exit 1; }
command -v pandoc >/dev/null || {
    echo "✗ pandoc не установлен. brew install pandoc" >&2
    exit 1
}

[ -z "$OUTPUT" ] && OUTPUT="${INPUT%.md}.$FORMAT"

EXPORT_CONFIG="$HOME/.config/saqta/export"
PDF_TEMPLATE="$EXPORT_CONFIG/template.tex"
DOCX_REFERENCE="$EXPORT_CONFIG/reference.docx"

echo "→ Экспорт: $INPUT → $OUTPUT ($FORMAT)"

case "$FORMAT" in
    pdf)
        # Проверяем что есть LaTeX engine
        if ! command -v xelatex >/dev/null 2>&1 && ! command -v pdflatex >/dev/null 2>&1; then
            echo "✗ LaTeX не найден. Поставь basictex:" >&2
            echo "    brew install --cask basictex" >&2
            echo "    eval \"\$(/usr/libexec/path_helper)\"" >&2
            echo "    sudo tlmgr update --self && sudo tlmgr install collection-fontsrecommended" >&2
            exit 1
        fi

        engine="xelatex"
        command -v xelatex >/dev/null 2>&1 || engine="pdflatex"

        args=(--pdf-engine="$engine" -V geometry:margin=2cm -V mainfont="Times New Roman")
        # XeLaTeX поддерживает кириллицу/казахские буквы из коробки
        [ "$engine" = "xelatex" ] && args+=(-V mainfont="Helvetica" -V CJKmainfont="PingFang SC")
        [ -f "$PDF_TEMPLATE" ] && args+=(--template="$PDF_TEMPLATE")

        pandoc "$INPUT" -o "$OUTPUT" "${args[@]}"
        ;;

    docx)
        args=()
        [ -f "$DOCX_REFERENCE" ] && args+=(--reference-doc="$DOCX_REFERENCE")
        pandoc "$INPUT" -o "$OUTPUT" "${args[@]}"
        ;;

    html)
        pandoc "$INPUT" -o "$OUTPUT" --standalone --metadata title="$(basename "${INPUT%.md}")" \
               --css <(cat << 'CSSEOF'
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       max-width: 800px; margin: 2em auto; padding: 0 1em; line-height: 1.6;
       color: #1a1a1a; }
h1, h2, h3 { color: #2c3e50; }
table { border-collapse: collapse; margin: 1em 0; }
th, td { border: 1px solid #ddd; padding: 0.5em 1em; }
th { background: #f5f5f5; }
blockquote { border-left: 4px solid #3498db; margin: 1em 0; padding: 0.5em 1em;
             color: #555; background: #f9f9f9; }
code { background: #f4f4f4; padding: 0.2em 0.4em; border-radius: 3px; }
CSSEOF
)
        ;;

    *)
        echo "✗ Неизвестный формат: $FORMAT (допустимо: pdf | docx | html)" >&2
        exit 1
        ;;
esac

if [ -f "$OUTPUT" ]; then
    size=$(du -h "$OUTPUT" | awk '{print $1}')
    echo "✓ Готово: $OUTPUT ($size)"
else
    echo "✗ Файл не создан" >&2
    exit 1
fi
