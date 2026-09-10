# mise activation 仅适用于交互式 Shell；其他进程依赖镜像级 shims PATH。
if type -q mise
    mise activate fish | source
end
