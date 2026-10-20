# relay-gateway

OpenAI 兼容的本地 LLM 网关，跑在树莓派上，局域网可访问。
把请求转发到上游（默认 `https://api.longcat.chat/openai/v1`），并记录请求日志。

## 特性
- `/health` 健康检查（Docker HEALTHCHECK 自动调用）
- `GET /v1/models` 模型列表
- `POST /v1/chat/completions` 对话补全（支持 stream 和非 stream）
- `GET /v1/logs` 查看最近的请求日志
- 资源限额：`--memory=192m`、`--cpus=0.5`，适配 2GB 内存的树莓派
  （注：本机内核未启用 cgroup 内存限制，内存限额会被忽略，属正常现象）
- 多阶段构建，最终镜像约 100MB

## 目录结构
```
relay-gateway/
├── Dockerfile
├── docker-compose.yml      # 参考配置（本机未装 compose 插件，用 run.sh 即可）
├── requirements.txt
├── run.sh                  # 一键构建并启动（基于 docker run）
├── README.md
└── app/main.py
```

## 运行

### 方式一：一键脚本（推荐）
```bash
cd /opt/data/docker-projects/relay-gateway
./run.sh
```
> 本机未安装 `docker compose` 插件，所以脚本用 `docker run` 启动，效果相同。

### 方式二：手动
```bash
cd /opt/data/docker-projects/relay-gateway
docker build -t relay-gateway:1.0.0 .
docker run -d --name relay-gateway --restart unless-stopped \
  -p 8000:8000 \
  -e UPSTREAM=https://api.longcat.chat/openai/v1 \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e LOG_DIR=/data/logs \
  -v relay-logs:/data/logs \
  --memory=192m --cpus=0.5 \
  relay-gateway:1.0.0
```

## 访问地址（重要）

网关跑在**宿主机 Docker** 上，绑定 `0.0.0.0:8000`：

| 从哪访问 | 地址 |
|----------|------|
| Pi 宿主机本身 | `http://localhost:8000` 或 `http://127.0.0.1:8000` |
| 局域网其他设备 | `http://<Pi的局域网IP>:8000` |
| hermes 容器内部 | `http://172.17.0.1:8000`（宿主机网桥网关，**不是** localhost） |

## 验证
```bash
curl http://localhost:8000/health
curl http://localhost:8000/v1/models
```

### 调用示例（OpenAI 兼容）
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"LongCat-2.5-Preview","messages":[{"role":"user","content":"你好"}]}'
```

## 环境变量
| 变量 | 默认值 | 说明 |
|------|--------|------|
| `UPSTREAM` | `https://api.longcat.chat/openai/v1` | 上游 API 地址 |
| `OPENAI_API_KEY` | 空 | 上游 API Key（必填） |
| `LOG_DIR` | `/data/logs` | 日志目录 |

## 停止 / 查看
```bash
docker logs -f relay-gateway     # 实时日志
docker stop relay-gateway         # 停止
docker rm relay-gateway           # 删除容器
```
