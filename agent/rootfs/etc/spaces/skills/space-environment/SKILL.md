---
name: space-environment
description: Understand and use the Spaces container environment, including persistent storage, mise-managed SDKs, user software layout, and startup hooks. Use when installing tools or runtimes, configuring an agent environment, or deciding where files should persist.
---

# Spaces Environment

Use this as environment context, not as blanket permission to change the system.
Follow the user's request and the current project's instructions.

## Container model

`agent-space` is a containerized Linux workspace built on `space-base`. The
container is replaceable; its writable layer is lost when the container is
recreated.

The default startup flow is:

```text
tini
  -> /entrypoint.sh
  -> /entrypoint.d/system/*.sh
  -> /entrypoint.d/user/*.sh
  -> final command
```

The user hooks and final command normally run as `space`. Runtime options can
change that behavior, so treat it as the default rather than an unconditional
fact.

- `/entrypoint.sh` and `/entrypoint.d/system` are managed by the image.
- `/entrypoint.d/system/10-space-directories.sh` initializes the persistent
  roots and default shell configuration.
- `/entrypoint.d/system/20-agent-skills.sh` exposes the image-managed Skills
  through the persistent user HOME.
- `/entrypoint.d/user` contains persistent user provisioning hooks. Hooks run
  on every start and should be idempotent.
- The container command selects and starts the actual Agent. The image does not
  require a specific Agent product.

## Persistent storage

Keep durable state in the mounted persistent directories:

| Path | Purpose |
| --- | --- |
| `/home/space` | User tools, SDKs, Agent configuration, application data, and caches |
| `/workspace` | Repositories, project configuration, documents, and work products |
| `/entrypoint.d/user` | Repeatable provisioning needed after a container is recreated |

An installation made only in the container writable layer is temporary. Put
project results in `/workspace`, and put reusable user environment state under
`/home/space`.

## SDKs and tools with mise

`mise` is preinstalled. The image also contains build-time-pinned Node.js LTS
and stable Python bootstrap runtimes under `/usr/local/share/mise`. Their exact
versions are recorded in `/etc/spaces/agent-runtime.env`.

These built-ins are replaceable defaults. Prefer mise for SDKs and command-line
tools that belong to the user or a project; user and project versions take
priority over the image defaults.

Use project configuration when the version belongs to a repository:

```bash
mise use node@lts python@latest
mise install
mise current
```

`mise use` creates or updates `mise.toml` in the current project. Use the
persistent user-global configuration only for defaults shared across projects:

```bash
mise use --global node@lts go@latest
```

Other useful commands:

```bash
mise ls
mise exec -- <command>
mise run <task>
mise --version
```

For advanced configuration, environments, tasks, plugins, and tool backends,
read the [mise documentation](https://mise.jdx.dev/) or the
[jdx/mise repository](https://github.com/jdx/mise).

## User software layout

For user-installed software outside mise:

- Put executable entry points in `/home/space/.local/bin`.
- Put application payloads and data in `/home/space/.local/share/<application>`
  or the application's documented user directory under `/home/space`.
- Do not install only a symlink in `.local/bin` while leaving its target in a
  disposable container location.
- System packages may install under system paths. If they must survive a
  container recreation, express the repeatable installation in an idempotent
  user hook and use `sudo` there when required.

## Built-in bootstrap tools

The image includes `ripgrep`, `file`, SQLite, Git LFS, rsync, Poppler PDF tools,
MarkItDown, and Chrome DevTools MCP. Use the dedicated `document-conversion`
and `chrome-devtools` Skills when those capabilities apply.

Chrome, Pandoc, TeX Live, LibreOffice, OCR engines, FFmpeg, ImageMagick, and a
full compiler toolchain are intentionally runtime additions rather than image
defaults.

## Credentials

Prefer the secret mechanism provided by the container platform. Avoid writing
credentials into the image, a source repository, or persistent startup hooks.
