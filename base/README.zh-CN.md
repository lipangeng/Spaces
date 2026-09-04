# Space Base

[English](README.md) · [项目说明](../README.zh-CN.md)

`space-base` 是所有 Space 共用的运行基础。它提供 Debian、稳定的用户和目录约定、常用运维工具、mise、Docker 客户端、Shell 集成以及两阶段 hook 框架，但不绑定具体 IDE、语言 Runtime 或 AI Agent。

## 基础系统

- 基础镜像：`debian:trixie-slim`
- 默认工作目录：`/workspace`
- 默认命令：`bash`
- 默认启动身份：Dockerfile 不设置 `USER`，调用方未覆盖时 Docker 使用 root
- Init 进程：`tini`
- Entrypoint：`/entrypoint.sh`

构建时可以调整用户 ID，以匹配共享存储权限：

| 参数 | 默认值 | 作用 |
| --- | ---: | --- |
| `SPACE_UID` | `1000` | `space` 用户的 UID |
| `SPACE_GID` | `1000` | `space` 用户组的 GID |

```bash
docker build \
  --build-arg SPACE_UID=1001 \
  --build-arg SPACE_GID=1001 \
  -t space-base:local \
  ./base
```

## 内置工具

```text
bash, zsh, fish, bash-completion
curl, wget, git, openssh-client, ca-certificates, openssl, gnupg
jq, less, vim, tree, tmux
tar, gzip, unzip, zip, xz-utils, 7zip
procps, psmisc, htop, sysstat, strace, lsof
iproute2, iputils-ping, dnsutils, netcat-openbsd, nmap, tcpdump
sudo, gosu, tini
fontconfig, fonts-noto-cjk
mise
docker-ce-cli, docker-buildx-plugin, docker-compose-plugin
```

镜像不包含 Docker daemon。Docker 客户端可以通过 `DOCKER_HOST` 等方式连接显式配置的外部 daemon 或 DinD 服务。

镜像有意排除完整开发工具链和上层应用。语言 Runtime 应优先使用 mise 安装，用户应用应优先放到 `/home/space`。

## 用户和目录

```text
用户：     space
用户组：   space
HOME：     /home/space
工作目录： /workspace
```

`space` 用户拥有 passwordless sudo：

```text
space ALL=(ALL) NOPASSWD:ALL
```

镜像级 PATH 最前面包含：

```text
/home/space/.local/bin
/home/space/.local/share/mise/shims
```

因此交互式 Shell、非交互命令、IDE 进程和 Agent 都能找到用户安装的软件，不必依赖 Shell 启动文件。

## 持久化

Dockerfile 声明三个 Volume：

| 路径 | 保存内容 |
| --- | --- |
| `/home/space` | mise 安装、用户应用、Shell 配置、应用数据、历史记录和缓存 |
| `/workspace` | 代码仓库、文档、项目配置、测试数据和其他工作成果 |
| `/entrypoint.d/user` | 持久化的用户初始化脚本 |

临时安装到容器 RootFS 的软件会在 recreate 后丢失。长期系统需求应记录在 user hooks 中；用户级软件应优先使用 mise 或 `/home/space/.local`。

## 启动流程

```text
tini
  └─ /entrypoint.sh 使用配置的启动身份
       ├─ /entrypoint.d/system/*.sh
       ├─ /entrypoint.d/user/*.sh
       └─ 最终命令
```

Dockerfile 默认使用 root，但 `docker run --user` 或编排平台的安全配置可以覆盖 entrypoint 身份。System hooks 始终使用实际启动身份；脚本不会推断或改写自身身份。

### System Hooks

System hooks 是镜像管理的 `/entrypoint.d/system` 文件。

- 只处理目录第一层的 `*.sh` 文件。
- 文件名按版本排序，例如 `10-directories.sh` 先于 `20-config.sh`。
- 可执行文件作为独立进程运行，并使用自身 shebang。
- 不可执行文件 source 到 entrypoint，可以有意修改其环境或 Shell 状态。
- Hook 使用 entrypoint 的实际启动身份。
- 任一 hook 失败都会终止容器启动。

内置的 `10-space-directories.sh` 会创建缺失的持久化目录，并且只在目标文件不存在时安装默认 Shell 配置，不覆盖用户已有配置。

### User Hooks

User hooks 是持久化在 `/entrypoint.d/user` 中、由用户管理的文件。

- 只处理目录第一层的 `*.sh` 文件。
- 使用与 system hooks 相同的版本排序。
- 可执行文件作为独立进程运行，并使用自身 shebang。
- 不可执行文件作为独立 Bash 进程运行。
- User hooks 永远不会 source 到 entrypoint。
- 默认以 `space` 运行；关闭用户切换后使用实际启动身份。
- 任一 hook 失败都会终止容器启动。

