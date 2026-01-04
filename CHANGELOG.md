# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/MattFlower/dangerous-claude/releases/tag/v1.0.0
