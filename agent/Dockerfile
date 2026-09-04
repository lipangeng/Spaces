# agent-space 是面向 AI Agent 的通用工作空间。
# SPACE_BASE_IMAGE 没有默认值：两阶段构建必须显式传入第一阶段实际产出的 Base
# 镜像引用。CI 中优先使用 digest，确保派生镜像使用的内容与已发布 Base 完全一致。
ARG SPACE_BASE_IMAGE
FROM ${SPACE_BASE_IMAGE}

# 当前不绑定 Codex、OpenCode 或其他具体 Agent。Agent CLI 及其 Runtime 应作为
# 用户级扩展安装到持久化 HOME，实际 Agent 由容器命令选择和启动。
LABEL org.opencontainers.image.title="agent-space" \
      org.opencontainers.image.description="Generic persistent workspace for AI agents"
