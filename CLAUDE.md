# dangerous-claude

A Docker sandbox for running Claude Code with `--dangerously-skip-permissions` safely isolated from the host system.

## Project Overview

This project wraps Claude Code in a Docker container so users can run it with full autonomy while limiting access to only explicitly mounted directories. Key features:

- Sandboxed execution (Claude only sees mounted directories)
- Shares host's `~/.claude` config for plugins/MCP servers
- Auto-updates Claude Code on each container start
- Supports multiple simultaneous directory mounts
- Conversation persistence via `--continue` and `--resume` flags
- Optional Docker access via `--docker` flag

## Architecture

```
dangerous-claude (CLI)
    │
    ├── Pulls pre-built image from ghcr.io (or builds locally if customized)
    │
    ├── Syncs: macOS Keychain OAuth credentials → ~/.claude/.credentials.json
    │
    ├── Mounts: source dirs → /workspace/*
    │           ~/.claude → /mnt/claude-data
    │           ~/.gitconfig (read-only)
    │           ~/.gradle (for Gradle projects)
    │           ~/.m2 (for Maven projects)
    │           /var/run/docker.sock (with --docker flag)
    │
    └── Passes: ANTHROPIC_API_KEY + env vars listed in env.txt

Dockerfile
    │
    ├── Base: Ubuntu 24.04
    ├── Node.js 20.x LTS
    ├── Claude Code (@anthropic-ai/claude-code)
    ├── Docker CLI, Buildx, Compose (for --docker flag)
    ├── SDKMAN (Java ecosystem tools)
    ├── Core tools: git, ripgrep, fd, jq, curl
    └── Optional: packages.apt, sdkman.txt customizations

entrypoint.sh
    │
    ├── Symlinks /mnt/claude-data → ~/.claude
    ├── Configures Docker socket permissions (if enabled)
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
| `.github/workflows/docker-publish.yml` | GitHub Actions workflow to build/push image |

## Docker Image

The Docker image is hosted on GitHub Container Registry at `ghcr.io/mattflower/dangerous-claude:latest`.

**Image acquisition logic:**
- If `packages.apt` or `sdkman.txt` differ from their `.example` files → build locally
- Otherwise → pull pre-built image from ghcr.io
- Use `--build` to force a local build
- Use `--init` to pull or build as appropriate (used by installer)

The GitHub Actions workflow automatically rebuilds and pushes the image when Dockerfile, entrypoint.sh, or example files change.

## Build & Run

```bash
# Force rebuild the Docker image locally
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

# Enable Docker access inside the container
dangerous-claude --docker ./repo
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

## Docker Access (--docker flag)

The `--docker` flag enables Docker commands inside the container by mounting the host's Docker socket. This allows Claude to build images, run containers, and use docker-compose.

**How it works:**
- Mounts `/var/run/docker.sock` from host into the container
- Entrypoint detects the socket's GID and adds the `claude` user to a matching group
- Docker CLI, Buildx, and Compose plugins are pre-installed in the image

**Security considerations:**
- Docker socket access is powerful - containers can access the host's Docker daemon
- Use this flag only when Docker functionality is actually needed
- Containers started from within dangerous-claude run on the host, not nested

**Usage:**
```bash
dangerous-claude --docker ./my-project
```

## macOS Keychain Credential Sync

On macOS, Claude Code stores OAuth credentials in the system Keychain rather than in `~/.claude/.credentials.json`. Since Docker containers cannot access the host's Keychain, dangerous-claude syncs credentials before each run:

- **Requires jq**: Install with `brew install jq` for credential syncing to work
- **One-time seed**: Only syncs from Keychain if credentials file doesn't exist or contains invalid JSON
- **Preserves container tokens**: Once a valid credentials file exists, it is NEVER overwritten from Keychain (since containers can refresh tokens but can't update Keychain)
- **Expiration warnings**: Warns if the OAuth token appears to be expired
- **Symlink protection**: Refuses to write if credentials file is a symlink
- **Atomic writes**: Uses temp file + mv with file locking to prevent race conditions

## Git Worktree Limitation

Git worktrees don't work inside the container because the parent `.git` directory isn't mounted. The CLI detects and warns about this.
