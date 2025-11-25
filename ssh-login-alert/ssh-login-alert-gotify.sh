#!/bin/sh
# OpenWRT SSH login alert script (Gotify webhook variant)
# Sends a notification to a Gotify server instead of email.
# Requirements: curl (opkg install curl), reachable Gotify server + app token.

# --------------- Configuration ----------------
GOTIFY_URL="https://gotify.example.com"  # Base URL, no trailing slash
GOTIFY_TOKEN="REPLACE_WITH_TOKEN"        # App token from Gotify UI
GOTIFY_PRIORITY="5"                      # 0..10 (Gotify default 0 or 5 depending on config)
TITLE_PREFIX="SSH Login"                 # Title prefix for notification
HOSTNAME_OVERRIDE=""                    # Leave empty for auto-detect
ENABLE_GOTIFY="1"                        # Set 0 to disable sending (keeps syslog only)
SYSLOG_TAG="ssh-login-alert"
RATE_LIMIT_SECONDS="0"                   # Set >0 to avoid spam (e.g. 30)
STAMP_FILE="/tmp/ssh-login-gotify-last"

# -------------- Environment Checks -------------
case "$-" in
  *i*) : ;;
  *) [ -n "$SSH_CONNECTION" ] || exit 0 ;;
esac

if [ -n "$SSH_LOGIN_ALERT_GOTIFY_RAN" ]; then
  exit 0
fi
export SSH_LOGIN_ALERT_GOTIFY_RAN=1

# Rate limiting
if [ "$RATE_LIMIT_SECONDS" -gt 0 ]; then
  NOW_S="$(date +%s)"
  if [ -f "$STAMP_FILE" ]; then
    LAST_S=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
    DIFF=$((NOW_S - LAST_S))
    if [ "$DIFF" -lt "$RATE_LIMIT_SECONDS" ]; then
      logger -t "$SYSLOG_TAG" "Rate limit: skipping Gotify alert (diff=${DIFF}s)"
      exit 0
    fi
  fi
  echo "$NOW_S" > "$STAMP_FILE"
fi

HOST="${HOSTNAME_OVERRIDE:-$(/bin/hostname 2>/dev/null)}"
UTC_TS="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
USER_NAME="${USER:-unknown}"

CLIENT_IP="" CLIENT_PORT="" SERVER_IP="" SERVER_PORT=""
if [ -n "$SSH_CLIENT" ]; then
  CLIENT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
  CLIENT_PORT=$(echo "$SSH_CLIENT" | awk '{print $2}')
fi
if [ -n "$SSH_CONNECTION" ]; then
  SERVER_IP=$(echo "$SSH_CONNECTION" | awk '{print $3}')
  SERVER_PORT=$(echo "$SSH_CONNECTION" | awk '{print $4}')
fi

TTY_DEVICE="$(tty 2>/dev/null || echo unknown)"
LAST_CMD=""
if [ -f "$HOME/.ash_history" ]; then
  LAST_CMD=$(tail -n 1 "$HOME/.ash_history" 2>/dev/null)
fi

MESSAGE="SSH login detected\nHost: $HOST\nUser: $USER_NAME\nTime: $UTC_TS\nClient: ${CLIENT_IP:-unknown}:$CLIENT_PORT\nServer: ${SERVER_IP:-unknown}:$SERVER_PORT\nTTY: $TTY_DEVICE"
if [ -n "$LAST_CMD" ]; then
  MESSAGE="$MESSAGE\nLast CMD: $LAST_CMD"
fi

TITLE="$TITLE_PREFIX - $USER_NAME@$HOST from ${CLIENT_IP:-unknown}"

logger -t "$SYSLOG_TAG" "Login: user=$USER_NAME client=$CLIENT_IP:$CLIENT_PORT tty=$TTY_DEVICE host=$HOST"

send_gotify() {
  [ "$ENABLE_GOTIFY" = "1" ] || return 0
  [ -n "$GOTIFY_URL" ] || { logger -t "$SYSLOG_TAG" "GOTIFY_URL not set"; return 1; }
  [ -n "$GOTIFY_TOKEN" ] || { logger -t "$SYSLOG_TAG" "GOTIFY_TOKEN not set"; return 1; }

  # Gotify expects POST /message with JSON {title, message, priority}
  # Token provided via X-Gotify-Key header.
  JSON_PAYLOAD="{\"title\":\"${TITLE}\",\"message\":\"$(echo "$MESSAGE" | sed 's/"/\\"/g')\",\"priority\":${GOTIFY_PRIORITY}}"

  curl -s -X POST "${GOTIFY_URL}/message" \
    -H "Content-Type: application/json" \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -d "$JSON_PAYLOAD" >/dev/null 2>&1
  RC=$?
  if [ $RC -ne 0 ]; then
    logger -t "$SYSLOG_TAG" "Gotify POST failed rc=$RC"
  else
    logger -t "$SYSLOG_TAG" "Gotify alert sent"
  fi
}

send_gotify

exit 0
