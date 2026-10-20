---
name: pi-docker-gotchas
description: "Pi Docker pitfalls: mounts, network, search."
---

# Pi Docker Gotchas

## Config Volume Mounts Fail Silently
On this host (Debian 13 arm64, Docker 26.1.5), mounting a local config directory into a container with `-v $(pwd)/config:/app/config` can silently shadow the image-baked config, causing `FileNotFoundError`. **Rule: bake configs into the image with COPY; only mount data/output directories.**

## Container Network = Domestic Only
The container can reach domestic sites (sina, people.com.cn, xinhuanet, solidot, jiemian) but NOT BBC, NYT, FT, Reuters, or other international outlets (`Network is unreachable`). RSS feeds must be selected accordingly. Tested working: `rss.sina.com.cn`, `people.com.cn/rss`, `xinhuanet.com/rss`, `solidot.org`.

## Web Search Backend
`ddgs` (DuckDuckGo search) is installed at `/opt/data/lazy-packages`. If `web_search` returns empty, check `python3 -c "import ddgs"` and reinstall with `python3 -m pip install ddgs` if needed.

## Image Build Pattern
Use `python:3.12-slim` base, `pip install --no-cache-dir`, and COPY baked configs. Tested working for small Python projects.

## Port Forwarding (User Preference: ALWAYS forward new ports)
When exposing a new container port to LAN, ALWAYS set up a socat forward on the host. User expects this to happen automatically without asking.
- Existing forwards: `host:8080 -> 172.17.0.2:8080` (PID 2316)
- SSH to host fails; use `docker run --network host` to run socat on host network
- After adding forward, verify with `curl http://172.17.0.1:<port>/`
- NOTE: `docker run -p PORT:PORT` already binds to 0.0.0.0, exposing the port on all host interfaces including LAN. socat is ONLY needed when docker's port mapping is insufficient (e.g., port already taken by a non-docker service). Verify with `curl http://<LAN-IP>:<port>/` before adding socat.

## Container IP Changes on Recreate
When a container is removed and recreated (`docker rm -f` + `docker run`), its bridge IP may change (e.g. 172.17.0.2 -> 172.17.0.3). Any socat forward pointing to the old IP will silently break. **Rule: after recreating a container, check its new IP with `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <name>` and update any forwards.**

## JS Syntax Validation for Inline HTML
When writing a single-file HTML frontend with inline `<script>`, always validate JS syntax before deploying. Extract with `sed -n '/<script>/,/<\/script>/p' | sed '1d;$d' > /tmp/check.js && node --check /tmp/check.js`. A single unclosed brace in a switch/case block kills the entire script, making all functions undefined.

## Reasoning Model Streaming — Read Both Fields
Reasoning models (e.g., LongCat-2.5-Preview) split SSE output across `delta.reasoning_content` (thinking) and `delta.content` (actual reply). Frontend MUST read both: `const delta = d?.content || d?.reasoning_content || ''`. Reading only `content` makes the model appear unresponsive — the thinking goes to `reasoning_content` and the reply may be a single short string at the end.

## Nginx Proxy Buffering Kills SSE
When proxying SSE streams through nginx, always set `proxy_buffering off; proxy_cache off;`. Without it, nginx buffers the entire response before sending — the frontend receives nothing until the stream completes, appearing as a network error or empty response.
