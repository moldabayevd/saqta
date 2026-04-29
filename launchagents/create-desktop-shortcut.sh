#!/usr/bin/env bash
# create-desktop-shortcut.sh — создаёт двойной-клик ярлычок Saqta.app
# на рабочем столе. При двойном клике открывается Terminal с запущенным меню.
#
# Использование:
#   bash launchagents/create-desktop-shortcut.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAQTA_SCRIPT="$SCRIPT_DIR/scripts/saqta"

if [ ! -x "$SAQTA_SCRIPT" ]; then
    echo "✗ Не найден или не исполняемый: $SAQTA_SCRIPT" >&2
    exit 1
fi

DESKTOP="$HOME/Desktop"
APP_NAME="Saqta"
COMMAND_FILE="$DESKTOP/$APP_NAME.command"

cat > "$COMMAND_FILE" << EOF
#!/usr/bin/env bash
# Двойной клик → открывается Terminal с меню Saqta.
# Закрыть можно Cmd+W или выбрав "Выход" в меню.
exec "$SAQTA_SCRIPT"
EOF

chmod +x "$COMMAND_FILE"

# Убираем .command расширение из отображения — в Finder будет просто "Saqta"
# (стандартный трюк — через extended attribute).
xattr -d com.apple.quarantine "$COMMAND_FILE" 2>/dev/null || true

echo "✓ Ярлычок создан: $COMMAND_FILE"
echo ""
echo "Теперь:"
echo "  1. Записал встречу через ⌘⇧R (QuickRecorder)"
echo "  2. Двойной клик по '$APP_NAME' на рабочем столе"
echo "  3. Выбираешь запись из списка → запускается магия"
echo ""
echo "Первый двойной клик может попросить подтверждения (macOS Gatekeeper)."
echo "Если не откроется — правый клик → Open → Open."