每个 user hook 都是独立进程，因此其中的 `export`、`cd`、alias 或 Shell 函数不会影响后续 hook 或最终命令。长期环境变更应写入 Shell 配置、mise 或 `/home/space` 下的其他文件。

User hook 示例：

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v ffmpeg >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ffmpeg
fi
```

设置 executable bit 后使用脚本自身 shebang：

```bash
chmod +x entrypoint.d/user/20-ffmpeg.sh
```

## Entrypoint 配置

所有布尔值均支持 `1/0`、`true/false`、`yes/no` 和 `on/off`，英文值不区分大小写。非法值会终止启动。

| 变量 | 默认值 | 行为 |
| --- | --- | --- |
| `SPACE_USER_SWITCH` | `true` | user hooks 和最终命令以 `space` 运行；设为 false 时保留实际启动身份与环境 |
| `SPACE_FIX_PERMISSIONS` | `true` | 将三个持久化根目录和 HOME 目录骨架修复为 `space:space`；设为 false 时不修改已有目录 |
| `SKIP_SYSTEM_ENTRYPOINT` | `false` | 跳过全部 system hooks |
| `SKIP_USER_ENTRYPOINT` | `false` | 跳过全部 user hooks |
| `HIDE_ENTRYPOINT_ARGS` | `false` | 最终命令日志只显示可执行文件，不打印完整参数 |

当 `SPACE_USER_SWITCH=true` 时，user hooks 和最终命令获得：

```text
HOME=/home/space
USER=space
LOGNAME=space
```

如果实际启动身份不能切换用户，`gosu` 会失败并终止启动，不会静默回退到其他身份。

当 `SPACE_USER_SWITCH=false` 时，entrypoint 不调用 `gosu`，并保留调用方的 UID、GID、`HOME`、`USER` 和 `LOGNAME`。调用方需要自行保证目录权限，并判断 system hooks 是否可以完成。

`SPACE_FIX_PERMISSIONS` 检查 `/home/space`、`/workspace` 和 `/entrypoint.d/user`，用于处理 Docker volume 或 bind mount 覆盖镜像目录后产生的挂载点属主差异。同时检查镜像管理的 HOME 目录骨架 `/home/space/.config`、`/home/space/.local` 和 `/home/space/.local/share`，因为这些中间路径否则可能由 root 隐式创建。修复只调整明确列出的目录，不改变 mode，也不递归修改已有内容。其他挂载文件的权限应通过匹配 `SPACE_UID`、`SPACE_GID` 或宿主机权限来保证。

## Shell 与 mise 集成

镜像维护的 Shell 片段位于 `/etc/spaces/shell`，默认用户模板位于 `/etc/spaces/templates`。

首次初始化会创建以下缺失文件，但不会覆盖持久化 HOME 中已有的用户配置：

```text
/home/space/.bashrc
/home/space/.profile
/home/space/.zshrc
/home/space/.config/fish/config.fish
```

交互式 Bash、Zsh 和 Fish 会加载对应的 mise activation。mise shims 同时保留在镜像级 PATH 中，因此非交互进程也能使用 mise 管理的工具。

```bash
mise use -g node@24
mise use -g python@3.14
mise use -g go@latest
```

项目级版本继续由 `/workspace` 中项目自己的 `mise.toml` 定义。

## 运行镜像

交互式工作空间：

```bash
docker run --rm -it \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  -v space-user-hooks:/entrypoint.d/user \
  space-base:local
```

运行明确命令：

```bash
docker run --rm \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  space-base:local \
  bash -lc 'mise current'
```

保留调用方指定的启动身份，不切换到 `space`：

```bash
docker run --rm -it \
  --user 1001:1001 \
  -e SPACE_USER_SWITCH=false \
  -e SKIP_SYSTEM_ENTRYPOINT=true \
  -v "$(pwd)":/workspace \
  space-base:local
```

最后一种模式由调用方管理：指定 UID 必须能够访问所需文件和挂载目录。

## 安全说明

- Passwordless sudo 是个人工作空间模型中的有意设计。
- 除非工作负载明确需要，否则不要使用 `--privileged`。
- 避免 Host PID、广泛的宿主机目录挂载和不必要的 capabilities。
- Docker daemon 访问权限通常意味着对 daemon 所在主机拥有很高控制力；不要因为镜像安装了 Docker CLI 就随意挂载宿主机 Docker socket。
- User hook 目录是持久化的可执行输入，只应挂载可信内容。
