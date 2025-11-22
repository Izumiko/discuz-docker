#!/bin/sh
set -e

# 获取环境变量中的 PUID 和 PGID，如果没有设置，默认使用 1000 (常见的主机用户 ID)
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting with UID: $PUID, GID: $PGID"

# --- 1. 修改 www-data 用户的 ID ---
# 将容器内的 www-data 用户修改为指定的 PUID/PGID
# 这样容器内 www-data 写的文件，在宿主机看来就是你的用户写的
groupmod -o -g "$PGID" www-data
usermod -o -u "$PUID" www-data

# --- 2. 源码初始化 ---
SOURCE_DIR="/usr/src/discuz"
TARGET_DIR="/app/public"

if [ ! -f "$TARGET_DIR/index.php" ]; then
    echo "Initializing DiscuzX..."
    cp -a $SOURCE_DIR/* $TARGET_DIR/
    echo "DiscuzX source code copied."
fi

# --- 3. 权限修正 ---
# 确保所有文件都属于新的 www-data (即你的宿主机用户)
echo "Fixing permissions (this might take a while)..."
chown -R www-data:www-data /app/public
chown -R www-data:www-data /data /config  # Caddy 的数据目录也需要权限

# --- 4. 启动服务 (降权执行) ---
# 使用 gosu 切换到 www-data 用户来执行传入的命令 (CMD)
echo "Starting FrankenPHP as user www-data..."
exec gosu www-data "$@"