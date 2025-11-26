#!/bin/sh
# 
# Unified script: records count of upgradable packages and appends to /etc/banner.
# - Default (no args): update counts + syslog entry + banner append.
# - --install : upgrade all packages listed by opkg list-upgradable.
# - --get : same as default (update counts).
# Install at /usr/sbin/available-updates.sh on your OpenWRT device.
# Cron example:
# 0 */6 * * * /usr/sbin/available-updates.sh

set -eu

COUNT_FILE="/tmp/opkg_upgradable_count"
TIMESTAMP_FILE="/tmp/opkg_last_check"
LOGGER_TAG="available-updates"
BASE_BANNER="/etc/banner.base"
CURRENT_BANNER="/etc/banner"

print_count() {
    [ -r "$COUNT_FILE" ] && COUNT=$(cat "$COUNT_FILE") || COUNT="?"
    [ -r "$TIMESTAMP_FILE" ] && WHEN=$(cat "$TIMESTAMP_FILE") || WHEN="(no timestamp)"
    printf "\nFound %s upgradable packages (last check: %s UTC)\n" "$COUNT" "$WHEN"
    if [ "$COUNT" != "0" ] 2>/dev/null; then
        echo "View: opkg list-upgradable"
    fi
}

MODE="get"  # default
for arg in "$@"; do
    case "$arg" in
        --install|install) MODE="install" ;;
        --get|get) MODE="get" ;;
    esac
done

if [ "$MODE" = "install" ]; then
    opkg list-upgradable | cut -f 1 -d ' ' | xargs -r opkg upgrade
    exit 0
fi

# Preserve original banner on first run
if [ ! -f "$BASE_BANNER" ]; then
    cp "$CURRENT_BANNER" "$BASE_BANNER" 2>/dev/null || echo "(no original banner captured)" > "$BASE_BANNER"
fi

if opkg update >/dev/null 2>&1; then UPDATE_STATUS=0; else UPDATE_STATUS=$?; echo "opkg update failed" >&2; fi

# Count upgradable packages
UPGRADABLE="$(opkg list-upgradable 2>/dev/null | wc -l | awk '{print $1}')" ; [ -n "$UPGRADABLE" ] || UPGRADABLE=0

echo "$UPGRADABLE" > "$COUNT_FILE"
DATE_LOCAL="$(date +%Y-%m-%dT%H:%M:%S)"
echo "$DATE_LOCAL" > "$TIMESTAMP_FILE"

# Syslog entry
if [ "$UPDATE_STATUS" -eq 0 ]; then logger -t "$LOGGER_TAG" "Found $UPGRADABLE upgradable packages (checked $DATE_LOCAL)"; else logger -t "$LOGGER_TAG" "opkg update failed; last known upgradable packages: $UPGRADABLE (attempt $DATE_LOCAL)"; fi

# Rebuild banner with appended count line
TMP="${CURRENT_BANNER}.tmp.$$"
{
    cat "$BASE_BANNER" 2>/dev/null || true
    if [ "$UPGRADABLE" -gt 0 ]; then
        printf " %s packages can be updated\n" "$UPGRADABLE"
        printf " -----------------------------------------------------\n"
    fi
} > "$TMP" && mv "$TMP" "$CURRENT_BANNER"

# If running in interactive TTY, also show current count after update
if [ -t 0 ]; then
    print_count
fi

exit 0
