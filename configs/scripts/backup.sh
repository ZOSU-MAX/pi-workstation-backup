#!/bin/bash
# Raspberry Pi AI Workstation Backup Script v3
# 只备份配置文件，排除缓存和大文件

set -e

BACKUP_DIR="/opt/data/backups/workstation"
REPO_URL="https://github.com/ZOSU-MAX/pi-workstation-backup.git"
GIT_PROXY=""
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="/opt/data/logs/backup.log"

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== 开始备份 ==="

# 清理旧的备份目录
rm -rf "$BACKUP_DIR"/*

# 创建备份目录
BACKUP_PATH="$BACKUP_DIR/configs"
mkdir -p "$BACKUP_PATH"

# 1. 备份系统配置
log "备份系统配置..."
cp /opt/data/home/.profile "$BACKUP_PATH/" 2>/dev/null || true
cp -r /opt/data/home/.codex "$BACKUP_PATH/" 2>/dev/null || true

# 2. 备份 Hermes 配置
log "备份 Hermes 配置..."
mkdir -p "$BACKUP_PATH/.hermes"
# 主配置在 /opt/data/config.yaml
cp /opt/data/config.yaml "$BACKUP_PATH/.hermes/" 2>/dev/null || true
# 其他配置目录
for item in .env memories skills; do
    cp -r "/opt/data/.hermes/$item" "$BACKUP_PATH/.hermes/" 2>/dev/null || true
done

# 3. 备份 Docker 项目
log "备份 Docker 项目..."
cp -r /opt/data/docker-projects "$BACKUP_PATH/" 2>/dev/null || true

# 4. 备份用户项目（排除 node_modules 和大文件）
log "备份用户项目..."
mkdir -p "$BACKUP_PATH/projects"
for dir in /opt/data/projects/*/; do
    name=$(basename "$dir")
    mkdir -p "$BACKUP_PATH/projects/$name"
    # 只复制代码文件，排除 node_modules、.git、缓存
    rsync -a --exclude='node_modules' --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.venv' --exclude='venv' --exclude='dist' --exclude='build' --exclude='.cache' "$dir" "$BACKUP_PATH/projects/$name/" 2>/dev/null || true
done

# 5. 备份技能文件
log "备份技能文件..."
cp -r /opt/data/skills "$BACKUP_PATH/" 2>/dev/null || true

# 6. 备份字体
log "备份字体..."
mkdir -p "$BACKUP_PATH/fonts"
cp /opt/data/fonts/*.ttf /opt/data/fonts/*.ttc "$BACKUP_PATH/fonts/" 2>/dev/null || true

# 7. 备份脚本
log "备份脚本..."
cp -r /opt/data/scripts "$BACKUP_PATH/" 2>/dev/null || true

# 8. 备份 cron
log "备份 crontab..."
{
    echo "# 系统 crontab"
    crontab -l 2>/dev/null || echo "# 无系统 crontab"
    echo ""
    echo "# Hermes cron 任务通过 cronjob_manage 管理，不在系统 crontab 中"
    echo "# 恢复后需要手动或用 cronjob_manage 重新创建 Hermes 定时任务"
} > "$BACKUP_PATH/crontab.txt"

# 9. 备份网络配置
log "备份网络配置..."
{
    echo "## IP 地址"
    ip addr 2>/dev/null || hostname -I 2>/dev/null || echo "无法获取"
    echo ""
    echo "## 路由"
    ip route 2>/dev/null || echo "无法获取"
} > "$BACKUP_PATH/network_config.txt" 2>/dev/null || echo "# 无法获取网络配置" > "$BACKUP_PATH/network_config.txt"

# 10. 备份软件清单
log "备份软件清单..."
{
    echo "# 已安装软件清单"
    echo "# 生成时间: $(date)"
    echo ""
    echo "## Docker 镜像"
    docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" 2>/dev/null
    echo ""
    echo "## 全局 npm 包"
    npm list -g --depth=0 2>/dev/null || echo "npm not available"
    echo ""
    echo "## Python 包"
    pip3 list 2>/dev/null || echo "pip3 not available"
    echo ""
    echo "## Docker 容器"
    docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}" 2>/dev/null
} > "$BACKUP_PATH/installed_software.md"

# 11. 生成备份摘要
cat > "$BACKUP_PATH/BACKUP_INFO.md" << EOF
# 备份信息

- **日期**: $(date '+%Y-%m-%d %H:%M:%S')
- **主机名**: $(hostname)
- **系统**: $(uname -a)
- **运行时间**: $(uptime)
- **磁盘使用**: $(df -h / | tail -1)
- **内存使用**: $(free -h | grep Mem)
- **Docker 容器数**: $(docker ps -q 2>/dev/null | wc -l)
- **备份大小**: $(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)

## 备份内容
- 系统配置 (.profile, .codex)
- Hermes 配置 (config.yaml, skills, memories)
- Docker 项目 (docker-projects/)
- 用户项目 (projects/, 排除 node_modules)
- 技能文件 (skills/)
- 字体文件 (fonts/)
- 脚本文件 (scripts/)
- Crontab 配置
- 网络配置
- 已安装软件清单
EOF

# 12. 推送到 GitHub
log "推送到 GitHub..."
cd "$BACKUP_DIR"

# 每次重新初始化 git，避免历史冲突
rm -rf .git
git init
git remote add origin "$REPO_URL"
git config user.email "pi@workstation"
git config user.name "Pi Workstation"

# 添加所有文件并提交
git add -A
git commit -m "Backup: $DATE"

# 推送
log "推送中..."
if [ -n "$GIT_PROXY" ]; then
  git -c http.proxy="$GIT_PROXY" push -f origin master >> "$LOG_FILE" 2>&1
else
  git push -f origin master >> "$LOG_FILE" 2>&1
fi

log "=== 备份完成 ==="
