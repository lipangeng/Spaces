# manual-space 是面向人工交互的通用工作空间。
# SPACE_BASE_IMAGE 没有默认值：两阶段构建必须显式传入第一阶段实际产出的 Base
# 镜像引用。CI 中优先使用 digest，确保派生镜像使用的内容与已发布 Base 完全一致。
ARG SPACE_BASE_IMAGE
FROM ${SPACE_BASE_IMAGE}

# 从 GitHub 最新正式 Release 安装 trzsz Go 二进制，不引入额外 APT 源。
# Docker 缓存命中时不会查询新版本；更新时需禁用此层缓存。
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) trzsz_arch=x86_64 ;; \
        arm64) trzsz_arch=aarch64 ;; \
        *) echo 'Unsupported architecture for trzsz' >&2; exit 1 ;; \
    esac; \
    trzsz_tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 https://api.github.com/repos/trzsz/trzsz-go/releases/latest \
        -o "${trzsz_tmp}/release.json"; \
    jq -e --arg suffix "_linux_${trzsz_arch}.tar.gz" \
        '[.assets[] | select(.name | endswith($suffix))] | if length == 1 then .[0] else error("Expected one trzsz archive") end' \
        "${trzsz_tmp}/release.json" > "${trzsz_tmp}/asset.json"; \
    trzsz_url="$(jq -er '.browser_download_url' "${trzsz_tmp}/asset.json")"; \
    trzsz_sha256="$(jq -er '.digest | select(test("^sha256:[0-9a-f]{64}$")) | ltrimstr("sha256:")' "${trzsz_tmp}/asset.json")"; \
    curl -fsSL --retry 3 "${trzsz_url}" -o "${trzsz_tmp}/trzsz.tar.gz"; \
    printf '%s  %s\n' "${trzsz_sha256}" "${trzsz_tmp}/trzsz.tar.gz" | sha256sum -c -; \
    tar -xzf "${trzsz_tmp}/trzsz.tar.gz" -C "${trzsz_tmp}" --strip-components=1; \
    install -m 0755 "${trzsz_tmp}/trz" "${trzsz_tmp}/tsz" "${trzsz_tmp}/trzsz" /usr/local/bin/; \
    trz --version; \
    tsz --version; \
    trzsz --version; \
    rm -rf "${trzsz_tmp}"

# IDE、Web Terminal、Jupyter 等交互工具应作为
# 用户级扩展安装到持久化 HOME，并由 docker run、Compose 或 Kubernetes 命令启动。
LABEL org.opencontainers.image.title="manual-space" \
      org.opencontainers.image.description="Generic persistent workspace for human-operated sessions"
