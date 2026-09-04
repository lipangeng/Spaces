#!/usr/bin/env bash

# Space 容器的统一启动入口。
#
# Dockerfile 默认以 root 启动本脚本，但调用方可以覆盖启动用户。entrypoint 不
# 推断或改写自身身份，只在执行 user hooks 和最终主进程时按开关切换用户：
#
#   启动身份               -> /entrypoint.d/system/*.sh
#   space 或启动身份       -> /entrypoint.d/user/*.sh
#   space 或启动身份       -> 容器主命令
#
# 可选控制变量：
#
#   SPACE_USER_SWITCH       是否将 user hooks 和主进程切换为 space，默认 true
#   SPACE_FIX_PERMISSIONS   是否修复三个持久化目录的 ownership，默认 true
#   SKIP_SYSTEM_ENTRYPOINT  是否跳过 system hooks，默认 false
#   SKIP_USER_ENTRYPOINT    是否跳过 user hooks，默认 false
#   HIDE_ENTRYPOINT_ARGS    是否隐藏启动日志中的命令参数，默认 false
#
# 布尔值接受 1/0、true/false、yes/no、on/off，英文值不区分大小写。

# -E：让未来配置的 ERR trap 继承到函数、命令替换和子 Shell；当前未定义 trap。
# -e：未被 if、while、&&、|| 等条件结构处理的失败会终止初始化。
# -u：读取未定义变量时报错；可选变量必须使用 ${VAR:-default} 形式读取。
# -o pipefail：管道中任一命令失败时，整条管道返回失败。
set -Eeuo pipefail

# space 的身份和 HOME 是镜像协议的一部分；仅在确实切换到 space 时使用。
readonly SPACE_HOME=/home/space
readonly SPACE_USER=space

# 日志颜色供本脚本及 hooks 中导出的日志函数复用。
export COLOR_DEBUG="\e[1;38;5;240m"
export COLOR_INFO="\e[1;36m"
export COLOR_WARNING="\e[1;33m"
export COLOR_ERROR="\e[1;31m"
export COLOR_FATAL="\e[1;41;97m"
export COLOR_RESET="\e[0m"

# 输出统一格式的带时间、级别和调用来源的日志。
#
# 参数：日志级别、ANSI 颜色，以及一到多个消息参数。
# BASH_SOURCE 优先显示实际调用 logger_* 的脚本，而不是固定显示 entrypoint.sh。
log_message() {
  local level="$1"
  local color="$2"
  shift 2
  printf '%b%s [%s] [%s]: %s%b\n' \
    "${color}" "$(date '+%Y-%m-%d %T')" "${level}" \
    "${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-$0}}" "$*" "${COLOR_RESET}"
}

logger_debug() {
  log_message DEBUG "${COLOR_DEBUG}" "$@"
}

logger_info() {
  log_message INFO "${COLOR_INFO}" "$@"
}

logger_warning() {
  log_message WARNING "${COLOR_WARNING}" "$@"
}

logger_error() {
  log_message ERROR "${COLOR_ERROR}" "$@"
}

logger_fatal() {
  log_message FATAL "${COLOR_FATAL}" "$@"
}

# 允许由 Bash 启动的独立 hook 直接调用相同的日志函数。
export -f log_message logger_debug logger_info logger_warning logger_error logger_fatal

# 判断给定值是否表示 true。
#
# 参数：一个已经过 validate_boolean 校验的布尔字符串。
# 返回：true 值返回 0，其他值返回 1；不输出内容。
is_true() {
  case "$1" in
    1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Oo][Nn]) return 0 ;;
    *) return 1 ;;
  esac
}

