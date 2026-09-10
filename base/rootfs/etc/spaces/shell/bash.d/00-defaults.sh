# 保留终端提供的 TERM，仅在未设置或为空时使用默认值。
export TERM="${TERM:-xterm-256color}"

# 忽略连续重复和空格开头的命令；退出时追加历史，避免覆盖其他会话。
# histappend 不会实时导入其他窗口的历史。
HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth
shopt -s histappend

# 支持直接输入目录切换路径（镜像中的 Bash 5 支持 autocd）。
shopt -s autocd

# 补全有多个匹配时直接显示候选列表，保留原有按键绑定。
bind 'set show-all-if-ambiguous on'
