### Available Updates Banner (Package Updates Count)
To display a color-coded banner after SSH login showing how many packages are upgradable:

1. Copy the script:
```sh
scp openwrt-update-banner.sh root@ROUTER_IP:/usr/local/bin/
ssh root@ROUTER_IP 'chmod 0755 /usr/local/bin/openwrt-update-banner.sh'
```
2. Hook it into `/etc/profile` (place near existing alert hook, order does not matter):
```sh
if [ -n "$SSH_CONNECTION" ]; then
    /usr/local/bin/openwrt-update-banner.sh || true
fi
```
3. (Optional) Adjust refresh/cache behavior by exporting variables before the call in `/etc/profile`:
```sh
export REFRESH_INTERVAL_SECONDS=1800   # 30 minutes
export AUTO_UPDATE_LISTS=1             # 0 to skip 'opkg update'
```

Behavior:
- Caches count in `/tmp/opkg_upgradable_count` for `REFRESH_INTERVAL_SECONDS` to avoid heavy repeated `opkg update` calls.
- Uses `opkg list-upgradable` to count packages; color is green (0), yellow (1-5), red (>5).
- Skips silently for non-interactive or missing `opkg`.

Manual refresh:
```sh
rm /tmp/opkg_upgradable_count; /usr/local/bin/openwrt-update-banner.sh
```
