# agent-space 是面向 AI Agent 的通用工作空间。
# SPACE_BASE_IMAGE 没有默认值：两阶段构建必须显式传入第一阶段实际产出的 Base
# 镜像引用。CI 中优先使用 digest，确保派生镜像使用的内容与已发布 Base 完全一致。
ARG SPACE_BASE_IMAGE
FROM ${SPACE_BASE_IMAGE}

# 模糊版本在构建时解析为精确版本。调用方可以通过 build args 覆盖，
# 但容器启动时不会自动下载或升级这些工具。
ARG NODE_VERSION=lts
ARG PYTHON_VERSION=latest
ARG CHROME_DEVTOOLS_MCP_VERSION=latest
ARG MARKITDOWN_VERSION=latest

# 不绑定 Codex、OpenCode 或其他具体 Agent。镜像只提供通用的
# bootstrap Runtime、文档提取和浏览器调试客户端。
LABEL org.opencontainers.image.title="agent-space" \
      org.opencontainers.image.description="Generic persistent workspace for AI agents"

# Agent 高频使用的系统工具优先从 Debian 仓库安装，保持 ABI、
# 安全更新和依赖解析与基础系统一致。Debian yq 不是常用的 Go 版 yq，
# 因此不在这里安装。
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        file \
        git-lfs \
        poppler-utils \
        ripgrep \
        rsync \
        sqlite3; \
    rm -rf /var/lib/apt/lists/*

# Node.js LTS 和最新稳定 Python 是 Agent 工具的 bootstrap Runtime。
# mise --system 将它们安装到持久化 HOME 之外，因此 HOME volume 不会
# 遮蔽镜像内置版本。/etc/mise/config.toml 是低优先级默认值，用户和
# 项目 mise 配置仍然可以覆盖它们。
RUN set -eux; \
    node_version="$(mise latest "node@${NODE_VERSION}")"; \
    python_version="$(mise latest "python@${PYTHON_VERSION}")"; \
    mise install --system "node@${node_version}" "python@${python_version}"; \
    install -d -m 0755 /etc/mise /etc/spaces /usr/local/share/mise/shims; \
    printf '[tools]\nnode = "%s"\npython = "%s"\n' \
        "${node_version}" "${python_version}" > /etc/mise/config.toml; \
    printf 'NODE_VERSION=%s\nPYTHON_VERSION=%s\n' \
        "${node_version}" "${python_version}" > /etc/spaces/agent-runtime.env; \
    mise reshim --system

# 用户 bin 和用户 mise shims 从基础镜像继承且优先级更高；系统
# shims 只作为非交互进程的内置 Runtime 保底。后续构建层也通过
# 这个 PATH 使用内置 Python 和 Node.js。
ENV PATH="${PATH}:/usr/local/share/mise/shims"

# MarkItDown 使用独立 venv，避免其 Python 依赖污染项目环境。只启用
# PDF、DOCX、PPTX 和 XLSX 文本提取，不引入 OCR、音视频或云服务依赖。
RUN set -eux; \
    python -m venv /opt/spaces/tools/markitdown; \
    if [ "${MARKITDOWN_VERSION}" = latest ]; then \
        markitdown_requirement='markitdown[pdf,docx,pptx,xlsx]'; \
    else \
        markitdown_requirement="markitdown[pdf,docx,pptx,xlsx]==${MARKITDOWN_VERSION}"; \
    fi; \
    /opt/spaces/tools/markitdown/bin/pip install --no-cache-dir "${markitdown_requirement}"; \
    ln -s /opt/spaces/tools/markitdown/bin/markitdown /usr/local/bin/markitdown; \
    resolved_version="$(/opt/spaces/tools/markitdown/bin/python -c \
        'from importlib.metadata import version; print(version("markitdown"))')"; \
    printf 'MARKITDOWN_VERSION=%s\n' "${resolved_version}" \
        >> /etc/spaces/agent-runtime.env

# Chrome DevTools MCP 预装为产品中立的 CLI，但不安装 Chrome，也不写入
# 任何 Agent 专用配置。运行时由 Agent 显式连接外部 Chrome CDP endpoint。
RUN set -eux; \
    install -d -m 0755 /opt/spaces/tools/chrome-devtools-mcp; \
    npm install --prefix /opt/spaces/tools/chrome-devtools-mcp \
        --omit=dev --no-audit --no-fund \
        "chrome-devtools-mcp@${CHROME_DEVTOOLS_MCP_VERSION}"; \
    ln -s /opt/spaces/tools/chrome-devtools-mcp/node_modules/.bin/chrome-devtools-mcp \
        /usr/local/bin/chrome-devtools-mcp; \
    resolved_version="$(node -p \
        "require('/opt/spaces/tools/chrome-devtools-mcp/node_modules/chrome-devtools-mcp/package.json').version")"; \
    printf 'CHROME_DEVTOOLS_MCP_VERSION=%s\n' "${resolved_version}" \
        >> /etc/spaces/agent-runtime.env

# 内置 Skill 的规范源由镜像管理，避免持久化 HOME 挂载后遮蔽镜像内容。
# 启动 hook 将整个 space namespace 链接到用户的通用 Agent Skills 目录。
COPY rootfs/etc/spaces/skills/ /etc/spaces/skills/
COPY --chmod=0755 rootfs/entrypoint.d/system/20-agent-skills.sh \
  /entrypoint.d/system/20-agent-skills.sh
