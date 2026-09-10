# mise activation 仅适用于交互式 Shell；其他进程依赖镜像级 shims PATH。
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi
