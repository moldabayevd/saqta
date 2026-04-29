#!/usr/bin/env bash
# Устанавливает watcher в автозапуск через LaunchAgent

set -euo pipefail

PLIST_LABEL="com.saqta.autotranscribe"
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
SCRIPT_PATH="$HOME/bin/saqta/auto-transcribe.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "✗ Скрипт не найден: $SCRIPT_PATH" >&2
    echo "  Сначала запусти install.sh" >&2
    exit 1
fi

# If already loaded — unload first
if launchctl list 2>/dev/null | grep -q "$PLIST_LABEL"; then
    echo "→ Останавливаю существующий watcher..."
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
fi

# Detect Homebrew prefix
if [ -d "/opt/homebrew/bin" ]; then
    BREW_PATH="/opt/homebrew/bin"
else
    BREW_PATH="/usr/local/bin"
fi

cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/saqta.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/saqta.err</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$BREW_PATH:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

launchctl load "$PLIST_FILE"

echo "✓ LaunchAgent установлен"
echo ""
echo "  Файл:          $PLIST_FILE"
echo "  Логи:          /tmp/saqta.log"
echo "  Ошибки:        /tmp/saqta.err"
echo ""
echo "  Остановить:    launchctl unload $PLIST_FILE"
echo "  Перезапуск:    launchctl kickstart -k gui/\$(id -u)/$PLIST_LABEL"
