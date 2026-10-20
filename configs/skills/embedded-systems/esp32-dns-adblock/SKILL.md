---
name: esp32-dns-adblock
description: "ESP32-C3 DNS sinkhole ad blocker firmware."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [esp32, esp32-c3]
---

# ESP32-C3 DNS AdBlock Sinkhole

Build a dedicated DNS ad-blocking server using an ESP32-C3. Lower power and cost than a Pi for this single-purpose task.

## When to use ESP32 vs Pi

- **ESP32-C3**: Dedicated always-on DNS sinkhole, ~0.5W power, ¥20-30 cost. Preferred for single-purpose ad blocking.
- **Pi**: If already running other services, or need Pi-hole's web UI and statistics.

## Network requirements

- Router DHCP must assign the ESP32's IP as the DNS server (or set clients manually).
- ESP32 and clients must be on the same LAN subnet.
- The ESP32 gets its IP via DHCP — reserve it in the router or use a static IP.

## Firmware architecture

The ESP32 runs a UDP DNS server on port 53. For each query:
1. Parse the domain from the DNS request.
2. Check against a blacklist of ad domains.
3. If matched → return `0.0.0.0` (sinkhole).
4. If not matched → forward the raw DNS packet to an upstream resolver (e.g., 223.5.5.5) and return the response.

**Critical**: Use raw UDP forwarding, NOT the `DNSServer` library's `start()` with `"*"` — that resolves ALL queries to the ESP32's own IP, breaking all internet connectivity.

## Flashing steps

1. Install ESP32 Arduino Core: Arduino IDE → File → Preferences → Additional board URLs → add `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. Board Manager → search `esp32` → install.
3. Open the template: `templates/esp32-dns-adblock.ino`
4. Board: `ESP32C3 Dev Module`, Flash Mode: QIO, Flash Size: 4MB.
5. Upload.
6. Serial monitor (115200 baud) shows connection status.

## First-time provisioning

1. ESP32 starts AP mode: `ESP32-ADBLOCK` / password `12345678`.
2. Connect to that AP, browse to `192.168.4.1`.
3. Enter home WiFi credentials.
4. ESP32 restarts, connects to WiFi, starts DNS on port 53.
5. Serial monitor prints the assigned IP.

## Router configuration

- **DHCP DNS**: Set the ESP32's IP as the primary DNS server in router DHCP settings.
- **DHCP lease**: Reserve the ESP32's MAC → IP mapping so it always gets the same address.
- **Gateway**: Keep the router's own IP (e.g., 192.168.0.1) as gateway — do NOT change gateway to ESP32.

## Testing

From a LAN client:
```bash
# Verify DNS points to ESP32
nslookup
# Default Server should show the ESP32 IP

# Test ad domain (should return 0.0.0.0)
nslookup ad.qq.com

# Test normal domain (should return real IP)
nslookup www.baidu.com

# Compare: bypass ESP32, query upstream directly
nslookup ad.qq.com 223.5.5.5
# Should return real ad server IP — confirms ESP32 is blocking
```

## Pitfalls

- **DNSServer library sinkhole-all bug**: `dnsServer.start(DNS_PORT, "*", WiFi.localIP())` resolves every query to the ESP2's own IP. All internet breaks. Use raw UDP forwarding instead.
- **DHCP DNS not applied**: After changing router DHCP DNS setting, clients must renew their lease (`ipconfig /release && ipconfig /renew` on Windows, toggle WiFi on mobile).
- **DoH/DoT bypass**: Apps using DNS-over-HTTPS/TLS (Chrome, many Chinese mobile apps) bypass port 53 entirely. Sinkhole only works for plaintext DNS.
- **Same-domain ads**: Ads served from the same domain as content (Tencent, ByteDance) cannot be blocked at DNS level without breaking content.

## References
- `references/blocklist-sources.md` — recommended blocklist feeds and update automation