# 由 Fish config.fish 加载；各工具只需维护 fish.d 中自己的配置文件。
status is-interactive; or return

# Fish 的 for 通配符允许空目录；先加载镜像配置，再加载用户配置。
begin
    set -l config
    for config in /etc/spaces/shell/fish.d/*.fish "$HOME"/.config/spaces/shell/fish.d/*.fish
        if test -f "$config"; and test -r "$config"
            source "$config"
        end
    end
end
