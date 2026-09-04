#!/usr/bin/env bash

set -Eeuo pipefail

install -d -o root -g root -m 0755 /entrypoint.d/system
install -d -o space -g space -m 0755 \
  /home/space \
  /home/space/.cache \
  /home/space/.config/fish \
  /home/space/.config/mise \
  /home/space/.local/bin \
  /home/space/.local/share/mise \
  /workspace \
  /entrypoint.d/user

install_user_config() {
  local template="$1"
  local target="$2"

  if [[ ! -e "${target}" ]]; then
    install -o space -g space -m 0644 "${template}" "${target}"
  fi
}

command -v bash >/dev/null 2>&1 && \
  install_user_config /etc/spaces/templates/bashrc /home/space/.bashrc
command -v bash >/dev/null 2>&1 && \
  install_user_config /etc/spaces/templates/profile /home/space/.profile
command -v zsh >/dev/null 2>&1 && \
  install_user_config /etc/spaces/templates/zshrc /home/space/.zshrc
command -v fish >/dev/null 2>&1 && \
  install_user_config \
    /etc/spaces/templates/config.fish \
    /home/space/.config/fish/config.fish
