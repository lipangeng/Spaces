# manual-space 是面向人工交互的通用工作空间。
# SPACE_BASE_IMAGE 没有默认值：两阶段构建必须显式传入第一阶段实际产出的 Base
# 镜像引用。CI 中优先使用 digest，确保派生镜像使用的内容与已发布 Base 完全一致。
ARG SPACE_BASE_IMAGE
FROM ${SPACE_BASE_IMAGE}

# 当前不引入额外软件或启动行为。IDE、Web Terminal、Jupyter 等交互工具应作为
# 用户级扩展安装到持久化 HOME，并由 docker run、Compose 或 Kubernetes 命令启动。
LABEL org.opencontainers.image.title="manual-space" \
      org.opencontainers.image.description="Generic persistent workspace for human-operated sessions"
