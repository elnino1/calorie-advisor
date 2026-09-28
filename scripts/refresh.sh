#!/bin/bash
# Re-signe et réinstalle CalorieAdvisor sur l'iPhone avant l'expiration du profil gratuit (7 jours).
# Usage : scripts/refresh.sh [--force]
#   --force : reconstruit et réinstalle même si la signature est encore valide
#             (à utiliser après une modification du code).
# Les données de l'app (journal, aliments) sont conservées : l'installation est une mise à jour.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/scripts/refresh.config"
LOCAL_XCCONFIG="$ROOT/Config/Signing.local.xcconfig"
DERIVED="$ROOT/build"
APP="$DERIVED/Build/Products/Release-iphoneos/CalorieAdvisor.app"
STATE_DIR="$HOME/Library/Application Support/CalorieAdvisor"
STATE_FILE="$STATE_DIR/installed_expiry"
LOG_DIR="$HOME/Library/Logs/CalorieAdvisor"
PROFILE_DIRS=("$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "$HOME/Library/MobileDevice/Provisioning Profiles")

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
mkdir -p "$STATE_DIR" "$LOG_DIR"
LOG="$LOG_DIR/refresh.log"
exec > >(tee -a "$LOG") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
notify() {
    osascript -e "display notification \"$1\" with title \"CalorieAdvisor\"" >/dev/null 2>&1 || true
}
fail() { log "ERREUR : $*"; notify "$*"; exit 1; }

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

[[ -f "$CONFIG" ]] || fail "Configuration manquante : copiez scripts/refresh.config.example en scripts/refresh.config"
# shellcheck source=/dev/null
source "$CONFIG"
: "${DEVICE_ID:?DEVICE_ID manquant dans refresh.config}"
if [[ "$DEVICE_ID" == 00000000-* ]]; then
    fail "DEVICE_ID est encore la valeur d'exemple dans scripts/refresh.config : lancez 'xcrun devicectl list devices' et copiez l'Identifier de l'iPhone"
fi
RENEW_THRESHOLD_HOURS="${RENEW_THRESHOLD_HOURS:-72}"

[[ -f "$LOCAL_XCCONFIG" ]] || fail "Config/Signing.local.xcconfig manquant (voir README)"
BUNDLE_ID="$(sed -n 's/^[[:space:]]*BUNDLE_ID[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p' "$LOCAL_XCCONFIG" | tail -1)"
[[ -n "$BUNDLE_ID" ]] || fail "BUNDLE_ID introuvable dans Signing.local.xcconfig"
TEAM_ID="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' "$LOCAL_XCCONFIG" | tail -1 | tr -d '[:space:]')"
if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    fail "DEVELOPMENT_TEAM doit être l'identifiant de 10 caractères (pas le nom). Pour le trouver : security find-certificate -a -c \"Apple Development\" -p | openssl x509 -noout -subject  (valeur OU=)"
fi

# Date d'expiration (epoch) du profil de provisionnement d'un .app ou d'un fichier .mobileprovision.
profile_expiry() {
    local file="$1" tmp date
    [[ -f "$file" ]] || { echo 0; return; }
    tmp="$(mktemp)"
    if security cms -D -i "$file" > "$tmp" 2>/dev/null \
        && date="$(plutil -extract ExpirationDate raw -o - "$tmp" 2>/dev/null)"; then
        date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$date" +%s 2>/dev/null || echo 0
    else
        echo 0
    fi
    rm -f "$tmp"
}

# Supprime les profils en cache pour ce bundle id afin que Xcode en génère un neuf (7 jours pleins).
purge_cached_profiles() {
    local dir file tmp appid
    for dir in "${PROFILE_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.mobileprovision "$dir"/*.provisionprofile; do
            [[ -f "$file" ]] || continue
            tmp="$(mktemp)"
            if security cms -D -i "$file" > "$tmp" 2>/dev/null; then
                appid="$(plutil -extract Entitlements.application-identifier raw -o - "$tmp" 2>/dev/null || true)"
                if [[ "$appid" == *".$BUNDLE_ID" ]]; then
                    log "Suppression du profil en cache $(basename "$file")"
                    rm -f "$file"
                fi
            fi
            rm -f "$tmp"
        done
    done
}

now="$(date +%s)"
threshold=$((RENEW_THRESHOLD_HOURS * 3600))
installed_expiry="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
remaining=$((installed_expiry - now))

if [[ $FORCE -eq 0 && $remaining -gt $threshold ]]; then
    log "Signature valide encore $((remaining / 3600)) h, rien à faire."
    exit 0
fi

log "Renouvellement (restant : $((remaining > 0 ? remaining / 3600 : 0)) h, force=$FORCE)"

# 1. Projet Xcode (généré par XcodeGen depuis project.yml)
# (toujours avec --force, pour prendre en compte les fichiers Swift ajoutés)
if [[ $FORCE -eq 1 || ! -d "$ROOT/CalorieAdvisor.xcodeproj" || "$ROOT/project.yml" -nt "$ROOT/CalorieAdvisor.xcodeproj/project.pbxproj" ]]; then
    command -v xcodegen >/dev/null || fail "xcodegen introuvable (brew install xcodegen)"
    log "Génération du projet Xcode"
    (cd "$ROOT" && xcodegen generate --quiet)
fi

# 2. Nouveau profil : on ne réutilise un profil en cache que s'il dure encore plus de 6 jours.
built_expiry="$(profile_expiry "$APP/embedded.mobileprovision")"
if (( built_expiry - now < 6 * 86400 )); then
    purge_cached_profiles
fi

# 3. Compilation et signature
log "Compilation…"
if ! xcodebuild \
    -project "$ROOT/CalorieAdvisor.xcodeproj" \
    -scheme CalorieAdvisor \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build > "$LOG_DIR/xcodebuild.log" 2>&1; then
    tail -30 "$LOG_DIR/xcodebuild.log"
    fail "Échec de la compilation (voir $LOG_DIR/xcodebuild.log)"
fi

built_expiry="$(profile_expiry "$APP/embedded.mobileprovision")"
log "Profil valide jusqu'au $(date -r "$built_expiry" '+%Y-%m-%d %H:%M')"

# 4. Installation (mise à jour en place, les données sont conservées)
log "Installation sur l'appareil ${DEVICE_ID}…"
if ! xcrun devicectl device install app --device "$DEVICE_ID" "$APP" > "$LOG_DIR/install.log" 2>&1; then
    tail -20 "$LOG_DIR/install.log"
    hours_left=$(( (installed_expiry - now) / 3600 ))
    if (( installed_expiry > 0 && hours_left < 24 )); then
        fail "iPhone injoignable, l'app expire dans ${hours_left} h ! Branchez-le ou mettez-le sur le même Wi-Fi."
    fi
    fail "iPhone injoignable (déverrouillé, même Wi-Fi ?). Nouvel essai à la prochaine exécution."
fi

echo "$built_expiry" > "$STATE_FILE"
log "OK, app valide jusqu'au $(date -r "$built_expiry" '+%Y-%m-%d %H:%M')"
notify "App rafraîchie, valide jusqu'au $(date -r "$built_expiry" '+%d/%m %H:%M')"
