# 该文件由镜像维护，并由 space 用户的 Fish 配置加载。
# mise activation 仅适用于交互式 Fish；其他进程依赖镜像级 shims PATH。
status is-interactive; or return

if type -q mise
    mise activate fish | source
end
