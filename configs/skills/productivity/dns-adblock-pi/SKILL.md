---
name: dns-adblock-pi
description: "DNS sinkhole ad blocking on the Pi."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, arm64]
---

# DNS Ad-Blocking on Raspberry Pi

Set up a DNS-level ad-blocking sinkhole (Pi-hole or dnsmasq + blocklists) on the Pi to block ads for all LAN devices.

**Alternative**: For a dedicated single-purpose DNS sinkhole, an ESP32-C3 costs less, uses ~0.5W, and is simpler to deploy. See `esp32-dns-adblock` skill. Choose the Pi approach only if you already run other services on it or want Pi-hole's web UI/statistics.

## Network requirements (critical)

**The Pi's LAN IP is 192.168.0.106** (WiFi). Clients must use this as their DNS server.

- Do NOT use 172.17.0.1 — that is the Docker bridge gateway, not the Pi's LAN address.
- The service MUST run with `--network host` so it binds to 192.168.0.106:53 and is reachable from LAN devices.
- Containers on the default bridge (172.17.0.x) are NOT reachable from the LAN.

## Deployment steps

1. Create config directory on host:
   ```bash
   mkdir -p /opt/data/dnsmasq
   ```

2. Create `/opt/data/dnsmasq/adblock.conf` with blocklist sources:
   ```
   server=/#/0.0.0.0
   addn-hosts=/etc/dnsmasq.d/blocklist.conf
   ```

3. Download blocklists (use domestic mirrors if needed):
   ```bash
   curl -sL "https://raw.githubusercontent.com/notracking/hostslists/master/hosts.txt" \
     -o /opt/data/dnsmasq/blocklist.conf
   ```

4. Run dnsmasq container with host networking:
   ```bash
   docker run -d --name dnsmasq-adblock --network host \
     --restart unless-stopped \
     -v /opt/data/dnsmasq:/etc/dnsmasq.d \
     andyshinn/dnsmasq:2.86
   ```

5. Verify from LAN client: `nslookup doubleclick.net 192.168.0.106` should return 0.0.0.0.

6. Configure router DHCP to assign 192.168.0.106 as DNS, OR set clients manually.

## Pitfalls

- **--network host is mandatory** — bridge mode makes the DNS server unreachable from LAN devices.
- **Port 53 conflicts**: If the host already runs a DNS resolver, stop it first (`systemctl stop systemd-resolved` or disable dnsmasq on host).
- **Image whitelist**: This Pi's Docker daemon restricts to an allowlist of images. If `andyshinn/dnsmasq` is blocked, try `cgr.dev/chainguard/dnsmasq` or build a minimal Alpine image with `apk add dnsmasq`.
- **DoH/DoT bypass**: Many modern apps (Chrome, Chinese mobile apps) use DNS-over-HTTPS/TLS, bypassing port 53 entirely. DNS sinkhole only works for clients using plaintext DNS on port 53.
- **Same-domain ads**: Ads served from the same domain as content (e.g., Tencent, ByteDance ad networks) cannot be blocked at the DNS level without breaking the content domain.
- **No sudo in container**: The container runs as user `hermes` (uid=1000). Use `docker run --rm ... --entrypoint sh alpine` to debug host-side paths.
- **Volume mount paths**: Docker daemon runs on the Pi HOST. Container path `/opt/data` maps to host `/home/jian/.hermes/`. Always verify host-side paths before mounting.

## Verification

```bash
# From container (if host networking):
dig @127.0.0.1 doubleclick.net +short
# Expected: 0.0.0.0

# From LAN client:
dig @192.168.0.106 doubleclick.net +short
# Expected: 0.0.0.0

# Check container logs:
docker logs dnsmasq-adblock
```

## References
- `references/blocklist-sources.md` — recommended blocklist feeds and update automation