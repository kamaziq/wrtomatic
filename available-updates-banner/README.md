# OpenWRT Update Count Display

Single script to track and display the number of upgradable packages by appending to `/etc/banner`.

## Files
- `available-updates.sh` – Unified script:
  - Default (no args): runs `opkg update`, counts upgradable packages, logs to syslog (`available-updates`), stores count & timestamp, appends to `/etc/banner`.
  - `--install` : upgrades all packages listed by `opkg list-upgradable`.
  - `--get` : same as default (update counts).
  - Interactive TTY run (e.g. login shell) auto-prints the count after an update.
- `cron-example.txt` – Sample cron line for `/etc/crontabs/root`.

## What It Does
1. Preserves original banner to `/etc/banner.base` on first run (if not already saved).
2. Runs `opkg update` to refresh package lists.
3. Counts upgradable packages via `opkg list-upgradable`.
4. Stores count in `/tmp/opkg_upgradable_count` and timestamp in `/tmp/opkg_last_check`.
5. Logs the result to syslog (tag `available-updates`).
6. Rebuilds `/etc/banner` from base:
   - If updates available (count > 0): appends count line and separator.
   - If no updates (count = 0): restores clean base banner without extra lines.
7. Prints the count summary when invoked in interactive TTY.

## Deployment Steps
1. Copy script to router:
   ```sh
   scp available-updates.sh root@ROUTER_IP:/usr/sbin/available-updates.sh
   ```
2. Make executable:
   ```sh
   chmod +x /usr/sbin/available-updates.sh
   ```
3. Add cron entry (`/etc/crontabs/root`):
   ```
   0 */6 * * * /usr/sbin/available-updates.sh
   ```
4. Restart cron:
   ```sh
   /etc/init.d/cron restart
   ```
5. Initialize once manually (optional):
   ```sh
   /usr/sbin/available-updates.sh
   ```

## Adjusting Frequency
Hourly example:
```
0 * * * * /usr/sbin/available-updates.sh
```

## Notes
- Preserves original banner to `/etc/banner.base` before first modification.
- Safe to run repeatedly; always rebuilds `/etc/banner` fresh from base.
- When 0 updates available: banner reverts to clean base (no update line).
- When updates available: banner shows base + " X packages can be updated" + separator.
- Review packages individually before upgrading.

## Banner Format
When updates are available, your banner will append separator with available updates count:
```

-----------------------------------------------------
 5 packages can be updated
-----------------------------------------------------
```

When no updates are available (count = 0), the banner reverts to the clean base without the update line.

## Manual Upgrade Examples
List upgradable packages:
```sh
opkg list-upgradable
```
Upgrade a single package:
```sh
opkg upgrade <package-name>
```

## Troubleshooting
- If `opkg update` fails, previous count remains; syslog records failure.
- Low flash environments: temp files in `/tmp` (RAM) vanish on reboot; after reboot run update again.

## Restore Original Banner
To revert to the original banner:
```sh
[ -f /etc/banner.base ] && cp /etc/banner.base /etc/banner
```

## Upgrade All Available Packages
```sh
/usr/sbin/available-updates.sh --install
```
*Use with caution; review packages first.*

## View History in Syslog
```sh
logread | grep available-updates
```

Enjoy concise visibility into pending OpenWRT updates at every login.
