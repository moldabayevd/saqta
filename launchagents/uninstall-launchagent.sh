#!/usr/bin/env bash
# Убирает watcher из автозапуска

set -euo pipefail

PLIST_LABEL="com.saqta.autotranscribe"
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [ ! -f "$PLIST_FILE" ]; then
    echo "LaunchAgent не установлен"
    exit 0
fi

launchctl unload "$PLIST_FILE" 2>/dev/null || true
rm -f "$PLIST_FILE"

echo "✓ LaunchAgent удалён"
