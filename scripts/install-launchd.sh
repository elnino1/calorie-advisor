#!/bin/bash
# Installe (ou réinstalle) la tâche launchd qui exécute refresh.sh deux fois par jour.
# launchd rattrape les exécutions manquées quand le Mac sort de veille.
# Désinstallation : scripts/install-launchd.sh --uninstall
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="local.calorieadvisor.refresh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$PLIST"
    echo "Tâche supprimée."
    exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/CalorieAdvisor"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$ROOT/scripts/refresh.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>30</integer></dict>
        <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/CalorieAdvisor/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/CalorieAdvisor/launchd.log</string>
</dict>
</plist>
PLIST

launchctl bootstrap "$DOMAIN" "$PLIST"
echo "Tâche installée : $PLIST"
echo "Test immédiat : launchctl kickstart -p $DOMAIN/$LABEL  (journal : ~/Library/Logs/CalorieAdvisor/refresh.log)"
