# dangerous-claude

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a sandboxed Docker container with `--dangerously-skip-permissions`.

## Why?

Claude Code's `--dangerously-skip-permissions` flag lets Claude execute commands without confirmation, making it much more autonomous. But running it on your host machine means Claude has access to everything you do.

**dangerous-claude** solves this by running Claude in a Docker container where it can only access the directories you explicitly mount.

## Features

- **Sandboxed execution**: Claude can only access mounted directories
- **Shared config**: Uses your host's `~/.claude` directory, so plugins and MCP servers work seamlessly
- **Auto-updates**: Claude Code updates to the latest version on each container start
- **Multiple repos**: Mount as many source directories as needed
- **Conversation persistence**: Continue or resume previous conversations
- **Development tools included**: Java 21, Gradle, Maven, Node.js 20, ripgrep, fd, jq, git

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- A Claude account (either [Claude Max](https://claude.ai) subscription or [Anthropic API](https://console.anthropic.com/) key)

## Installation

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/MattFlower/dangerous-claude/main/install.sh | bash
```

### Manual Install

```bash
git clone https://github.com/MattFlower/dangerous-claude.git ~/.dangerous-claude
echo 'export PATH="$PATH:$HOME/.dangerous-claude"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc
dangerous-claude build
```

## Usage

### Basic Usage

```bash
# Run with one or more repositories
dangerous-claude ./repo1 ./repo2 ./repo3

# Run with current directory
dangerous-claude

# Continue the most recent conversation
dangerous-claude --continue ./repo

# Resume a specific conversation by ID
dangerous-claude --resume abc123 ./repo
```

### Other Commands

```bash
dangerous-claude build      # Rebuild the Docker image
dangerous-claude shell      # Start a bash shell (for debugging)
dangerous-claude version    # Show version
dangerous-claude help       # Show help
```

## Updating

```bash
cd ~/.dangerous-claude && git pull && ./dangerous-claude build
```

Or re-run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/MattFlower/dangerous-claude/main/install.sh | bash
```

## How It Works

1. **Volume Mounts**: Each directory you specify is mounted at `/workspace/<dirname>`
2. **Shared Config**: Mounts your `~/.claude` and `~/.claude.json` so authentication, plugins, and MCP servers work
3. **Git Integration**: Mounts `~/.gitconfig` so commits appear as you
4. **Auto-Update**: Runs `npm update` on each start to keep Claude Code current

## Configuration

### Environment Variables

These are automatically passed to the container if set:

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API authentication (if not using Claude Max) |
| `ARTIFACTORY_USERNAME` | For corporate artifact repositories |
| `ARTIFACTORY_PASSWORD` | For corporate artifact repositories |
| `ARTIFACTORY_TOKEN` | For corporate artifact repositories |

### Installed Tools

| Tool | Version | Notes |
|------|---------|-------|
| Java | 21 (Temurin) | Via SDKMAN |
| Gradle | Latest | Via SDKMAN |
| Maven | Latest | Via SDKMAN |
| Node.js | 20.x LTS | For Claude Code |
| ripgrep | Latest | Fast code search |
| fd | Latest | Fast file finder |
| jq | Latest | JSON processing |
| git | Latest | Version control |

### Customization

Edit the `Dockerfile` to add tools, then rebuild:

```bash
dangerous-claude build
```

## Git Worktrees

If you mount a git worktree, you'll see a warning that commits won't work. This is because worktrees require access to the parent repository's `.git` directory, which isn't mounted for security reasons.

To make commits, mount the main repository instead of the worktree.

## Security Notes

While this sandbox isolates Claude from most of your system:

- **Mounted directories** are fully accessible (read/write)
- **Network access** is available (for npm, API calls, etc.)
- **~/.claude config** is shared with the host

For maximum security, only mount the specific directories you need.

## Troubleshooting

### "Permission denied" errors
The container runs as a non-root user. Ensure your mounted directories are readable.

### Container won't start
Try rebuilding: `dangerous-claude build`

### Authentication issues
If you're logged in on your host but the container asks for auth, make sure `~/.claude.json` exists and contains `hasCompletedOnboarding: true`.

## License

MIT License - see [LICENSE](LICENSE) for details.
