---
name: docker-service-development
description: Build and run Docker services on the Raspberry Pi.
---

# Docker Service Development

## Multi-stage Python builds (critical)
When using `pip install --prefix=/install` in a multi-stage build, the runtime stage needs BOTH:
- `ENV PATH=/install/bin:$PATH` — to find executables
- `ENV PYTHONPATH=/install/lib/python3.12/site-packages` — to find Python modules

Without PYTHONPATH, the container starts but crashes with `ModuleNotFoundError` at runtime. The error appears in `docker logs` as the container restart-loops.

## Container networking
When a service runs in a container on the host's Docker:
- From the host: `localhost:PORT` or `127.0.0.1:PORT`
- From inside another container: use the bridge gateway IP `172.17.0.1:PORT` — NOT localhost
- From LAN devices: use the Pi's LAN IP:PORT

**Network reachability**: containers on this Pi can ONLY access domestic Chinese sites. BBC, Reuters, NYT, FT, and most international outlets return `Network is unreachable` or timeout. Do not waste build cycles testing international RSS feeds inside containers — validate against `*.com.cn`, `*.gov.cn`, and known-domestic sources (solidot, 新华网, 人民网, 新浪).

**TTS services**: Edge TTS (speech.platform.bing.com) returns 403 from Chinese IPs — the WebSocket connection is rejected. Do not use Edge TTS in containers on this Pi. Use domestic alternatives (百度/讯飞 TTS API) or local offline TTS (espeak, piper) instead.

**Edge TTS Python workaround**: The Node.js `msedge-tts` library gets 403 from China IPs, but Python `edge-tts` (v7.3.1) uses a different protocol and connects successfully. Install with `python3 -m pip install edge-tts` and call via subprocess. Working example:
```python
import asyncio, edge_tts
async def synth(text, voice, out):
    tts = edge_tts.Communicate(text, voice)
    await tts.save(out)
asyncio.run(synth("你好", "zh-CN-XiaoxiaoNeural", "out.mp3"))
```
To integrate into a Node.js project, replace the msedge-tts import with `child_process.execFile` calling `python3 -c` with the above script. This avoids the 403 entirely.

## Pi constraints
- 2GB RAM total, ~500MB available for containers
- Use `--memory=192m --cpus=0.5` per container
- No docker compose plugin — use `docker run` directly
- Kernel may not support cgroup memory limits (warning is harmless)
- Port 8080 is occupied by the Hermes gateway — use 8081+ for new services

## Volume mount paths: host vs container
The Docker daemon runs on the Pi host, NOT inside the container. When using `docker run -v /opt/data/...:/app/...`, the daemon interprets the host path — but `/opt/data` is the container's path. The host's equivalent is `/home/jian/.hermes/`. **Rule: always use host-side paths for volume mounts.** Test with `ls /home/jian/.hermes/path/to/file` before running the container.

```bash
# WRONG (container path — daemon can't find it):
docker run -v /opt/data/project/config.json:/app/config.json ...

# RIGHT (host path — daemon resolves correctly):
docker run -v /home/jian/.hermes/project/config.json:/app/config.json ...
```

## Alpine mirror pitfall
TUNA (tuna.tsinghua.edu.cn) returns 403 on this Pi. If a Dockerfile switches apk to TUNA, replace with aliyun in BOTH the ARG and the RUN instruction:
```dockerfile
ARG APK_MIRROR=https://mirrors.aliyun.com/alpine
RUN sed -i 's|dl-cdn.alpinelinux.org/alpine|mirrors.aliyun.com/alpine|g' /etc/apk/repositories
```
Tsinghua mirror is intermittently 403 — aliyun is the reliable fallback.

## Build and run
```bash
# Build
docker build -t name:tag .

# Run
docker run -d --name name --restart unless-stopped \
  -p PORT:PORT \
  -e KEY=value \
  -v volume-name:/path \
  --memory=192m --cpus=0.5 \
  name:tag

# Verify (from host)
curl http://127.0.0.1:PORT/health

# Verify (from inside a container)
curl http://172.17.0.1:PORT/health
```

## RSS source validation (non-negotiable)
Many URLs that look like RSS feeds return HTML pages — feedparser parses them as 0 entries. Before deploying any news/feed service, validate every source:

```python
import requests, feedparser
r = requests.get(url, timeout=10, headers={'User-Agent': 'Mozilla/5.0'})
feed = feedparser.parse(r.content)
assert len(feed.entries) > 0, f"{name}: 0 entries"
```

Known-working domestic sources: 新华网 (`xinhuanet.com`), 人民网 (`people.com.cn`), 新浪新闻 (`rss.sina.com.cn`), Solidot (`solidot.org`). Always test inside the actual container, not the host.

## Volume mount pitfall
When mounting a config directory (`-v $(pwd)/config:/app/config`), if the host path doesn't match or is empty, the container sees an empty/missing directory and crashes with `FileNotFoundError`. Verify with `docker run --rm image ls /app/config/` before the full run. Prefer baking config into the image (`COPY config/`) for immutable defaults, mount only for user overrides.

**File-vs-directory mount error**: Binding a file (`-v host/file.json:/app/file.json`) fails with "not a directory: Are you trying to mount a directory onto a file" when the destination path already exists as a directory (or vice versa). Before mounting a file, verify the container target path does NOT already exist as a directory: `docker run --rm image ls /app/file.json`.

**Permission denied on output dirs**: When a container writes to a volume-mounted directory that was created by root (e.g. via a prior Docker build), the hermes user gets EACCES. Fix by running a throwaway container as root:
```bash
docker run --rm -v /host/path:/data alpine sh -c "mkdir -p /data/sub && chmod -R 777 /data/sub"
```
This is simpler than rebuilding the image or changing ownership on the host.

## References
- `references/nginx-reverse-proxy-frontend.md` — nginx reverse proxy for frontend+API split, SSE streaming config, reasoning model streaming pattern