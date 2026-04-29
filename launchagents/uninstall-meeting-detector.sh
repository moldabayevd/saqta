#!/usr/bin/env bash
# uninstall-meeting-detector.sh — удаляет meeting-detector LaunchAgent.

set -euo pipefail

PLIST_LABEL="com.saqta.meeting-detector"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "✓ Meeting-detector удалён"
else
    echo "ℹ Meeting-detector не был установлен"
fi

# Чистим state-файлы
rm -f /tmp/saqta-meeting-state /tmp/saqta-meeting-cooldown
