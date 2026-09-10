# Debian 13 稳定版。使用代号而非固定补丁版本，以持续获得同一大版本的
# 安全更新，同时避免跟随 testing/unstable 发生不可控的系统升级。
FROM debian:trixie-slim

# space 用户的 UID/GID 可在构建时覆盖，以匹配宿主机或共享存储的权限。
ARG SPACE_UID=1000
ARG SPACE_GID=1000

# Debian 官方仓库中的基础、交互和诊断工具。
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        7zip \
        bash \
        bash-completion \
        ca-certificates \
        curl \
        dnsutils \
        fish \
        fontconfig \
        fonts-noto-cjk \
        git \
        gnupg \
        gosu \
        gzip \
        htop \
        iproute2 \
        iputils-ping \
        jq \
        less \
        lsof \
        netcat-openbsd \
        nmap \
        openssl \
        openssh-client \
        procps \
        psmisc \
        strace \
        sudo \
        sysstat \
        tar \
        tcpdump \
        tini \
        tmux \
        tree \
        unzip \
        vim \
        wget \
        xz-utils \
        zip \
        zsh; \
    rm -rf /var/lib/apt/lists/*

# 配置 mise 官方仓库并安装 mise。仓库配置与对应软件放在同一层，
# 便于识别依赖关系；APT 索引也在该层内清理。
RUN set -eux; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://mise.jdx.dev/gpg-key.pub \
        -o /etc/apt/keyrings/mise-archive-keyring.asc; \
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.jdx.dev/deb stable main" \
        > /etc/apt/sources.list.d/mise.list; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mise; \
    rm -rf /var/lib/apt/lists/*

# 配置 Docker 官方仓库并安装客户端组件。镜像不包含 Docker daemon，
# 客户端可通过 DOCKER_HOST 连接独立 daemon，例如 DinD 服务。
RUN set -eux; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    docker_suite="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME}")"; \
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://download.docker.com/linux/debian' \
        "Suites: ${docker_suite}" \
        'Components: stable' \
        'Signed-By: /etc/apt/keyrings/docker.asc' \
        > /etc/apt/sources.list.d/docker.sources; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-buildx-plugin \
        docker-ce-cli \
        docker-compose-plugin; \
    rm -rf /var/lib/apt/lists/*

# 创建统一的 space 用户，并授予显式 sudo 所需的权限。
# 不设置 Dockerfile USER：entrypoint 必须先以 root 完成系统初始化。
RUN set -eux; \
    groupadd --gid "${SPACE_GID}" space; \
    useradd --uid "${SPACE_UID}" --gid space --no-create-home --shell /bin/bash space; \
    echo "space ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/space; \
    chmod 0440 /etc/sudoers.d/space

# HOME 和 WORKSPACE 是所有 Space 的稳定路径约定。将用户级 bin 和 mise shims
# 放入镜像级 PATH，确保非交互 shell、CMD、IDE 和 Agent 子进程都能找到工具。
# 使用 Debian 内置的 C.UTF-8 locale，确保 Vim 等程序正确处理中文。
ENV WORKSPACE=/workspace \
    LANG=C.UTF-8 \
    LC_CTYPE=C.UTF-8 \
    TERM=xterm-256color \
    COLORTERM=truecolor \
    PATH="/home/space/.local/bin:/home/space/.local/share/mise/shims:$PATH"

# rootfs 提供统一 entrypoint、镜像管理的 system hooks，以及 `/etc/spaces`
# 下由镜像维护的 Bash、Zsh 和 Fish 公共配置与用户 rc 模板。
COPY rootfs/ /

# 固化脚本权限并创建目录。system hooks 归 root，其余持久化目录归 space。
RUN set -eux; \
    chmod 0755 /entrypoint.sh /entrypoint.d/system/*.sh; \
    install -d -o root -g root -m 0755 /entrypoint.d/system; \
    install -d -o space -g space -m 0755 \
        /home/space \
        /home/space/.cache \
        /home/space/.config \
        /home/space/.config/fish \
        /home/space/.config/mise \
        /home/space/.config/bash.d \
        /home/space/.config/zsh.d \
        /home/space/.config/fish.d \
        /home/space/.local \
        /home/space/.local/bin \
        /home/space/.local/share \
        /home/space/.local/share/mise \
        /workspace \
        /entrypoint.d/user

# 初始化用户 Shell 配置；容器启动时的 system hook 会补充缺失文件，
# 但不会覆盖持久化 HOME 中已有的用户配置。
RUN set -eux; \
    install -o space -g space -m 0644 /etc/spaces/templates/bashrc /home/space/.bashrc; \
    install -o space -g space -m 0644 /etc/spaces/templates/profile /home/space/.profile; \
    install -o space -g space -m 0644 /etc/spaces/templates/zshrc /home/space/.zshrc; \
    install -o space -g space -m 0644 \
        /etc/spaces/templates/config.fish /home/space/.config/fish/config.fish

# 所有正常业务进程默认从工作目录启动。
WORKDIR /workspace

# 这三个目录构成 Space 的持久化边界：用户环境、工作成果和用户初始化声明。
# 实际存储可由 Docker volume、bind mount 或编排平台的持久卷提供。
VOLUME ["/home/space", "/workspace", "/entrypoint.d/user"]

# tini 作为 PID 1 负责转发信号和回收孤儿进程。entrypoint 以 root 启动，依次执行：
# root system hooks -> space user hooks -> space final process。
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# 基础镜像不绑定具体应用；调用方可通过 docker run、Compose 或 Kubernetes 覆盖。
CMD ["bash"]
