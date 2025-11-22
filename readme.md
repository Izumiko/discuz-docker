# Discuz\! X3.5 Docker (FrankenPHP Edition)

这是一个基于 **Docker** 和 **FrankenPHP (Caddy)** 的 Discuz\! X3.5 现代化容器部署方案。

本项目旨在解决传统 LAMP/LNMP 环境下配置繁琐、权限管理混乱的问题，利用 FrankenPHP 的高性能和 Caddy 的自动配置能力，提供开箱即用的 Discuz\! 运行环境。

## ✨ 主要特性

  * **高性能架构**: 使用 [FrankenPHP](https://frankenphp.dev/)，将 PHP 运行时与 Caddy Web Server 融为一体，支持 Worker 模式（需 Discuz 适配，目前作为标准 PHP 运行）。
  * **完美的权限管理**: 通过 `entrypoint.sh` 脚本动态调整容器内 UID/GID，确保宿主机编辑代码时没有权限问题。
  * **内置伪静态规则**: `Caddyfile` 中已预置 Discuz\! X3.5 的所有标准伪静态规则（门户、论坛、群组、空间等）。
  * **安全加固**: 默认禁止访问敏感目录（如 `/config`, `/uc_client`）以及禁止在上传目录执行 PHP 脚本。
  * **环境完备**: 基于 `php:8.2`，预装 `gd`, `mysqli`, `pdo_mysql`, `zip`, `opcache`, `exif`, `intl` 等 Discuz 运行所需扩展。

## 📂 目录结构

```text
.
├── Caddyfile            # Caddy 配置文件 (包含伪静态和安全规则)
├── Dockerfile           # 构建镜像的定义文件
├── docker-compose.yaml  # 容器编排文件
├── entrypoint.sh        # 启动脚本 (处理权限和初始化)
└── www/                 # (自动生成) 网站根目录，映射到容器内的 /app/public
```

## 🚀 快速开始

### 1\. 环境准备

确保你的服务器已安装 Docker 和 Docker Compose。

### 2\. 配置环境

修改 `docker-compose.yaml` 中的环境变量以匹配你的当前用户：

```yaml
    environment:
      - PUID=1000  # 输入命令 `id -u` 查看并替换
      - PGID=1000  # 输入命令 `id -g` 查看并替换
      - TZ=Asia/Shanghai
```

*设置 `PUID` 和 `PGID` 可以让容器生成的文件直接属于你的宿主机用户，避免出现 `root` 权限锁死文件的情况。*

### 3\. 启动服务

在项目根目录下执行：

```bash
docker-compose up -d --build
```

  * **首次启动时**：容器会自动从 Gitee 下载 Discuz\! X3.5 源码并解压到 `./www` 目录。
  * **数据库**：会自动启动一个 MariaDB 10 容器。

### 4\. 安装 Discuz\!

打开浏览器访问 `http://localhost` (或你的服务器 IP)。
按照提示进行安装，数据库信息如下（参考 `docker-compose.yaml`）：

  * **数据库服务器**: `discuz-db`
  * **数据库名**: `discuz`
  * **数据库用户名**: `discuz`
  * **数据库密码**: `discuzpassword` (或你在 compose 文件中修改的密码)

## ⚙️ 配置说明

### 自定义伪静态 (Caddyfile)

本项目将 `Caddyfile` 挂载到了容器外部。如果你安装了第三方插件需要特殊的重写规则，请直接修改根目录下的 `Caddyfile` 并重启容器：

```bash
docker-compose restart discuz-web
```

### 更换 Discuz 版本

默认下载版本为 `v3.5-20250901`。如果你需要更改版本，请修改 `docker-compose.yaml` 中的 `build.args`：

```yaml
    build:
      context: .
      args:
        - DISCUZ_URL=https://你的自定义下载链接.zip
```

若非全新安装，更改上述参数只会构建新的镜像，不会更新已有的网站，需要用户根据Discuz的升级说明自行处理。

## 🛡️ 安全机制

为了防止 Webshell 和数据泄露，Caddyfile 内置了以下策略：

1.  **敏感目录阻断**：`/config/*`, `/uc_client/data/*`, `/source/*` 等目录禁止直接通过 HTTP 访问。
2.  **脚本执行限制**：在 `/data`, `/static`, `/template`, `/attachment` 目录下禁止执行 `.php` 文件。

## 🛠️ 常见问题

**Q: 安装时提示 config 目录不可写？**
A: 请检查宿主机 `./www` 目录的权限。由于配置了 `PUID/PGID`，通常情况下容器会自动修复权限。如果仍有问题，尝试在宿主机执行 `chown -R 1000:1000 ./www` (替换为你的实际 ID)。

**Q: 为什么没有使用 Nginx？**
A: 本项目使用 FrankenPHP (Caddy)，它是一个现代化的应用服务器。它不仅充当 Web 服务器（替代 Nginx），还直接运行 PHP（替代 PHP-FPM），配置更简单且支持 HTTP/3。

**Q: 如何开启 HTTPS？**
A: Caddy 默认支持自动 HTTPS。如果你在公网服务器上有域名，将 `docker-compose.yaml` 中的 `SERVER_NAME` 改为你的域名（例如 `bbs.example.com`），并将 `80` 和 `443` 端口正确暴露，Caddy 会自动申请并续期 Let's Encrypt 证书。
