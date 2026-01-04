# dangerous-claude

![dangerous-claude](dangerous-claude-image.png)

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
- **Customizable tools**: Choose which languages and tools to install (Java, Python, Ruby, Rust, etc.)

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

`ANTHROPIC_API_KEY` is always passed if set (for API authentication).

Additional environment variables can be passed by listing them in `env.txt` (one variable name per line). Only variables that are set in your shell will be passed. For example:

```bash
# ~/.dangerous-claude/env.txt
GITHUB_TOKEN
NPM_TOKEN
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

### Installed Tools

**Always installed** (required for core functionality):

- Node.js 20.x, git, curl, wget, ripgrep, fd, jq

**Default extras** (from example configs):

- Java 21 (Azul Zulu), Gradle, Maven
- vim, nano, python3, build-essential

### Customizing Installed Packages

The Docker image is customizable via config files:

| File | Purpose | Example | Rebuild required? |
|------|---------|---------|-------------------|
| `packages.apt` | apt packages | vim, python3, ruby | Yes |
| `sdkman.txt` | SDKMAN tools | java:21.0.9-zulu, kotlin, scala | Yes |
| `env.txt` | Environment variables to pass | GITHUB_TOKEN, NPM_TOKEN | No |

On first run, these are created from `.example` files. To customize:

```bash
# Edit the config files
nano ~/.dangerous-claude/packages.apt
nano ~/.dangerous-claude/sdkman.txt
nano ~/.dangerous-claude/env.txt

# Rebuild with your changes (only needed for packages.apt and sdkman.txt)
dangerous-claude build
```

**For a minimal image** (no Java/Python/etc):

```bash
# Create empty config files
echo "" > ~/.dangerous-claude/packages.apt
echo "" > ~/.dangerous-claude/sdkman.txt
dangerous-claude build
```

Your customizations are gitignored, so `git pull` won't overwrite them.

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

## Contributing

Contributions are welcome! If you have ideas for improvements or find bugs, please open an issue or submit a pull request on [GitHub](https://github.com/MattFlower/dangerous-claude).

Some areas where help would be appreciated:
- Support for additional development tools and languages
- Improved documentation
- Bug fixes and edge case handling

## License

MIT License - see [LICENSE](LICENSE) for details.
