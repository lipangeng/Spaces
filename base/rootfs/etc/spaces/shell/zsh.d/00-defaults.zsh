# 保留终端提供的 TERM，仅在未设置或为空时使用默认值。
export TERM="${TERM:-xterm-256color}"

# 持久化历史，并在使用同一历史文件的 Zsh 会话间共享。
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
# 仅忽略连续重复命令；空格开头的命令不保存到历史文件。
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# 支持直接输入目录切换路径；补全后将光标移到单词末尾。
setopt AUTO_CD
setopt ALWAYS_TO_END

# 先进行普通补全，连续请求补全时再循环选择候选项。
unsetopt MENU_COMPLETE
setopt AUTO_MENU
