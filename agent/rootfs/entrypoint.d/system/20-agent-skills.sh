#!/usr/bin/env bash

# 将 agent-space 内置的通用 Agent Skills 接入 space 用户的持久化 HOME。
#
# 镜像管理的规范源：
#
#   /etc/spaces/skills
#
# Agent 发现入口：
#
#   /home/space/.agents/skills/space -> /etc/spaces/skills
#
# space 目录作为内置 Skill 的 namespace，可以在规范源下继续增加多级 Skill。
# 已有用户文件、目录或指向其他位置的软链接始终保留。本功能属于辅助能力，创建
# 失败只记录 WARNING，不阻断容器启动。
#
# SPACE_LINK_AGENT_SKILLS 默认为 true；设为 false 可完全跳过自动链接。

set -Eeuo pipefail

readonly SPACE_SKILLS_SOURCE=/etc/spaces/skills
readonly SPACE_SKILLS_TARGET=/home/space/.agents/skills/space

# entrypoint 会导出统一日志函数；直接运行本脚本时使用无颜色的后备实现。
if ! declare -F logger_info >/dev/null 2>&1; then
  logger_info() {
    printf '%s [INFO] [%s]: %s\n' "$(date '+%Y-%m-%d %T')" "$0" "$*"
  }
fi

if ! declare -F logger_warning >/dev/null 2>&1; then
  logger_warning() {
    printf '%s [WARNING] [%s]: %s\n' "$(date '+%Y-%m-%d %T')" "$0" "$*" >&2
  }
fi

# 返回是否启用自动链接。非法值不会中止启动，而是记录警告并跳过。
agent_skill_link_enabled() {
  case "${SPACE_LINK_AGENT_SKILLS:-true}" in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Oo][Nn]) return 0 ;;
    0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Oo][Ff][Ff]) return 1 ;;
    *)
      logger_warning \
        "SPACE_LINK_AGENT_SKILLS has an invalid value; skipped built-in Skill link"
      return 1
      ;;
  esac
}

# 创建缺失的用户目录。已经存在的目录保持原 ownership 和 mode。
ensure_space_user_directory() {
  local actual_gid
  local actual_uid
  local directory="$1"
  local expected_gid
  local expected_uid

  if [[ -d "${directory}" ]]; then
    return 0
  fi

  if [[ -e "${directory}" || -L "${directory}" ]]; then
    logger_warning "Cannot create Agent Skills directory over existing path: ${directory}"
    return 1
  fi

  if ! mkdir -- "${directory}"; then
    logger_warning "Could not create Agent Skills directory: ${directory}"
    return 1
  fi

  if ! chmod 0755 -- "${directory}"; then
    logger_warning "Could not initialize Agent Skills directory mode: ${directory}"
    return 1
  fi

  if ! expected_uid="$(id -u space)" || ! expected_gid="$(id -g space)"; then
    logger_warning "Could not resolve the space user while creating: ${directory}"
    return 1
  fi

  if ! read -r actual_uid actual_gid \
    < <(stat -c '%u %g' -- "${directory}"); then
    logger_warning "Could not inspect Agent Skills directory: ${directory}"
    return 1
  fi

  if [[ "${actual_uid}" != "${expected_uid}" || \
    "${actual_gid}" != "${expected_gid}" ]] && \
    ! chown space:space -- "${directory}"; then
    logger_warning "Could not initialize Agent Skills directory ownership: ${directory}"
    return 1
  fi
}

main() {
  local actual_target

  if ! agent_skill_link_enabled; then
    return 0
  fi

  if [[ ! -d "${SPACE_SKILLS_SOURCE}" ]]; then
    logger_warning "Built-in Agent Skills source is missing: ${SPACE_SKILLS_SOURCE}"
    return 0
  fi

  if [[ -L "${SPACE_SKILLS_TARGET}" ]]; then
    if ! actual_target="$(readlink -- "${SPACE_SKILLS_TARGET}")"; then
      logger_warning "Could not inspect Agent Skills link: ${SPACE_SKILLS_TARGET}"
      return 0
    fi

    if [[ "${actual_target}" == "${SPACE_SKILLS_SOURCE}" ]]; then
      return 0
    fi

    logger_info \
      "Preserving existing Agent Skills link: ${SPACE_SKILLS_TARGET} -> ${actual_target}"
    return 0
  fi

  if [[ -e "${SPACE_SKILLS_TARGET}" ]]; then
    logger_info "Preserving existing Agent Skills path: ${SPACE_SKILLS_TARGET}"
    return 0
  fi

  ensure_space_user_directory /home/space/.agents || return 0
  ensure_space_user_directory /home/space/.agents/skills || return 0

  if ! ln -s -- "${SPACE_SKILLS_SOURCE}" "${SPACE_SKILLS_TARGET}"; then
    logger_warning "Could not link built-in Agent Skills: ${SPACE_SKILLS_TARGET}"
    return 0
  fi

  if ! chown -h space:space -- "${SPACE_SKILLS_TARGET}"; then
    logger_warning "Could not initialize Agent Skills link ownership: ${SPACE_SKILLS_TARGET}"
  fi
}

main "$@"
