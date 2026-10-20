#!/bin/bash
# Raspberry Pi AI Workstation Restore Script v2
# 在新卡上运行此脚本即可恢复配置

set -e

REPO_URL="https://github.com/ZOSU-MAX/pi-workstation-backup.git"
GIT_PROXY="http://192.168.0.102:7897"
RESTORE_DIR="/opt/data"
LOG_FILE="/opt/data/logs/restore.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== 开始恢复 ==="

# 1. 克隆备份仓库
if [ ! -d "/tmp/backup-restore" ]; then
    log "克隆备份仓库..."
    git -c http.proxy="$GIT_PROXY" clone "$REPO_URL" /tmp/backup-restore
fi

BACKUP_PATH="/tmp/backup-restore/configs"

if [ ! -d "$BACKUP_PATH" ]; then
    log "错误: 备份文件不存在"
    exit 1
fi

# 2. 恢复系统配置
log "恢复系统配置..."
cp "$BACKUP_PATH/.profile" "$RESTORE_DIR/home/.profile" 2>/dev/null || true
cp -r "$BACKUP_PATH/.codex" "$RESTORE_DIR/home/" 2>/dev/null || true

# 3. 恢复 Hermes 配置
log "恢复 Hermes 配置..."
mkdir -p "$RESTORE_DIR/.hermes"
# 主配置恢复到 /opt/data/config.yaml
if [ -f "$BACKUP_PATH/.hermes/config.yaml" ]; then
    cp "$BACKUP_PATH/.hermes/config.yaml" "$RESTORE_DIR/config.yaml"
fi
# 其他配置
cp -r "$BACKUP_PATH/.hermes/"* "$RESTORE_DIR/.hermes/" 2>/dev/null || true

# 4. 恢复 Docker 项目
log "恢复 Docker 项目..."
cp -r "$BACKUP_PATH/docker-projects" "$RESTORE_DIR/" 2>/dev/null || true

# 5. 恢复用户项目
log "恢复用户项目..."
cp -r "$BACKUP_PATH/projects" "$RESTORE_DIR/" 2>/dev/null || true

# 6. 恢复技能文件
log "恢复技能文件..."
cp -r "$BACKUP_PATH/skills" "$RESTORE_DIR/" 2>/dev/null || true

# 7. 恢复字体
log "恢复字体..."
mkdir -p "$RESTORE_DIR/fonts"
cp "$BACKUP_PATH/fonts/"* "$RESTORE_DIR/fonts/" 2>/dev/null || true

# 8. 恢复脚本
log "恢复脚本..."
cp -r "$BACKUP_PATH/scripts" "$RESTORE_DIR/" 2>/dev/null || true

# 9. 恢复 crontab
log "恢复 crontab..."
if [ -f "$BACKUP_PATH/crontab.txt" ] && [ -s "$BACKUP_PATH/crontab.txt" ]; then
    crontab "$BACKUP_PATH/crontab.txt"
else
    log "crontab 为空，跳过"
fi

# 10. 安装基础软件
log "安装基础软件..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget ffmpeg docker.io npm python3-pip rsync 2>/dev/null

# 11. 启用 Docker
log "启用 Docker..."
sudo systemctl enable docker 2>/dev/null || true
sudo usermod -aG docker $USER 2>/dev/null || true

# 12. 恢复 Hermes 容器
log "恢复 Hermes 容器..."
if command -v docker &> /dev/null; then
    docker pull nousresearch/hermes-agent 2>/dev/null || true
fi

log "=== 恢复完成 ==="
log "请重启系统以应用所有更改"
log "备份仓库保留在: /tmp/backup-restore"