# 校验显式传入的布尔值。
#
# 参数：变量名、变量值。空值合法，表示使用调用点定义的默认行为。
# 返回：合法值返回 0；非法值记录 FATAL 日志并返回 1。
validate_boolean() {
  local name="$1"
  local value="$2"

  case "${value}" in
    '' | 0 | 1 | [Tt][Rr][Uu][Ee] | [Ff][Aa][Ll][Ss][Ee] | \
      [Yy][Ee][Ss] | [Nn][Oo] | [Oo][Nn] | [Oo][Ff][Ff])
      return 0
      ;;
    *)
      logger_fatal \
        "${name} must be one of: 1, 0, true, false, yes, no, on, off"
      return 1
      ;;
  esac
}

# 记录即将替换 entrypoint 的最终命令。
#
# 第一个参数是用于日志展示的执行身份，其余参数是未经拼接的原始 argv。默认使用
# printf %q 逐项转义，以便从日志识别参数边界；HIDE_ENTRYPOINT_ARGS=true 时只
# 记录可执行文件，避免 token、密码等敏感参数进入日志。
log_execution() {
  local run_user="$1"
  local command_line
  shift

  if is_true "${HIDE_ENTRYPOINT_ARGS:-}"; then
    printf -v command_line '%q' "$1"
    logger_info "Executing process as ${run_user}: ${command_line} [arguments hidden]"
    return 0
  fi

  printf -v command_line '%q ' "$@"
  logger_info "Executing process as ${run_user}: ${command_line% }"
}

# 以 entrypoint 的实际启动身份、按版本顺序执行镜像维护的 system hooks。
#
# 仅处理目录第一层的 *.sh 文件；目录不存在时直接成功返回。文件名使用版本排序，
# 因此 10-foo.sh 会先于 20-bar.sh 执行。可执行脚本作为独立进程运行，并使用自身
# shebang；不可执行脚本 source 到当前 entrypoint，可以有意修改后续阶段使用的
# 环境、函数或 Shell 状态。该 source 语义仅适用于镜像管理的 system 目录。
#
# system hook 不做身份切换，也不保证实际启动身份一定是 root；权限不足时由具体
# hook 返回失败，并在 set -e 规则下终止启动。
process_system_init_files() {
  local directory=/entrypoint.d/system
  local file

  [[ -d "${directory}" ]] || return 0

  # NUL 分隔可正确处理包含空格的文件名，sort -V 支持 10-foo、20-bar 的顺序。
  while IFS= read -r -d '' file; do
    if [[ -x "${file}" ]]; then
      logger_info "Running system hook: ${file}"
      "${file}"
    else
      logger_info "Sourcing system hook: ${file}"
      source "${file}"
    fi
  done < <(find "${directory}" -maxdepth 1 -type f -name '*.sh' -print0 | sort -zV)
}

# 返回当前是否启用 space 用户切换。
#
# SPACE_USER_SWITCH 未设置或为空时默认为 true；显式 false 值返回 1。
# 该函数只判断配置，不执行身份切换。
space_user_switch_enabled() {
  is_true "${SPACE_USER_SWITCH:-true}"
}

# 运行一个 user hook 命令并等待其结束。
#
# 开启用户切换时，通过 gosu 以 space 运行，并在子进程边界设置匹配的
# HOME/USER/LOGNAME；关闭时以 entrypoint 的实际启动身份和原始环境直接运行。
# 本函数不使用 exec，因此每个 hook 结束后控制权会返回 entrypoint。
run_user_command() {
  if space_user_switch_enabled; then
    gosu "${SPACE_USER}" env \
      HOME="${SPACE_HOME}" \
      USER="${SPACE_USER}" \
      LOGNAME="${SPACE_USER}" \
      "$@"
  else
    "$@"
  fi
}

# 使用最终命令永久替换 entrypoint。
#
# 身份和环境选择规则与 run_user_command 一致，但这里使用 exec，不会返回。
# 这样最终进程保留原始 argv，并直接接收 tini 转发的信号。
exec_user_command() {
  if space_user_switch_enabled; then
    exec gosu "${SPACE_USER}" env \
      HOME="${SPACE_HOME}" \
      USER="${SPACE_USER}" \
      LOGNAME="${SPACE_USER}" \
      "$@"
  else
    exec "$@"
  fi
}

