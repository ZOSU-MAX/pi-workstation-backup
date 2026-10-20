# Nginx Reverse Proxy for Frontend + API Split

When a single-file HTML frontend needs to call an API running in a separate container, use nginx as a reverse proxy so the frontend can use relative URLs (`/v1/...`).

## Pattern

```nginx
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /v1/ {
        proxy_pass http://API_CONTAINER_IP:PORT;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://API_CONTAINER_IP:PORT;
    }
}
```

## Streaming (SSE) — critical

For streaming responses (SSE), disable nginx buffering:

```nginx
location /v1/ {
    proxy_pass http://API_CONTAINER_IP:PORT;
    proxy_buffering off;
    proxy_cache off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding off;
}
```

Without `proxy_buffering off`, nginx buffers the entire response before sending — the frontend receives nothing until the stream completes, which looks like a "network error" or empty response.

## Reasoning Model Streaming

Reasoning models (e.g., LongCat-2.5-Preview) split output across two fields in each SSE chunk:
- `delta.reasoning_content` — the model's thinking process
- `delta.content` — the actual user-facing reply

Frontend MUST read both:
```javascript
const d = chunk.choices?.[0]?.delta;
const delta = d?.content || d?.reasoning_content || '';
```

Reading only `content` makes it appear the model is "not responding" — the thinking goes to `reasoning_content` and the actual reply may be a single short string at the end.

## Container IP Stability

When the API container is recreated, its bridge IP may change. Use a Docker network or `--network container:frontend` to avoid hardcoding IPs. Alternatively, use `extra_hosts` in docker-compose or `--add-host` in docker run.

## Build Pattern

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

Build and run:
```bash
docker build -t frontend:1.0.0 .
docker run -d --name frontend -p 8001:80 frontend:1.0.0
```
