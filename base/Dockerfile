FROM debian:latest

RUN set -eux ;\
    apt-get update -y;\
    \
    apt-get install -y \
        bash zsh fish openssl sudo \
        htop tcpdump busybox tini libncurses6 strace lsof coreutils tmux sysstat\
        curl wget vim bind9-dnsutils nmap iproute2 dnsutils 7zip\
        psmisc tree jq cmake\
      	unzip zip bash-completion \
        fontconfig fonts-dejavu zlib1g \
        gnupg ca-certificates p11-kit tzdata \
    	git gh \
    	;\
    \
    install -dm 755 /etc/apt/keyrings ;\
    curl -fSs https://mise.jdx.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise-archive-keyring.asc 1> /dev/null ;\
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list ;\
    apt update -y ;\
    apt install -y mise ;\
    mkdir -p /opt/mise/{config,data,cache} ;\
    echo 'PATH=~/.local/share/mise/shims:$PATH' >> /etc/profile ;\
    \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc ;\
    chmod a+r /etc/apt/keyrings/docker.asc ;\
    echo 'Types: deb' > /etc/apt/sources.list.d/docker.sources ;\
    echo 'URIs: https://download.docker.com/linux/debian' >> /etc/apt/sources.list.d/docker.sources ;\
    echo "Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")" >> /etc/apt/sources.list.d/docker.sources ;\
    echo 'Components: stable' >> /etc/apt/sources.list.d/docker.sources ;\
    echo 'Signed-By: /etc/apt/keyrings/docker.asc' >> /etc/apt/sources.list.d/docker.sources ;\
    apt-get update -y ;\
    apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin ;\
    \
    apt-get clean ;\
    rm -rf /var/lib/apt/lists/* ;\
    rm -rf /tmp/*

ENV PATH="/home/space/.local/share/mise/shims:${PATH}"

COPY rootfs/ /

RUN set -eux ;\
    \
    chmod +x /usr/local/bin/entrypoint.sh ;\
    mkdir -pv /entrypoint.d/user /entrypoint.d/system

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/entrypoint.sh"]

CMD ["bash"]