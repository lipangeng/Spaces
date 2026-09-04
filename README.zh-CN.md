# Spaces

[English](README.md)

Spaces 是一套基于 Docker 的标准化、可持久化、可扩展隔离工作空间基础。它定义稳定的 Linux 运行环境和生命周期约定，同时把 IDE、语言 Runtime 和 Agent 保留为用户自行管理的扩展。

## 项目状态

| 组件 | 状态 | 作用 |
| --- | --- | --- |
| [`space-base`](base/README.zh-CN.md) | 已实现 | 公共 Debian 环境、用户模型、持久化路径、mise 和 entrypoint 框架 |
| [`manual-space`](manual/README.zh-CN.md) | 已初始化 | 面向人工操作的通用工作空间，不绑定具体 IDE |
| [`agent-space`](agent/README.zh-CN.md) | 已初始化 | 面向 AI Agent 的通用工作空间，不绑定具体 Agent 产品 |

两个派生镜像目前有意保持最小化，只建立独立的镜像入口并完整继承 `space-base`；具体工具继续作为用户级扩展安装。

## 设计原则

- 基础镜像保持通用、稳定和易维护。
- 用户状态与工作成果独立于 Container Writable Layer 持久化。
- Provisioning 与 Execution 分离：hooks 负责准备环境，`CMD` 负责启动应用。
- 明确区分 system hooks 与 user hooks 的身份和执行语义。
- 用户软件优先安装到 `/home/space`，Runtime 优先交给 mise 管理。
- 基础镜像不预装或绑定具体 IDE、语言 Runtime 或 AI Agent。
- 把 Container 到 Host 视为主要安全边界。

## 运行模型

镜像定义统一的 `space` 用户和三个持久化边界：

```text
/home/space        用户工具、Runtime、配置和应用数据
/workspace         源代码与其他工作成果
/entrypoint.d/user 持久化的用户初始化脚本
```

容器按以下顺序启动：

```text
tini
  └─ entrypoint 使用配置的启动身份
       ├─ system hooks 使用启动身份
       ├─ user hooks 默认使用 space
       └─ 最终命令默认使用 space
```

如果调用方需要保留显式指定的容器用户，可以关闭用户切换。准确的行为约定见 [基础镜像说明](base/README.zh-CN.md)。

## 快速开始

构建分为两个阶段：先构建 Base，再把它的精确镜像引用传给两个派生镜像：

```bash
SPACE_VERSION=1.0.0
BASE_IMAGE="ghcr.io/lipangeng/space-base:${SPACE_VERSION}"
docker build -t "${BASE_IMAGE}" ./base
docker build \
  --build-arg SPACE_BASE_IMAGE="${BASE_IMAGE}" \
  -t "ghcr.io/lipangeng/manual-space:${SPACE_VERSION}" ./manual
docker build \
  --build-arg SPACE_BASE_IMAGE="${BASE_IMAGE}" \
  -t "ghcr.io/lipangeng/agent-space:${SPACE_VERSION}" ./agent
```

GitHub Actions 中应使用 Docker Metadata Action 生成各镜像的标准名称和标签。第一阶段发布 Base 后，把其 digest 引用作为 `SPACE_BASE_IMAGE` 传给第二阶段；派生 Dockerfile 不猜测或默认使用任何 tag。

## 发布流程

[`publish-images.yml`](.github/workflows/publish-images.yml) 在 `main` 更新时发布 `main` 和 `sha-*` 镜像。推送符合 `v*` 的 SemVer 标签时，发布对应的版本、major/minor 别名、`latest` 和 `sha-*` 镜像。版本标签和 GitHub Release 由人工创建，不依赖自动发布管理工具。

镜像工作流始终先发布 Base，再使用其 digest 并行构建两个派生镜像，也可以针对所选分支或标签手动运行。

启动一个交互式持久化工作空间：

```bash
docker run --rm -it \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  -v space-user-hooks:/entrypoint.d/user \
  ghcr.io/lipangeng/manual-space:1.0.0
```

默认命令是 `bash`。可以通过 Docker、Compose 或 Kubernetes 传入其他命令，启动 IDE、终端、Notebook、Agent 或其他常驻进程。

## 扩展 Space

建议遵循以下职责划分：

```text
语言 Runtime 和兼容 CLI         mise
用户应用和可执行程序             /home/space/.local
项目数据与项目级 mise 配置       /workspace
持久化的系统级初始化             /entrypoint.d/user 中显式使用 sudo
应用启动                         CMD / command / args
```

因此镜像可以安全替换：使用新版镜像 recreate 容器，再重新挂载三个持久化路径，即可恢复用户环境和工作区。

## 安全边界

Spaces 定位为个人隔离工作空间，因此 `space` 用户拥有 passwordless sudo。除非明确需要，不要向容器暴露宿主机权限，尤其应避免 privileged、Host PID、宿主机根目录挂载、不必要的 capabilities，以及在不了解影响时挂载宿主机 Docker socket。

## 仓库结构

```text
.
├── README.md
├── README.zh-CN.md
├── .github/
│   └── workflows/
│       └── publish-images.yml
├── agent/
│   ├── Dockerfile
│   ├── README.md
│   └── README.zh-CN.md
├── base/
│   ├── Dockerfile
│   ├── README.md
│   ├── README.zh-CN.md
│   └── rootfs/
└── manual/
    ├── Dockerfile
    ├── README.md
    └── README.zh-CN.md
```

软件清单、构建参数、hook 语义、环境开关和详细示例见 [`base/README.zh-CN.md`](base/README.zh-CN.md)。
