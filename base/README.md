# Space Base

[简体中文](README.zh-CN.md) · [Project overview](../README.md)

`space-base` is the shared runtime foundation for Spaces. It provides Debian, a stable user and directory contract, common operational tools, mise, Docker client tools, shell integration, and a two-phase hook framework. It intentionally does not bundle a specific IDE, language runtime, or AI agent.

## Base system

- Base image: `debian:trixie-slim`
- Default working directory: `/workspace`
- Default command: `bash`
- Default startup identity: root, because the Dockerfile does not set `USER`; callers may override it
- Init process: `tini`
- Entrypoint: `/entrypoint.sh`

Build-time user IDs can be adjusted to match shared storage:

| Argument | Default | Purpose |
| --- | ---: | --- |
| `SPACE_UID` | `1000` | UID of the `space` user |
| `SPACE_GID` | `1000` | GID of the `space` group |

```bash
docker build \
  --build-arg SPACE_UID=1001 \
  --build-arg SPACE_GID=1001 \
  -t space-base:local \
  ./base
```

## Included tools

```text
bash, zsh, fish, bash-completion
curl, wget, git, openssh-client, ca-certificates, openssl, gnupg
jq, less, vim, tree, tmux
tar, gzip, unzip, zip, xz-utils, 7zip
procps, psmisc, htop, sysstat, strace, lsof
iproute2, iputils-ping, dnsutils, netcat-openbsd, nmap, tcpdump
sudo, gosu, tini
fontconfig, fonts-noto-cjk
mise
docker-ce-cli, docker-buildx-plugin, docker-compose-plugin
```

The Docker daemon is not included. The client can connect to an explicitly configured external daemon or DinD service, for example through `DOCKER_HOST`.

Full development toolchains and upper-layer applications are intentionally excluded. Install language runtimes with mise and user applications under `/home/space`.

## User and directories

```text
user:      space
group:     space
home:      /home/space
workspace: /workspace
```

The `space` user has passwordless sudo:

```text
space ALL=(ALL) NOPASSWD:ALL
```

The image-level PATH starts with:

```text
/home/space/.local/bin
/home/space/.local/share/mise/shims
```

This makes user-installed tools available to interactive shells, non-interactive commands, IDE processes, and agents without depending on shell startup files.

## Persistence

The Dockerfile declares three volumes:

| Path | Contents |
| --- | --- |
| `/home/space` | mise installations, user applications, shell configuration, application data, history, and caches |
| `/workspace` | Repositories, documents, project configuration, test data, and other work products |
| `/entrypoint.d/user` | Persistent user provisioning scripts |

Temporary packages installed into the container root filesystem are lost when the container is recreated. Record long-lived system requirements in user hooks, and prefer mise or `/home/space/.local` for user-level software.

## Startup lifecycle

```text
tini
  └─ /entrypoint.sh using the configured startup identity
       ├─ /entrypoint.d/system/*.sh
       ├─ /entrypoint.d/user/*.sh
       └─ final command
```

The Dockerfile defaults to root, but `docker run --user` and orchestrator security settings may override the entrypoint identity. System hooks always use that actual startup identity; the script does not infer or rewrite its own identity.

### System hooks

System hooks are image-managed files under `/entrypoint.d/system`.

- Only first-level `*.sh` files are processed.
- Files use version sorting, such as `10-directories.sh` before `20-config.sh`.
- Executable files run as independent processes using their shebang.
- Non-executable files are sourced into the entrypoint and may intentionally modify its environment or shell state.
- Hooks use the entrypoint's actual startup identity.
- A hook failure stops container startup.

The built-in `10-space-directories.sh` creates missing persistent directories and installs default shell configuration only when the target file does not already exist.

### User hooks

User hooks are persistent, user-managed files under `/entrypoint.d/user`.

- Only first-level `*.sh` files are processed.
- Files use the same version sorting as system hooks.
- Executable files run as independent processes using their own shebang.
- Non-executable files run as independent Bash processes.
- User hooks are never sourced into the entrypoint.
- Hooks run as `space` by default, or as the startup identity when user switching is disabled.
- A hook failure stops container startup.

Because every user hook is an independent process, an `export`, `cd`, alias, or shell function does not affect later hooks or the final command. Persist environment changes through shell configuration, mise, or another file under `/home/space`.

Example user hook:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v ffmpeg >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ffmpeg
fi
```

Make it executable to use its shebang:

```bash
chmod +x entrypoint.d/user/20-ffmpeg.sh
```

## Entrypoint configuration

All boolean values accept `1/0`, `true/false`, `yes/no`, or `on/off`, case-insensitively. Invalid values stop startup.

| Variable | Default | Behavior |
| --- | --- | --- |
| `SPACE_USER_SWITCH` | `true` | Run user hooks and the final command as `space`; when false, preserve the startup identity and environment |
| `SKIP_SYSTEM_ENTRYPOINT` | `false` | Skip all system hooks |
| `SKIP_USER_ENTRYPOINT` | `false` | Skip all user hooks |
| `HIDE_ENTRYPOINT_ARGS` | `false` | Log only the executable name instead of the complete final command |

When `SPACE_USER_SWITCH=true`, user hooks and the final command receive:

```text
HOME=/home/space
USER=space
LOGNAME=space
```

If the startup identity cannot switch users, `gosu` fails and startup stops. There is no silent fallback to a different identity.

When `SPACE_USER_SWITCH=false`, the entrypoint does not call `gosu` and preserves the caller's UID, GID, `HOME`, `USER`, and `LOGNAME`. The caller remains responsible for directory permissions and for deciding whether system hooks can complete.

## Shell and mise integration

Image-owned shell fragments live under `/etc/spaces/shell`, with default user templates under `/etc/spaces/templates`.

On first initialization, missing files are created without overwriting persistent user configuration:

```text
/home/space/.bashrc
/home/space/.profile
/home/space/.zshrc
/home/space/.config/fish/config.fish
```

Interactive Bash, Zsh, and Fish sessions load the matching mise activation script. The mise shims directory remains in the image-level PATH so tools are also available to non-interactive processes.

```bash
mise use -g node@24
mise use -g python@3.14
mise use -g go@latest
```

Project-specific versions remain in a project's `mise.toml` under `/workspace`.

## Running the image

Interactive workspace:

```bash
docker run --rm -it \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  -v space-user-hooks:/entrypoint.d/user \
  space-base:local
```

Run an explicit command:

```bash
docker run --rm \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  space-base:local \
  bash -lc 'mise current'
```

Preserve a caller-selected startup identity instead of switching to `space`:

```bash
docker run --rm -it \
  --user 1001:1001 \
  -e SPACE_USER_SWITCH=false \
  -e SKIP_SYSTEM_ENTRYPOINT=true \
  -v "$(pwd)":/workspace \
  space-base:local
```

The last mode is caller-managed: the selected UID must be able to access all required files and mounts.

## Security notes

- Passwordless sudo is intentional for this personal workspace model.
- Do not use `--privileged` unless the workload explicitly requires it.
- Avoid host PID mode, broad host filesystem mounts, and unnecessary capabilities.
- Access to a Docker daemon can grant extensive control over that daemon's host. Do not mount a host Docker socket merely because the CLI is installed.
- User hook directories are persistent executable input; only mount content you trust.
