# 由 ~/.bashrc 加载；各工具只需维护 bash.d 中自己的配置文件。
case $- in
  *i*) ;;
  *) return ;;
esac

# 先加载镜像配置，再加载用户配置；每组按文件名顺序执行。
_spaces_load_bash_config() {
  local config
  for config in /etc/spaces/shell/bash.d/*.sh "${HOME}"/.config/spaces/shell/bash.d/*.sh; do
    [[ -f "${config}" && -r "${config}" ]] || continue
    source "${config}"
  done
}
_spaces_load_bash_config
unset -f _spaces_load_bash_config
