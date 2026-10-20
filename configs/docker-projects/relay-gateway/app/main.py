import os
import time
import json
import logging
from pathlib import Path
from datetime import datetime

import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("relay")

UPSTREAM = os.getenv("UPSTREAM", "https://api.longcat.chat/openai/v1")
API_KEY = os.getenv("OPENAI_API_KEY", "")
LOG_DIR = Path(os.getenv("LOG_DIR", "/data/logs"))
LOG_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="relay-gateway", version="1.0.0")

# ---- simple in-memory request log (ring buffer) ----
MAX_LOGS = 500
REQUESTS: list[dict] = []


@app.get("/")
def index():
    return {
        "service": "relay-gateway",
        "version": "1.0.0",
        "endpoints": {
            "GET /health": "健康检查",
            "GET /v1/models": "模型列表",
            "POST /v1/chat/completions": "对话补全（OpenAI 兼容）",
            "GET /v1/logs": "最近请求日志",
        },
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "version": "1.0.0",
        "upstream": UPSTREAM,
        "key_configured": bool(API_KEY),
        "requests_logged": len(REQUESTS),
    }


@app.get("/v1/models")
async def models():
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.get(
            f"{UPSTREAM}/models",
            headers={"Authorization": f"Bearer {API_KEY}"},
        )
    return JSONResponse(r.json(), status_code=r.status_code)


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.body()
    payload = json.loads(body) if body else {}
    model = payload.get("model", "?")
    stream = bool(payload.get("stream"))

    started = time.time()
    entry = {
        "time": datetime.utcnow().isoformat() + "Z",
        "model": model,
        "stream": stream,
        "bytes_in": len(body),
    }

    async def do_upstream():
        async with httpx.AsyncClient(timeout=600) as c:
            req = c.build_request(
                "POST",
                f"{UPSTREAM}/chat/completions",
                content=body,
                headers={
                    "Authorization": f"Bearer {API_KEY}",
                    "Content-Type": "application/json",
                },
            )
            async with c.send(req, stream=True) as r:
                entry["status"] = r.status_code
                async for chunk in r.aiter_bytes():
                    yield chunk

    # Non-streaming: capture full body for logging
    if not stream:
        try:
            async with httpx.AsyncClient(timeout=600) as c:
                r = await c.post(
                    f"{UPSTREAM}/chat/completions",
                    content=body,
                    headers={
                        "Authorization": f"Bearer {API_KEY}",
                        "Content-Type": "application/json",
                    },
                )
            entry["status"] = r.status_code
            entry["bytes_out"] = len(r.content)
            entry["ms"] = int((time.time() - started) * 1000)
            REQUESTS.append(entry)
            if len(REQUESTS) > MAX_LOGS:
                REQUESTS.pop(0)
            log.info("%s model=%s status=%s %dms in=%dB out=%dB",
                     "chat", model, r.status_code, entry["ms"], entry["bytes_in"], entry["bytes_out"])
            return JSONResponse(r.json(), status_code=r.status_code)
        except httpx.HTTPError as e:
            log.error("upstream error: %s", e)
            raise HTTPException(status_code=502, detail=f"upstream error: {e}")

    return StreamingResponse(do_upstream(), media_type="application/json")


@app.post("/v1/chat/completion")
async def chat_completion_alias(request: Request):
    return await chat_completions(request)


@app.get("/v1/logs")
def get_logs(limit: int = 50):
    return {"count": len(REQUESTS), "logs": REQUESTS[-limit:][::-1]}
