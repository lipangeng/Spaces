# 保留终端提供的 TERM，仅在未设置或为空时使用默认值。
if not set -q TERM; or test -z "$TERM"
    set -gx TERM xterm-256color
else
    set -gx TERM "$TERM"
end

# Fish 原生支持隐式 cd 和交互式补全，无需额外选项或按键绑定。
