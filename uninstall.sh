#!/usr/bin/env bash
# Полная деинсталляция Saqta

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Saqta — uninstall${NC}"
echo ""

# LaunchAgent
if [ -f "$HOME/Library/LaunchAgents/com.saqta.autotranscribe.plist" ]; then
    echo "→ Удаляю LaunchAgent..."
    launchctl unload "$HOME/Library/LaunchAgents/com.saqta.autotranscribe.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.saqta.autotranscribe.plist"
    echo -e "${GREEN}✓ LaunchAgent удалён${NC}"
fi

# Scripts
if [ -d "$HOME/bin/saqta" ]; then
    echo "→ Удаляю скрипты..."
    rm -rf "$HOME/bin/saqta"
    echo -e "${GREEN}✓ Скрипты удалены${NC}"
fi

# Config (confirm)
if [ -d "$HOME/.config/saqta" ]; then
    echo -n "Удалить конфиг ~/.config/saqta? [y/N] "
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.config/saqta"
        echo -e "${GREEN}✓ Конфиг удалён${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Готово.${NC}"
echo ""
echo "Не тронуто (удали вручную если нужно):"
echo "  • ~/Recordings/           — твои записи"
echo "  • ~/whisper-models/       — модели Whisper"
echo "  • QuickRecorder.app       — brew uninstall --cask quickrecorder"
echo "  • CLI-зависимости         — brew uninstall whisper-cpp ffmpeg fswatch terminal-notifier jq"
