---
name: chrome-devtools
description: Connect an agent to an external Chrome browser through the built-in Chrome DevTools MCP server. Use for browser inspection, web debugging, network analysis, screenshots, performance traces, or CDP connection setup in agent-space.
---

# Chrome DevTools

`chrome-devtools-mcp` is installed in `agent-space`. Chrome itself is external
to the container, and the image does not configure a particular MCP client.

## Connect

Start Chrome with remote debugging enabled and an isolated browser profile.
Make its CDP endpoint reachable from the container, then configure the current
Agent to launch:

```text
chrome-devtools-mcp --browser-url=http://<chrome-host>:9222
```

Use `--ws-endpoint=<webSocketDebuggerUrl>` instead when the deployment exposes
the browser WebSocket endpoint directly. In a container, `127.0.0.1` refers to
the container itself, not automatically to the host.

The MCP client configuration should invoke the installed
`chrome-devtools-mcp` command directly. Do not use `npx ...@latest`; the image
contains a build-time-pinned version and does not update it at startup.

## Privacy and access

The MCP server can inspect and modify everything available in the connected
browser profile. Use a dedicated profile without unrelated accounts or
sensitive sessions, and avoid exposing the remote debugging endpoint to an
untrusted network.

Consider these upstream options when configuring the MCP client:

```text
--no-usage-statistics
--no-performance-crux
```

Use `chrome-devtools-mcp --help` for the options supported by the installed
version. For connection modes and current behavior, read the
[official configuration guide](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md).
