# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.2] - 2026-01-04

### Fixed

- **macOS Docker Desktop compatibility**: Fixed UID/GID adjustment failing on macOS where mounted volumes appear as root. The container now detects this scenario and skips adjustment since Docker Desktop handles permissions transparently.

## [1.1.1] - 2026-01-04

### Fixed

- **Linux permission errors**: Fixed "EACCES: permission denied" errors on Linux when Claude tries to write to mounted volumes. The container now dynamically adjusts the claude user's UID/GID at runtime to match the host user's ownership, ensuring seamless file access without requiring image rebuilds.

## [1.1.0] - 2026-01-04

### Added

- **`--init` flag**: Smart image acquisition that pulls from ghcr.io unless config files are customized
- Installer now uses `--init` for faster first-time setup

### Changed

- Commands now consistently use `--` prefix (`--build`, `--shell`, `--login`, etc.)
- Installer adds PATH to both `.bashrc` and `.zshrc` if they exist (previously only one)

### Fixed

- Installation no longer forces a local build when pre-built image is available

## [1.0.0] - 2026-01-04

### Added

- **Docker sandboxing**: Run Claude Code in an isolated container with `--dangerously-skip-permissions`
- **Multi-directory mounting**: Mount multiple source directories simultaneously
- **Conversation persistence**: Continue (`--continue`) or resume (`--resume <id>`) previous conversations
- **Customizable packages**: Configure apt packages via `packages.apt` and SDKMAN tools via `sdkman.txt`
- **Configurable environment variables**: Pass custom env vars into the container via `env.txt`
- **Pre-built Docker images**: Pull from GitHub Container Registry for faster installation (builds locally only if customized)
- **Auto-updates**: Claude Code updates to the latest version on each container start
- **Shared configuration**: Uses host's `~/.claude` directory for plugins and MCP servers
- **Git integration**: Mounts `~/.gitconfig` so commits appear as the user
- **Git worktree detection**: Warns when mounting worktrees (commits won't work)
- **Shell mode**: Debug access via `--shell` flag
- **Login support**: Authenticate with Claude Max via `--login` flag
- **One-line installer**: Quick install via curl

### Security

- Container runs as non-root `claude` user
- Only explicitly mounted directories are accessible
- Host git config mounted read-only

[1.1.2]: https://github.com/MattFlower/dangerous-claude/releases/tag/v1.1.2
[1.1.1]: https://github.com/MattFlower/dangerous-claude/releases/tag/v1.1.1
[1.1.0]: https://github.com/MattFlower/dangerous-claude/releases/tag/v1.1.0
[1.0.0]: https://github.com/MattFlower/dangerous-claude/releases/tag/v1.0.0
