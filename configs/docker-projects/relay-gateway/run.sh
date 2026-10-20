#!/usr/bin/env bash
# 一键构建并启动 relay-gateway
# 用法：在 Pi 宿主机上运行  ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "错误：请先设置 OPENAI_API_KEY"
  echo "  export OPENAI_API_KEY=\"你的key\""
  exit 1
fi

echo "==> 构建镜像 relay-gateway:1.0.0"
docker build -t relay-gateway:1.0.0 .

echo "==> 清理旧容器（如有）"
docker rm -f relay-gateway >/dev/null 2>&1 || true

echo "==> 启动容器"
docker run -d --name relay-gateway --restart unless-stopped \
  -p 8000:8000 \
  -e UPSTREAM=https://api.longcat.chat/openai/v1 \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e LOG_DIR=/data/logs \
  -v relay-logs:/data/logs \
  --memory=192m --cpus=0.5 \
  relay-gateway:1.0.0

echo "==> 等待健康检查..."
BASE="http://127.0.0.1:8000"
for i in $(seq 1 30); do
  # 若本机 localhost 不通（例如在容器内运行），回退到宿主机网关 IP
  if ! curl -sf "$BASE/health" >/dev/null 2>&1; then
    GW=$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)
    [[ -n "$GW" ]] && BASE="http://$GW:8000"
  fi
  if curl -sf "$BASE/health" >/dev/null 2>&1; then
    echo "==> 已就绪：$BASE"
    curl -s "$BASE/health"; echo
    echo
    echo "调用示例："
    echo "  curl $BASE/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"LongCat-2.5-Preview\",\"messages\":[{\"role\":\"user\",\"content\":\"你好\"}]}'"
    exit 0
  fi
  sleep 2
done

echo "==> 30 秒内未通过健康检查，最后日志："
docker logs --tail=30 relay-gateway
exit 1
