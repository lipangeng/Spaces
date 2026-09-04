# 该文件由镜像维护，并由 space 用户的 ~/.bashrc 加载。
# mise activation 仅适用于交互式 Bash；其他进程依赖镜像级 shims PATH。
case $- in
  *i*) ;;
  *) return ;;
esac

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi
