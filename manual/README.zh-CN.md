# manual-space

[English](README.md)

`manual-space` 是面向人工交互的通用持久化 Linux 工作空间。它完整继承 [`space-base`](../base/README.zh-CN.md) 的运行契约，但不预装 IDE、语言 Runtime、Notebook 或终端服务。

## 当前范围

初始镜像有意不在 `space-base` 之上增加软件包或启动行为。它为交互式工作空间提供稳定的镜像名称和扩展点，同时把具体应用选择保留在镜像之外。

通过继承的能力完成定制：

- `/home/space` 保存用户应用、Shell 配置、mise Runtime 和应用数据。
- `/workspace` 保存代码仓库和其他工作成果。
- `/entrypoint.d/user` 保存持久化的用户初始化逻辑。
- 通过 `CMD`、Compose `command` 或 Kubernetes `command` 与 `args` 选择交互服务。

## 构建

`SPACE_BASE_IMAGE` 是必填构建参数。先构建 Base，再将第一阶段实际产生的镜像引用传给 `manual-space`：

```bash
SPACE_VERSION=1.0.0
BASE_IMAGE="ghcr.io/lipangeng/space-base:${SPACE_VERSION}"
docker build -t "${BASE_IMAGE}" ./base
docker build \
  --build-arg SPACE_BASE_IMAGE="${BASE_IMAGE}" \
  -t "ghcr.io/lipangeng/manual-space:${SPACE_VERSION}" \
  ./manual
```

在 GitHub Actions 中，第一阶段负责通过 Docker Metadata Action 生成 Base 镜像名称和标签并完成发布；第二阶段应使用第一阶段输出的完整镜像引用。优先传入不可变的 digest 引用，例如：

```bash
docker build \
  --build-arg SPACE_BASE_IMAGE="ghcr.io/lipangeng/space-base@sha256:<digest>" \
  -t "<docker-metadata-action 生成的 manual-space tag>" \
  ./manual
```

## 运行

使用持久化存储启动继承的 Bash 命令：

```bash
docker run --rm -it \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  -v space-user-hooks:/entrypoint.d/user \
  ghcr.io/lipangeng/manual-space:1.0.0
```

用户安装交互应用后，可以显式把它设置为容器命令。Provisioning 负责安装和配置，命令负责启动应用。

```bash
docker run --rm \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  ghcr.io/lipangeng/manual-space:1.0.0 \
  code serve-web --host 0.0.0.0 --port 8000
```

该示例假设 `code` 已经安装在持久化用户环境中；`manual-space` 本身不安装 VS Code。

## 扩展边界

只有所有人工工作空间都必需的镜像级依赖才应加入该镜像。用户自行选择的软件优先通过 mise 或 `/home/space/.local` 安装；需要持久化的系统级初始化使用 user hooks。entrypoint 开关、hook 语义和权限处理见[基础镜像说明](../base/README.zh-CN.md)。
