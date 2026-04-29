#!/usr/bin/env bash
# meeting-detector.sh — фоновый демон, который детектит запуск встречи и
# вызывает Saqta-виджет.
#
# Что мониторит:
#   - Zoom (zoom.us)
#   - Microsoft Teams
#   - Google Meet (через активную вкладку Chrome / Safari / Arc)
#   - Discord (опционально, нужно подтверждение)
#
# Логика:
#   - Опрос раз в 3 секунды
#   - Когда встреча обнаружена впервые → запускает Saqta с флагом --widget
#   - Когда встреча закончилась → сбрасывает state
#   - Cooldown 2 минуты после ручного "пропустить" — чтобы не доставать
#
# Лог: ~/Library/Logs/saqta-meeting-detector.log

set -u

LOG_FILE="$HOME/Library/Logs/saqta-meeting-detector.log"
STATE_FILE="/tmp/saqta-meeting-state"
COOLDOWN_FILE="/tmp/saqta-meeting-cooldown"
COOLDOWN_SECS=120

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Проверка одного источника — Zoom
check_zoom() {
    pgrep -x "zoom.us" >/dev/null 2>&1
}

# Microsoft Teams (новый и старый)
check_teams() {
    pgrep -fi "Microsoft Teams" >/dev/null 2>&1 && return 0
    pgrep -fi "MSTeams" >/dev/null 2>&1 && return 0
    return 1
}

# Google Meet через AppleScript — проверяем активные вкладки браузеров
check_google_meet() {
    # Chrome
    if pgrep -x "Google Chrome" >/dev/null 2>&1; then
        local result
        result=$(osascript -e '
            tell application "Google Chrome"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "meet.google.com/" and URL of t does not contain "meet.google.com/landing" then
                                return "yes"
                            end if
                        end repeat
                    end repeat
                end try
                return "no"
            end tell' 2>/dev/null || echo "no")
        [ "$result" = "yes" ] && return 0
    fi

    # Safari
    if pgrep -x "Safari" >/dev/null 2>&1; then
        local result
        result=$(osascript -e '
            tell application "Safari"
                try
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "meet.google.com/" and URL of t does not contain "meet.google.com/landing" then
                                return "yes"
                            end if
                        end repeat
                    end repeat
                end try
                return "no"
            end tell' 2>/dev/null || echo "no")
        [ "$result" = "yes" ] && return 0
    fi

    # Arc браузер тоже основан на Chromium и доступен через AppleScript
    if pgrep -x "Arc" >/dev/null 2>&1; then
        local result
        result=$(osascript -e '
            tell application "Arc"
                try
                    repeat with t in tabs of front window
                        if URL of t contains "meet.google.com/" then return "yes"
                    end repeat
                end try
                return "no"
            end tell' 2>/dev/null || echo "no")
        [ "$result" = "yes" ] && return 0
    fi

    return 1
}

# Главная проверка — есть ли активная встреча
is_meeting_active() {
    local source=""
    check_zoom         && { source="Zoom"; echo "$source"; return 0; }
    check_teams        && { source="Teams"; echo "$source"; return 0; }
    check_google_meet  && { source="Google Meet"; echo "$source"; return 0; }
    return 1
}

# Запуск Saqta в режиме виджета
trigger_widget() {
    local source="$1"
    log "Detected meeting: $source — launching widget"

    # Ищем установленную Saqta.app (после tauri:build) или fallback на dev
    if [ -d "/Applications/Saqta.app" ]; then
        open -a "Saqta" --args --widget --source="$source"
    elif [ -d "$HOME/Applications/Saqta.app" ]; then
        open -a "$HOME/Applications/Saqta.app" --args --widget --source="$source"
    else
        # Fallback: уведомление если приложения нет
        osascript -e "display notification \"Похоже, у вас встреча в $source. Запиши через ⌘⇧R.\" with title \"Saqta\" sound name \"Glass\"" 2>/dev/null
        log "Saqta.app not found — sent notification instead"
    fi
}

# Cooldown активен?
in_cooldown() {
    [ -f "$COOLDOWN_FILE" ] || return 1
    local age
    age=$(($(date +%s) - $(stat -f %m "$COOLDOWN_FILE" 2>/dev/null || echo 0)))
    [ "$age" -lt "$COOLDOWN_SECS" ]
}

# Главный цикл
log "meeting-detector started (pid $$)"

while true; do
    source=$(is_meeting_active 2>/dev/null) && active=1 || active=0

    if [ "$active" = "1" ]; then
        if [ ! -f "$STATE_FILE" ]; then
            # Встреча только что началась
            echo "$source" > "$STATE_FILE"
            if ! in_cooldown; then
                trigger_widget "$source"
            else
                log "In cooldown, skipping trigger"
            fi
        fi
    else
        if [ -f "$STATE_FILE" ]; then
            log "Meeting ended"
            rm -f "$STATE_FILE"
        fi
    fi

    sleep 3
done
