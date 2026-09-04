# Spaces

[简体中文](README.zh-CN.md)

Spaces is a Docker-based foundation for standardized, persistent, and extensible isolated workspaces. It defines a stable Linux runtime and lifecycle contract while leaving IDEs, language runtimes, and agents to user-managed extensions.

## Project status

| Component | Status | Purpose |
| --- | --- | --- |
| [`space-base`](base/README.md) | Available | Shared Debian environment, user model, persistence paths, mise, and entrypoint framework |
| [`manual-space`](manual/README.md) | Initialized | Generic workspace operated by a human; not tied to a particular IDE |
| [`agent-space`](agent/README.md) | Initialized | Generic workspace for AI agents; not tied to a particular agent product |

The two derived images are intentionally minimal: they establish independent image entry points while inheriting the complete `space-base` contract. Specific tools remain user-managed extensions.

## Design principles

- Keep the base image general-purpose and maintainable.
- Persist user state and work independently of the container writable layer.
- Separate provisioning from execution: hooks prepare the environment, while `CMD` starts the application.
- Keep system hooks and user hooks distinct in identity and behavior.
- Prefer user-level installation under `/home/space` and runtime management through mise.
- Do not bundle a specific IDE, language runtime, or AI agent into the base image.
- Treat the container-to-host boundary as the primary security boundary.

## Runtime model

The image defines a `space` user and three persistence boundaries:

```text
/home/space        User tools, runtimes, configuration, and application data
/workspace         Source code and other work products
/entrypoint.d/user Persistent user provisioning hooks
```

Container startup follows this sequence:

```text
tini
  └─ entrypoint using the configured startup identity
       ├─ system hooks using the startup identity
       ├─ user hooks as space by default
       └─ final command as space by default
```

The user switch can be disabled when the caller needs to preserve an explicitly configured container user. See the [base image documentation](base/README.md) for the exact contract.

## Quick start

The build has two stages: build Base first, then pass its exact image reference to both derived images:

```bash
SPACE_VERSION=1.0.0
BASE_IMAGE="ghcr.io/lipangeng/space-base:${SPACE_VERSION}"
docker build -t "${BASE_IMAGE}" ./base
docker build \
  --build-arg SPACE_BASE_IMAGE="${BASE_IMAGE}" \
  -t "ghcr.io/lipangeng/manual-space:${SPACE_VERSION}" ./manual
docker build \
  --build-arg SPACE_BASE_IMAGE="${BASE_IMAGE}" \
  -t "ghcr.io/lipangeng/agent-space:${SPACE_VERSION}" ./agent
```

In GitHub Actions, Docker Metadata Action should generate the standard names and tags for each image. After the first stage publishes Base, pass its digest reference to the second stage as `SPACE_BASE_IMAGE`; the derived Dockerfiles do not guess or default to any tag.

## Release flow

[`publish-images.yml`](.github/workflows/publish-images.yml) publishes `main` and `sha-*` images whenever `main` changes. Pushing a `v*` SemVer tag publishes the corresponding version, major/minor aliases, `latest`, and `sha-*` images. Version tags and GitHub Releases are created manually; no automatic release manager is required.

The workflow always publishes Base first and then builds both derived images in parallel from its digest. It can also be started manually for the selected branch or tag.

Start an interactive persistent workspace:

```bash
docker run --rm -it \
  -v space-home:/home/space \
  -v "$(pwd)":/workspace \
  -v space-user-hooks:/entrypoint.d/user \
  ghcr.io/lipangeng/manual-space:1.0.0
```

The default command is `bash`. Supply a different command through Docker, Compose, or Kubernetes to start an IDE, terminal, notebook, agent, or other long-running process.

## Extending a Space

Use the following ownership model:

```text
Language runtimes and compatible CLIs  mise
User applications and executables      /home/space/.local
Project data and project mise config   /workspace
Persistent system provisioning         /entrypoint.d/user with explicit sudo
Application startup                    CMD / command / args
```

This keeps the image replaceable: recreate a container with a newer image and remount the three persistent paths to restore the user environment and workspace.

## Security

The `space` user has passwordless sudo because Spaces is designed as a personal isolated workspace. Do not expose host-level authority unless explicitly required. In particular, avoid privileged containers, host PID mode, broad host filesystem mounts, unnecessary capabilities, and mounting a host Docker socket without understanding the consequences.

## Repository layout

```text
.
├── README.md
├── README.zh-CN.md
├── .github/
│   └── workflows/
│       └── publish-images.yml
├── agent/
│   ├── Dockerfile
│   ├── README.md
│   └── README.zh-CN.md
├── base/
│   ├── Dockerfile
│   ├── README.md
│   ├── README.zh-CN.md
│   └── rootfs/
└── manual/
    ├── Dockerfile
    ├── README.md
    └── README.zh-CN.md
```

For package inventory, build arguments, hook semantics, environment switches, and detailed examples, see [`base/README.md`](base/README.md).
