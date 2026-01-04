#!/bin/bash
set -e

# Set up PATH for npm global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# Source SDKMAN for Java access
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Set up Claude config symlink (like Docker's official sandbox does)
# This ensures credentials from the mounted volume are properly accessible
if [ -d "/mnt/claude-data" ] && [ ! -L "$HOME/.claude" ]; then
    rm -rf "$HOME/.claude" 2>/dev/null || true
    ln -sf /mnt/claude-data "$HOME/.claude"
fi

# Update Claude Code to the latest version
echo "Updating Claude Code to the latest version..."
npm update -g @anthropic-ai/claude-code 2>/dev/null || npm install -g @anthropic-ai/claude-code

# Show version
echo "Claude Code version: $(claude --version)"
echo ""

# If a command was passed (e.g., "bash" or "claude login"), run it directly
if [ $# -gt 0 ]; then
    echo "Running: $@"
    echo "-------------------------------------------"
    echo ""
    exec "$@"
fi

# Default behavior: run Claude with --dangerously-skip-permissions
CLAUDE_ARGS=("--dangerously-skip-permissions")

# Check if we should resume a conversation
if [ -n "$CLAUDE_RESUME" ]; then
    CLAUDE_ARGS+=("--resume" "$CLAUDE_RESUME")
    echo "Resuming conversation: $CLAUDE_RESUME"
fi

# Check if we should continue the most recent conversation
if [ "$CLAUDE_CONTINUE" = "true" ]; then
    CLAUDE_ARGS+=("--continue")
    echo "Continuing most recent conversation..."
fi

echo "Starting Claude Code..."
echo "Working directory: $(pwd)"
echo "Mounted volumes:"
ls -la /workspace/
echo ""
echo "-------------------------------------------"
echo ""

# Run Claude interactively
exec claude "${CLAUDE_ARGS[@]}"
