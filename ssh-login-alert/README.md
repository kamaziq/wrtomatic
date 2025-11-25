## SSH Login Alert Script (OpenWRT)

This repository provides a lightweight BusyBox `ash` compatible script that sends an email (via `msmtp`) and logs to syslog whenever an interactive SSH session starts on an OpenWRT router.

### 1. Features
- Captures user, client IP/port, server IP/port, UTC time, TTY.
- Optional last command from `.ash_history` (if present).
- Syslog entry via `logger` regardless of email status.
- Guard against duplicate execution within the same session.
- No bash-isms; safe for BusyBox `sh`.

### 2. Requirements
Install `msmtp` (or adjust script for `ssmtp` if preferred):

```sh
opkg update
opkg install msmtp ca-certificates
```

Create `/etc/msmtprc` with appropriate SMTP relay settings, e.g.:

```sh
account default
host smtp.example.com
port 587
auth on
user smtp-user@example.com
password yourpassword
from openwrt@example.com
tls on
tls_starttls on
logfile /var/log/msmtp.log
```

Ensure permissions:

```sh
chmod 600 /etc/msmtprc
```

### 3. Deploy Script
Copy `ssh-login-alert.sh` to your router (example using `scp` from workstation):

```sh
scp ssh-login-alert.sh root@ROUTER_IP:/usr/local/bin/
ssh root@ROUTER_IP 'chmod 0755 /usr/local/bin/ssh-login-alert.sh'
```

### 4. Hook Into Login
Append this guard block near the end of `/etc/profile` (but before any interactive menu scripts) so it runs only for SSH interactive sessions:

```sh
# SSH login alert hook
if [ -n "$SSH_CONNECTION" ]; then
    /usr/local/bin/ssh-login-alert.sh || true
fi
```

Alternative (OpenSSH only): If you use OpenSSH server instead of Dropbear, you can use an `sshrc` file:

```sh
echo '/usr/local/bin/ssh-login-alert.sh || true' >> /etc/ssh/sshrc
```

### 5. Configuration
Edit the variables at the top of `ssh-login-alert.sh`:

```sh
MAIL_TO="admin@example.com"
MAIL_FROM="openwrt@example.com"
SUBJECT_PREFIX="[OpenWRT SSH Login]"
ENABLE_EMAIL="1"  # set 0 to disable emails
```

### 6. Testing
SSH into the router:

```sh
ssh root@ROUTER_IP
```

Then check syslog:

```sh
logread | grep ssh-login-alert
```

And verify mail was delivered. If mail fails, the script logs an msmtp error line.

### 7. Troubleshooting
- No email: run `/usr/bin/msmtp --debug -t < sample.eml` to validate SMTP settings.
- Missing client IP: ensure `SSH_CONNECTION` or `SSH_CLIENT` environment variables exist (non-SSH shells won't set them).
- Multiple emails: Confirm only one invocation in `/etc/profile` and that the `SSH_LOGIN_ALERT_RAN` variable isn't being cleared.

### 8. Customization Ideas
- Add geo-IP lookup via a lightweight HTTP API (curl call) if `curl` installed.
- Push to webhook instead of email (replace `send_email` function with `curl -X POST`).
- Rate-limit alerts (maintain a timestamp file and skip if too frequent).

### 8.a Gotify Variant
If you prefer push notifications via a Gotify server instead of email, use the provided `ssh-login-alert-gotify.sh` file.

Requirements:
```sh
opkg update
opkg install curl
```

Configuration variables at the top of the script:
```sh
GOTIFY_URL="https://gotify.example.com"   # Base URL
GOTIFY_TOKEN="REPLACE_WITH_TOKEN"         # App token from Gotify
GOTIFY_PRIORITY="5"                       # 0..10
RATE_LIMIT_SECONDS="30"                   # Optional rate limit (0 disables)
```

Deploy:
```sh
scp ssh-login-alert-gotify.sh root@ROUTER_IP:/usr/local/bin/
ssh root@ROUTER_IP 'chmod 0755 /usr/local/bin/ssh-login-alert-gotify.sh'
```

Hook (choose this instead of the email version):
```sh
if [ -n "$SSH_CONNECTION" ]; then
    /usr/local/bin/ssh-login-alert-gotify.sh || true
fi
```

The script posts `title`, `message`, and `priority` JSON to `${GOTIFY_URL}/message` with header `X-Gotify-Key: <token>`.
Rate limiting prevents spamming during scripted or repeated sessions.

### 9. Security Notes
- Keep `/etc/msmtprc` permissions strict (600) to protect SMTP credentials.
- Consider using an SMTP relay with an app-specific password.
- Monitor `/var/log/msmtp.log` and `logread` for unusual patterns.

### 10. Removal
Delete the hook line from `/etc/profile` and remove the script:

```sh
sed -i '/ssh-login-alert.sh/d' /etc/profile
rm /usr/local/bin/ssh-login-alert.sh
```

---
For enhancements (e.g., webhook integration), feel free to request an updated version.
