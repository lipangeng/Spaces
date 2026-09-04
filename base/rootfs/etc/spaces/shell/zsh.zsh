# 该文件由镜像维护，并由 space 用户的 ~/.zshrc 加载。
# mise activation 仅适用于交互式 Zsh；其他进程依赖镜像级 shims PATH。
[[ -o interactive ]] || return 0

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
