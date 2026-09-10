# 由 ~/.zshrc 加载；各工具只需维护 zsh.d 中自己的配置文件。
[[ -o interactive ]] || return 0

# (N) 允许配置目录为空；每组按文件名顺序执行。
_spaces_load_zsh_config() {
  local config
  for config in /etc/spaces/shell/zsh.d/*.zsh(N) "${HOME}"/.config/zsh.d/*.zsh(N); do
    [[ -f "${config}" && -r "${config}" ]] || continue
    source "${config}"
  done
}
_spaces_load_zsh_config
unfunction _spaces_load_zsh_config
