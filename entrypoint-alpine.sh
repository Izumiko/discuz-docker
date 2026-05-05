#!/bin/sh
set -e

# 获取环境变量中的 PUID 和 PGID，如果没有设置，默认使用 1000 (常见的主机用户 ID)
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting with UID: $PUID, GID: $PGID"

# --- 2. 源码初始化与自动更新 ---
SOURCE_DIR="/usr/src/discuz"
TARGET_DIR="/app/public"
SRC_VER_FILE="$SOURCE_DIR/source/discuz_version.php"
TARGET_VER_FILE="$TARGET_DIR/source/discuz_version.php"

# 定义一个辅助函数：通过 grep 和 cut 提取单引号中的常量值
# 传入参数 $1 为文件路径，提取 'DISCUZ_RELEASE' 后面的值
get_discuz_release() {
    if [ -f "$1" ]; then
        grep "define('DISCUZ_RELEASE'" "$1" | cut -d"'" -f4
    fi
}

# 检查目标目录是否已存在版本文件
if [ ! -f "$TARGET_VER_FILE" ]; then
    # 场景一：全新安装
    echo "Target version file not found. Initializing DiscuzX..."
    cp -a "$SOURCE_DIR/"* "$TARGET_DIR/"
    echo "DiscuzX source code copied."
else
    # 场景二：已有安装，检查是否需要更新
    SRC_RELEASE=$(get_discuz_release "$SRC_VER_FILE")
    TARGET_RELEASE=$(get_discuz_release "$TARGET_VER_FILE")

    if [ -n "$SRC_RELEASE" ] && [ "$SRC_RELEASE" != "$TARGET_RELEASE" ]; then
        echo "Update detected! Upgrading DiscuzX from release $TARGET_RELEASE to $SRC_RELEASE..."
        # 复制新代码覆盖旧代码
        cp -a "$SOURCE_DIR/"* "$TARGET_DIR/"
        echo "DiscuzX update completed."
    else
        echo "DiscuzX is up to date (Release: $TARGET_RELEASE). No update needed."
    fi
fi

# --- 3. 权限修正 ---
# 确保所有文件都属于新的 www-data (即你的宿主机用户)
echo "Fixing permissions (this might take a while)..."
chown -R ${PUID}:${PGID} /app/public
chown -R ${PUID}:${PGID} /data /config  # Caddy 的数据目录也需要权限

# --- 4. 启动服务 (降权执行) ---
echo "Starting FrankenPHP as ${PUID}:${PGID}..."
exec su-exec "$PUID:$PGID" "$@"