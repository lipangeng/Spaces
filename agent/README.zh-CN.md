# agent-space

[English](README.md)

`agent-space` 是面向 AI Agent 的通用持久化 Linux 工作空间。它完整继承 [`space-base`](../base/README.zh-CN.md) 的运行契约，但不把镜像绑定到 Codex、OpenCode 或其他 Agent 产品。

## 内置能力

`agent-space` 是通用 Agent bootstrap 环境，内置：

- 构建时固定的 Node.js LTS 和最新稳定 Python。
- `ripgrep`、`file`、SQLite、Git LFS、rsync 和 Poppler PDF 工具。
- 支持 PDF、DOCX、PPTX 和 XLSX 的 MarkItDown。
- 用于连接外部 Chrome 的 `chrome-devtools-mcp`。

精确的 Runtime 和工具版本记录在 `/etc/spaces/agent-runtime.env`。镜像不在启动时自动升级，也不内置 Chrome、Pandoc、LibreOffice、OCR、FFmpeg 或完整编译工具链。高级能力可在运行时按需补充。

通过继承的能力完成定制：

- `/home/space` 保存 Agent CLI、mise Runtime、配置和缓存。
- `/workspace` 保存代码仓库和 Agent 工作成果。
- `/entrypoint.d/user` 保存持久化的用户初始化逻辑。
- 通过 `CMD`、Compose `command` 或 Kubernetes `command` 与 `args` 选择 Agent 进程。

## 内置 Agent Skills

镜像把内置 Skills 保存在 `/etc/spaces/skills`。启动时，system hook 会在目标不存在时创建以下 namespace 软链接：

```text
/home/space/.agents/skills/space -> /etc/spaces/skills
```

`space` 目录是 namespace，下面可以继续使用多级目录组织 Skills：

- [`space-environment`](rootfs/etc/spaces/skills/space-environment/SKILL.md)：容器、持久化、mise 和软件目录约定。
- [`chrome-devtools`](rootfs/etc/spaces/skills/chrome-devtools/SKILL.md)：连接外部 Chrome 的 CDP/MCP 指引。
- [`document-conversion`](rootfs/etc/spaces/skills/document-conversion/SKILL.md)：本地文档文本提取指引。

已有文件、目录或软链接不会被替换；发生冲突时只记录信息并保留原内容。设置 `SPACE_LINK_AGENT_SKILLS=false` 可以关闭自动链接；链接失败会记录警告，但不会阻断容器启动。

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

以下构建参数控制 bootstrap 工具版本。默认值会在构建时解析为精确
版本并记录到镜像中：

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `NODE_VERSION` | `lts` | 当前 Node.js LTS 版本线或显式版本 |
| `PYTHON_VERSION` | `latest` | 最新稳定 Python 或显式版本 |
| `MARKITDOWN_VERSION` | `latest` | MarkItDown 软件包版本 |
| `CHROME_DEVTOOLS_MCP_VERSION` | `latest` | Chrome DevTools MCP 软件包版本 |

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

`agent-space` 不规定凭据注入方式。应使用部署平台提供的 Secret 机制、限制凭据权限范围，并避免把凭据写入镜像、仓库或持久化 user hooks。

## 扩展边界

镜像级依赖限于高频、通用或 bootstrap 能力。可替换的 Agent CLI 和项目 Runtime 优先通过 mise 或 `/home/space/.local` 安装；这些用户路径的 PATH 优先级高于镜像内置 Runtime。entrypoint 开关、hook 语义、持久化和权限处理见[基础镜像说明](../base/README.zh-CN.md)。
