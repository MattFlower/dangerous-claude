#!/bin/bash
set -e

# This script runs as root initially to fix UID/GID, then drops privileges

CLAUDE_USER="claude"
CLAUDE_HOME="/home/claude"

# Get the UID/GID of the mounted claude-data directory
if [ -d "/mnt/claude-data" ]; then
    HOST_UID=$(stat -c "%u" /mnt/claude-data)
    HOST_GID=$(stat -c "%g" /mnt/claude-data)
else
    # Fallback to current claude user's IDs
    HOST_UID=$(id -u $CLAUDE_USER)
    HOST_GID=$(id -g $CLAUDE_USER)
fi

CURRENT_UID=$(id -u $CLAUDE_USER)
CURRENT_GID=$(id -g $CLAUDE_USER)

# Skip UID/GID adjustment if mounted volume appears as root (UID/GID 0)
# This happens on macOS with Docker Desktop, where file permissions are handled
# transparently and the claude user can already access the files
if [ "$HOST_UID" = "0" ] && [ "$HOST_GID" = "0" ]; then
    echo "Mounted volume owned by root (likely macOS Docker Desktop), skipping UID/GID adjustment..."
else
    # Update claude user's GID if it doesn't match the host
    if [ "$HOST_GID" != "$CURRENT_GID" ]; then
        # Check if target GID is already taken by another group
        EXISTING_GROUP=$(getent group "$HOST_GID" | cut -d: -f1 || true)
        if [ -n "$EXISTING_GROUP" ] && [ "$EXISTING_GROUP" != "$CLAUDE_USER" ]; then
            # Use the existing group instead of creating a new one
            echo "Using existing group $EXISTING_GROUP (GID $HOST_GID) for claude user..."
            usermod -g "$EXISTING_GROUP" "$CLAUDE_USER"
        else
            echo "Adjusting claude group ID from $CURRENT_GID to $HOST_GID..."
            groupmod -g "$HOST_GID" "$CLAUDE_USER"
        fi
    fi

    # Update claude user's UID if it doesn't match the host
    if [ "$HOST_UID" != "$CURRENT_UID" ]; then
        # Check if target UID is already taken by another user
        EXISTING_USER=$(getent passwd "$HOST_UID" | cut -d: -f1 || true)
        if [ -n "$EXISTING_USER" ] && [ "$EXISTING_USER" != "$CLAUDE_USER" ]; then
            # Remove the conflicting user (typically just the default ubuntu user)
            echo "Removing conflicting user $EXISTING_USER (UID $HOST_UID)..."
            userdel "$EXISTING_USER" 2>/dev/null || true
        fi
        echo "Adjusting claude user ID from $CURRENT_UID to $HOST_UID..."
        usermod -u "$HOST_UID" "$CLAUDE_USER"
    fi

    # Fix ownership of claude's home directory if UID/GID changed
    if [ "$HOST_UID" != "$CURRENT_UID" ] || [ "$HOST_GID" != "$CURRENT_GID" ]; then
        echo "Fixing ownership of $CLAUDE_HOME..."
        chown -R "$CLAUDE_USER:$CLAUDE_USER" "$CLAUDE_HOME"
    fi
fi

# Now drop privileges and run the rest as the claude user
exec gosu "$CLAUDE_USER" /bin/bash -c '
set -e

# Set up PATH for npm global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# Source SDKMAN for Java access
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Set up Claude config symlink (like Docker official sandbox does)
# This ensures credentials from the mounted volume are properly accessible
if [ -d "/mnt/claude-data" ] && [ ! -L "$HOME/.claude" ]; then
    rm -rf "$HOME/.claude" 2>/dev/null || true
    ln -sf /mnt/claude-data "$HOME/.claude"
fi

# Copy ~/.claude.json from staging location if present
# Each container gets its own copy to avoid conflicts when running multiple instances
if [ -f "/mnt/claude-config/.claude.json" ]; then
    cp /mnt/claude-config/.claude.json "$HOME/.claude.json"
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
' -- "$@"