# 返回供日志展示的最终执行身份。
#
# 开启切换时返回固定用户名 space；关闭时返回实际启动 UID。使用 UID 而不是
# id -un，可兼容 /etc/passwd 中不存在对应用户名的纯数字 UID。
user_execution_identity() {
  if space_user_switch_enabled; then
    printf '%s' "${SPACE_USER}"
  else
    printf 'UID %s' "$(id -u)"
  fi
}

# 按用户切换开关选择实际启动身份或 space，并按版本顺序执行持久化的 user hooks。
#
# 与 system hooks 一样，仅处理目录第一层的 *.sh 文件并使用版本排序。user hooks
# 始终是独立进程，不能通过 source 修改 entrypoint 父进程。带 executable bit 的
# 文件使用自身 shebang，可选择 Bash、Zsh、Fish 或其他解释器；不带 executable
# bit 的 .sh 文件明确交给 Bash 执行。如需系统权限，hook 应显式调用 sudo。
process_user_init_files() {
  local directory=/entrypoint.d/user
  local file
  local run_user

  [[ -d "${directory}" ]] || return 0

  run_user="$(user_execution_identity)"

  # 与 system hooks 使用相同的文件筛选和排序规则，但不共享 source 语义。
  while IFS= read -r -d '' file; do
    if [[ -x "${file}" ]]; then
      logger_info "Running user hook as ${run_user}: ${file}"
      run_user_command "${file}"
    else
      logger_info "Running user hook with Bash as ${run_user}: ${file}"
      run_user_command /bin/bash "${file}"
    fi
  done < <(find "${directory}" -maxdepth 1 -type f -name '*.sh' -print0 | sort -zV)
}

# 校验配置、依次执行两阶段 hooks，并启动最终主进程。
#
# system hooks 总是使用实际启动身份；用户切换开关只影响 user hooks 和主进程。
# 任一未跳过的 hook 失败都会终止启动，避免在初始化不完整时继续运行服务。
main() {
  local run_user

  validate_boolean SPACE_USER_SWITCH "${SPACE_USER_SWITCH:-}"
  validate_boolean SPACE_FIX_PERMISSIONS "${SPACE_FIX_PERMISSIONS:-}"
  validate_boolean SKIP_SYSTEM_ENTRYPOINT "${SKIP_SYSTEM_ENTRYPOINT:-}"
  validate_boolean SKIP_USER_ENTRYPOINT "${SKIP_USER_ENTRYPOINT:-}"
  validate_boolean HIDE_ENTRYPOINT_ARGS "${HIDE_ENTRYPOINT_ARGS:-}"

  # 兼容显式传入的 "--" 分隔符；它不是最终命令的一部分。
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  logger_info "Container initialization started"

  # 跳过开关主要用于故障排查或调用方已完成初始化的特殊场景。
  if is_true "${SKIP_SYSTEM_ENTRYPOINT:-}"; then
    logger_warning "Skipped system hooks"
  else
    process_system_init_files
  fi

  if is_true "${SKIP_USER_ENTRYPOINT:-}"; then
    logger_warning "Skipped user hooks"
  else
    process_user_init_files
  fi

  # 即使调用方没有提供 CMD，也保持一个可交互的通用工作空间入口。
  if [[ $# -eq 0 ]]; then
    set -- bash
  fi

  # 使用 exec 让主进程直接接替 entrypoint，保持原始 argv 边界，并确保 tini 能将
  # 信号正确转发给实际进程；这里不会自动通过 /bin/sh -c 解析命令字符串。
  run_user="$(user_execution_identity)"
  log_execution "${run_user}" "$@"
  exec_user_command "$@"
}

# 保留调用方传入的参数边界，不进行字符串拼接或二次解析。
main "$@"
