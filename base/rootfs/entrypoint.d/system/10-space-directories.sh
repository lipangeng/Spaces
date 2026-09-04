#!/usr/bin/env bash

# 初始化 Space 的持久化目录和默认 Shell 配置。
#
# Docker volume 或 bind mount 会覆盖镜像构建时创建的目录，因此容器每次启动时
# 都需要重新确认以下三个持久化根目录可由 space 用户访问：
#
#   /home/space        用户环境、配置和用户级软件
#   /workspace         工作成果和项目文件
#   /entrypoint.d/user 用户维护的启动 hooks
#
# SPACE_FIX_PERMISSIONS 默认为 true。启用时，本脚本检查三个持久化根目录
# 和 HOME 中由镜像管理的三个目录骨架，并把不属于 space:space 的目录修复为
# space:space；关闭时只创建缺失目录，不修改已有目录。修复不递归处理已有
# 内容，也不使用 chmod，避免改动 bind mount 在宿主机上的其他文件。

set -Eeuo pipefail

# 返回是否启用持久化目录权限修复。
# 变量值已由 entrypoint.sh 统一校验；这里仍保留默认值，以便单独运行本脚本。
permission_fix_enabled() {
  case "${SPACE_FIX_PERMISSIONS:-true}" in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Oo][Nn]) return 0 ;;
    *) return 1 ;;
  esac
}

# 创建缺失的用户目录，但不修改已存在目录的属主、属组或 mode。
# 已存在的持久化根目录由 fix_persistent_directory_ownership 按开关统一处理。
ensure_space_directory() {
  local directory="$1"

  if [[ -d "${directory}" ]]; then
    return 0
  fi

  if [[ -e "${directory}" ]]; then
    logger_fatal "Expected a directory but found another file type: ${directory}"
    return 1
  fi

  install -d -o space -g space -m 0755 "${directory}"
}

# 将一个持久化根目录的属主和属组修复为 space:space。
#
# 这里只处理挂载点本身。后续由 space 创建的内容会自然归 space 所有；挂载中
# 已存在内容的 UID/GID 应由调用方通过 SPACE_UID/SPACE_GID 或宿主机权限管理。
# 不递归 chown，避免启动时扫描大型目录或改写整个宿主机目录树。
fix_persistent_directory_ownership() {
  local directory="$1"
  local actual_gid
  local actual_uid
  local expected_gid
  local expected_uid

  expected_uid="$(id -u space)"
  expected_gid="$(id -g space)"
  read -r actual_uid actual_gid < <(stat -c '%u %g' -- "${directory}")

  if [[ "${actual_uid}" == "${expected_uid}" ]] && \
    [[ "${actual_gid}" == "${expected_gid}" ]]; then
    logger_debug "Persistent directory ownership is correct: ${directory}"
    return 0
  fi

  logger_info "Repairing persistent directory ownership: ${directory}"
  chown space:space -- "${directory}"
}

# system hooks 属于镜像且始终保持 root 管理；它不属于用户持久化边界。
install -d -o root -g root -m 0755 /entrypoint.d/system

# 挂载后的目录可能为空，因此同时补齐 Shell 和 mise 使用的标准用户目录。
for directory in \
  /home/space \
  /home/space/.cache \
  /home/space/.config \
  /home/space/.config/fish \
  /home/space/.config/mise \
  /home/space/.local \
  /home/space/.local/bin \
  /home/space/.local/share \
  /home/space/.local/share/mise \
  /workspace \
  /entrypoint.d/user; do
  ensure_space_directory "${directory}"
done

# 除三个持久化根目录外，只修复 HOME 中会被 install -d 隐式创建的
# 标准中间目录。列表是有限的，不会递归扫描或修改其他用户内容。
if permission_fix_enabled; then
  for directory in \
    /home/space \
    /home/space/.config \
    /home/space/.local \
    /home/space/.local/share \
    /workspace \
    /entrypoint.d/user; do
    fix_persistent_directory_ownership "${directory}"
  done
else
  logger_warning \
    "Skipped persistent directory ownership repair (SPACE_FIX_PERMISSIONS=false)"
fi

# 仅在用户尚未创建对应配置时，从镜像模板安装默认文件。
install_user_config() {
  local template="$1"
  local target="$2"

  if [[ ! -e "${target}" ]]; then
    install -o space -g space -m 0644 "${template}" "${target}"
  fi
}

# 按镜像中实际存在的 Shell 安装相应配置；任何已有用户文件都不会被覆盖。
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
