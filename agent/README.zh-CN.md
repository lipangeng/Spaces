# agent-space

[English](README.md)

`agent-space` 是面向 AI Agent 的通用持久化 Linux 工作空间。它完整继承 [`space-base`](../base/README.zh-CN.md) 的运行契约，但不把镜像绑定到 Codex、OpenCode 或其他 Agent 产品。

## 当前范围

初始镜像有意不在 `space-base` 之上增加软件包或启动行为。它建立稳定的镜像名称和扩展点，同时允许每个部署独立选择 Agent、Runtime、凭据和启动命令。

通过继承的能力完成定制：

- `/home/space` 保存 Agent CLI、mise Runtime、配置和缓存。
- `/workspace` 保存代码仓库和 Agent 工作成果。
- `/entrypoint.d/user` 保存持久化的用户初始化逻辑。
- 通过 `CMD`、Compose `command` 或 Kubernetes `command` 与 `args` 选择 Agent 进程。

## 构建

`SPACE_BASE_IMAGE` 是必填构建参数。先构建 Base，再将第一阶段实际产生的镜像引用传给 `agent-space`：

```bash
SPACE_VERSION=1.0.0
BASE_IMAGE="ghcr.io/lipangeng/space-base:${SPACE_VERSION}"
docker build -t "${BASE_IMAGE}" ./base
docker build \
  --build-arg SPACE_BASE_IMAGE="${BASE_IMAGE}" \
  -t "ghcr.io/lipangeng/agent-space:${SPACE_VERSION}" \
  ./agent
```

在 GitHub Actions 中，第一阶段负责通过 Docker Metadata Action 生成 Base 镜像名称和标签并完成发布；第二阶段应使用第一阶段输出的完整镜像引用。优先传入不可变的 digest 引用，例如：

```bash
docker build \
  --build-arg SPACE_BASE_IMAGE="ghcr.io/lipangeng/space-base@sha256:<digest>" \
  -t "<docker-metadata-action 生成的 agent-space tag>" \
  ./agent
```

## 运行

使用持久化存储启动继承的 Bash 命令：

```bash
docker run --rm -it \
  -v agent-home:/home/space \
  -v "$(pwd)":/workspace \
  -v agent-user-hooks:/entrypoint.d/user \
  ghcr.io/lipangeng/agent-space:1.0.0
```

在持久化用户环境中安装 Agent CLI 后，将该 CLI 显式作为容器命令传入：

```bash
docker run --rm -it \
  -v agent-home:/home/space \
  -v "$(pwd)":/workspace \
  ghcr.io/lipangeng/agent-space:1.0.0 \
  your-agent-command
```

`agent-space` 不规定凭据注入方式。应使用部署平台提供的 Secret 机制、限制凭据权限范围，并避免把凭据写入镜像或 user hooks。

## 扩展边界

只有所有受支持 Agent 都必需的镜像级依赖才应加入该镜像。可替换的 Agent CLI 和 Runtime 优先通过 mise 或 `/home/space/.local` 安装。entrypoint 开关、hook 语义、持久化和权限处理见[基础镜像说明](../base/README.zh-CN.md)。
