#!/usr/bin/env bash
# install-meeting-detector.sh — устанавливает фоновый watcher meeting-detector
# как LaunchAgent (запуск при логине + автоматический рестарт при падении).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTOR="$REPO_ROOT/scripts/meeting-detector.sh"
PLIST_LABEL="com.saqta.meeting-detector"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

[ -x "$DETECTOR" ] || chmod +x "$DETECTOR"
[ -f "$DETECTOR" ] || { echo "✗ Не найден: $DETECTOR" >&2; exit 1; }

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Останавливаем старую версию если была
launchctl unload "$PLIST_PATH" 2>/dev/null || true

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${DETECTOR}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/saqta-meeting-detector.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/saqta-meeting-detector.stderr.log</string>

    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

launchctl load "$PLIST_PATH"

echo "✓ Meeting-detector установлен как LaunchAgent"
echo ""
echo "Что он делает:"
echo "  • Запускается автоматически при логине"
echo "  • Опрашивает раз в 3 сек: Zoom / Teams / Google Meet"
echo "  • При обнаружении встречи → открывает Saqta-виджет"
echo ""
echo "Управление:"
echo "  Лог:        ~/Library/Logs/saqta-meeting-detector.log"
echo "  Остановить: launchctl unload $PLIST_PATH"
echo "  Запустить:  launchctl load $PLIST_PATH"
echo "  Удалить:    bash launchagents/uninstall-meeting-detector.sh"
echo ""
echo "Проверить что работает:"
echo "  launchctl list | grep saqta"
