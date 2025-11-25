#!/bin/sh
# OpenWRT SSH login alert script (BusyBox / ash compatible)
# Place at /usr/local/bin/ssh-login-alert.sh and make executable: chmod 0755
# Trigger from /etc/profile (see README).

# ---------------- Configuration ----------------
MAIL_TO="admin@example.com"
MAIL_FROM="openwrt@example.com"
SUBJECT_PREFIX="[OpenWRT SSH Login]"
HOSTNAME_OVERRIDE=""   # Leave empty to auto-detect via /bin/hostname
MSMTP_BIN="/usr/bin/msmtp"  # Path to msmtp. Adjust if different.
ENABLE_EMAIL="1"            # Set to 0 to disable sending (keeps syslog only)
SYSLOG_TAG="ssh-login-alert"

# -------------- Environment Checks -------------

# Only run for interactive SSH sessions.
case "$-" in
  *i*) : ;;  # interactive shell
  *) [ -n "$SSH_CONNECTION" ] || exit 0 ;;  # if non-interactive and no SSH, exit
esac

# Prevent duplicate execution within the same session.
if [ -n "$SSH_LOGIN_ALERT_RAN" ]; then
  exit 0
fi
export SSH_LOGIN_ALERT_RAN=1

NOW_UTC="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
HOST="${HOSTNAME_OVERRIDE:-$(/bin/hostname 2>/dev/null)}"
USER_NAME="${USER:-unknown}"  # BusyBox safe

# SSH_CLIENT: "IP_CLIENT PORT_CLIENT IP_SERVER PORT_SERVER"
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

# Collect optional command info (first command in history if available)
RECENT_CMD=""
if [ -f "$HOME/.ash_history" ]; then
  RECENT_CMD=$(tail -n 1 "$HOME/.ash_history" 2>/dev/null)
fi

# Build message body (plain text)
BODY="SSH Login Detected\n\n"
BODY="$BODY Host: $HOST\n"
BODY="$BODY User: $USER_NAME\n"
BODY="$BODY Time: $NOW_UTC\n"
BODY="$BODY Client IP: ${CLIENT_IP:-unknown}\n"
BODY="$BODY Client Port: ${CLIENT_PORT:-unknown}\n"
BODY="$BODY Server IP: ${SERVER_IP:-unknown}\n"
BODY="$BODY Server Port: ${SERVER_PORT:-unknown}\n"
BODY="$BODY TTY: $TTY_DEVICE\n"
if [ -n "$RECENT_CMD" ]; then
  BODY="$BODY Last Command (history tail): $RECENT_CMD\n"
fi
BODY="$BODY -----------------------------\n"

SUBJECT="$SUBJECT_PREFIX $USER_NAME from ${CLIENT_IP:-unknown} on $HOST"

# Syslog entry
logger -t "$SYSLOG_TAG" "Login: user=$USER_NAME client=$CLIENT_IP:$CLIENT_PORT tty=$TTY_DEVICE host=$HOST"

send_email() {
  [ "$ENABLE_EMAIL" = "1" ] || return 0
  if [ ! -x "$MSMTP_BIN" ]; then
    logger -t "$SYSLOG_TAG" "msmtp not found at $MSMTP_BIN; email suppressed"
    return 0
  fi
  # Compose email using a heredoc (BusyBox ash compatible)
  "$MSMTP_BIN" --debug -f "$MAIL_FROM" -t <<EOF >/dev/null 2>&1
From: $MAIL_FROM
To: $MAIL_TO
Subject: $SUBJECT
Date: $(date -R)
Content-Type: text/plain; charset=UTF-8

$BODY
EOF
  if [ "$?" -ne 0 ]; then
    logger -t "$SYSLOG_TAG" "Failed to send login email via msmtp"
  else
    logger -t "$SYSLOG_TAG" "Login email sent to $MAIL_TO"
  fi
}

send_email

exit 0
