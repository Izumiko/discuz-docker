# ==========================================
# Stage 1: 源码下载阶段 (Downloader)
# ==========================================
FROM alpine/git:latest AS downloader

WORKDIR /src

# 定义构建参数，默认为 X5.0_20260320 (这是 DiscuzX 目前的稳定大版本)
# 你可以在构建时通过 --build-arg DISCUZ_URL=<下载地址> 来指定其他版本的下载地址
ARG DISCUZ_URL=https://download.discuz.vip/redirect/?X5.0

# 下载指定版本的 DiscuzX 源码
RUN apk add curl unzip && \
    curl --retry 8 --retry-connrefused -Lo dz.zip ${DISCUZ_URL} && \
    unzip dz.zip -d .

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# ==========================================
# Stage 2: 最终运行阶段 (Final Runtime)
# ==========================================
FROM debian:13-slim

ARG TARGETARCH

# 1. 安装运行时必需的系统依赖 # 2. 安装 PHP 扩展 # 3. 提权设置
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gosu \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/* \
    && if [ "$TARGETARCH" = "arm64" ]; then \
        FILENAME="frankenphp-linux-aarch64-gnu"; \
    else \
        FILENAME="frankenphp-linux-x86_64-gnu"; \
    fi && \
    curl -L "https://github.com/dunglas/frankenphp/releases/latest/download/${FILENAME}" -o /usr/local/bin/frankenphp \
    && chmod +x /usr/local/bin/frankenphp \
    && setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp

ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

# 4. 从下载阶段拷贝源码
WORKDIR /usr/src/discuz
COPY --from=downloader /src/upload /usr/src/discuz

# 5. 准备脚本和配置
COPY --from=downloader /usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh

COPY Caddyfile /etc/caddy/Caddyfile

# 6. 入口设置
WORKDIR /app/public
ENTRYPOINT ["entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
