# dangerous-claude

A Docker sandbox for running Claude Code with `--dangerously-skip-permissions` safely isolated from the host system.

## Project Overview

This project wraps Claude Code in a Docker container so users can run it with full autonomy while limiting access to only explicitly mounted directories. Key features:

- Sandboxed execution (Claude only sees mounted directories)
- Shares host's `~/.claude` config for plugins/MCP servers
- Auto-updates Claude Code on each container start
- Supports multiple simultaneous directory mounts
- Conversation persistence via `--continue` and `--resume` flags

## Architecture

```
dangerous-claude (CLI)
    │
    ├── Builds/runs Docker container (dangerous-claude)
    │
    ├── Mounts: source dirs → /workspace/*
    │           ~/.claude → /mnt/claude-data
    │           ~/.gitconfig (read-only)
    │           ~/.gradle (for Java projects)
    │
    └── Passes: ANTHROPIC_API_KEY + env vars listed in env.txt

Dockerfile
    │
    ├── Base: Ubuntu 24.04
    ├── Node.js 20.x LTS
    ├── Claude Code (@anthropic-ai/claude-code)
    ├── SDKMAN (Java ecosystem tools)
    ├── Core tools: git, ripgrep, fd, jq, curl
    └── Optional: packages.apt, sdkman.txt customizations

entrypoint.sh
    │
    ├── Symlinks /mnt/claude-data → ~/.claude
    ├── Updates Claude Code to latest
    └── Runs claude --dangerously-skip-permissions
```

## Key Files

| File | Purpose |
|------|---------|
| `dangerous-claude` | Main CLI entry point (bash script) |
| `Dockerfile` | Docker image definition |
| `entrypoint.sh` | Container initialization script |
| `install.sh` | First-time installation script |
| `packages.apt` | User-customizable apt packages (gitignored) |
| `sdkman.txt` | User-customizable SDKMAN tools (gitignored) |
| `env.txt` | User-customizable env vars to pass (gitignored) |
| `*.example` | Templates for user config files |

## Build & Run

```bash
# Build/rebuild the Docker image
dangerous-claude --build

# Run with directories
dangerous-claude ./repo1 ./repo2

# Continue last conversation
dangerous-claude --continue ./repo

# Resume specific conversation
dangerous-claude --resume <conversation-id> ./repo

# Debug shell access
dangerous-claude --shell

# Authenticate with Claude Max
dangerous-claude --login
```

## Customizing Installed Packages

1. Edit `packages.apt` to add/remove apt packages (one per line)
2. Edit `sdkman.txt` to add/remove SDKMAN tools (format: `tool` or `tool:version`)
3. Rebuild with `dangerous-claude --build`

## Passing Environment Variables

Edit `env.txt` to list environment variable names to pass into the container (one per line). Only variables that are set in your shell will be passed. No rebuild required.

## Code Conventions

- Bash scripts use 2-space indentation
- Config files auto-generated from `.example` templates on first run
- User customizations (packages.apt, sdkman.txt, env.txt) are gitignored
- Volume mounts built as bash arrays and expanded with `"${ARRAY[@]}"`

## Common Development Tasks

**Modifying the Docker image**: Edit `Dockerfile`, then rebuild with `--build`

**Adding new CLI flags**: Edit `dangerous-claude`, add to the case statement in argument parsing

**Changing container startup behavior**: Edit `entrypoint.sh`

**Testing changes**: Run `dangerous-claude --shell` to get a bash shell in the container

## Security Model

- Container runs as non-root `claude` user
- Only explicitly mounted directories are accessible
- Host git config mounted read-only
- Network access allowed (for API calls and package downloads)
- `--dangerously-skip-permissions` only applies inside the sandbox

## Git Worktree Limitation

Git worktrees don't work inside the container because the parent `.git` directory isn't mounted. The CLI detects and warns about this.
