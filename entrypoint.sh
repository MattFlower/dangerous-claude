#!/bin/bash
set -e

# This script runs as root initially to fix UID/GID, then drops privileges

CLAUDE_USER="claude"
CLAUDE_HOME="/home/claude"

# Get the UID/GID of the mounted claude directory
# Check both possible mount points depending on overlay mode
if [ -d "/mnt/claude-data" ]; then
    HOST_UID=$(stat -c "%u" /mnt/claude-data)
    HOST_GID=$(stat -c "%g" /mnt/claude-data)
elif [ -d "/mnt/claude-lower" ]; then
    HOST_UID=$(stat -c "%u" /mnt/claude-lower)
    HOST_GID=$(stat -c "%g" /mnt/claude-lower)
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

# Configure Docker socket access if enabled
if [ "$DOCKER_ENABLED" = "true" ] && [ -S "/var/run/docker.sock" ]; then
    DOCKER_SOCK_GID=$(stat -c "%g" /var/run/docker.sock)
    echo "Configuring Docker access (socket GID: $DOCKER_SOCK_GID)..."

    # Check if a group with this GID already exists
    EXISTING_GROUP=$(getent group "$DOCKER_SOCK_GID" | cut -d: -f1 || true)

    if [ -n "$EXISTING_GROUP" ]; then
        # Use existing group
        echo "Using existing group '$EXISTING_GROUP' for Docker access..."
        usermod -aG "$EXISTING_GROUP" "$CLAUDE_USER"
    else
        # Create or modify docker group to use the socket's GID
        echo "Creating docker group with GID $DOCKER_SOCK_GID..."
        if getent group docker > /dev/null 2>&1; then
            # Group name exists with different GID, modify it
            groupmod -g "$DOCKER_SOCK_GID" docker
        else
            # Group name doesn't exist, create it
            groupadd -g "$DOCKER_SOCK_GID" docker
        fi
        usermod -aG docker "$CLAUDE_USER"
    fi
fi

# Set up ~/.claude symlink (always direct mount - needed for conversation persistence)
if [ -d "/mnt/claude-data" ] && [ ! -L "$CLAUDE_HOME/.claude" ]; then
    rm -rf "$CLAUDE_HOME/.claude" 2>/dev/null || true
    ln -sf /mnt/claude-data "$CLAUDE_HOME/.claude"
    echo "Symlinked: $CLAUDE_HOME/.claude -> /mnt/claude-data"
fi

# Set up ~/.gradle and ~/.m2 based on overlay mode
if [ "$DISABLE_OVERLAY" = "true" ]; then
    # No overlay: directories are mounted directly to their final locations
    echo "Overlay protection disabled for .gradle and .m2"
else
    # Set up overlay filesystems for cache directories
    # This protects host directories from deletion while allowing writes
    setup_overlay() {
        local name="$1"
        local lower="$2"
        local target="$3"

        # Skip if lower directory doesn't exist (not mounted)
        if [ ! -d "$lower" ]; then
            return 0
        fi

        local overlay_base="/tmp/overlay/$name"
        local upper="$overlay_base/upper"
        local work="$overlay_base/work"

        echo "Setting up overlay for $name..."

        # Create overlay directories
        mkdir -p "$upper" "$work" "$target"

        # Mount the overlay
        if mount -t overlay overlay \
            -o "lowerdir=$lower,upperdir=$upper,workdir=$work" \
            "$target"; then
            echo "  Overlay mounted: $target"
            # Fix ownership for claude user
            chown -R "$CLAUDE_USER:$CLAUDE_USER" "$upper" "$target"
        else
            echo "  WARNING: Failed to mount overlay for $name, falling back to symlink"
            rm -rf "$target"
            ln -sf "$lower" "$target"
        fi
    }

    # Set up overlays for cache directories (while still root)
    setup_overlay "gradle" "/mnt/gradle-lower" "/home/claude/.gradle"
    setup_overlay "m2" "/mnt/m2-lower" "/home/claude/.m2"
fi

# Now drop privileges and run the rest as the claude user
exec gosu "$CLAUDE_USER" /bin/bash -c '
set -e

# Set up PATH for npm global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# Source SDKMAN for Java access
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Note: ~/.claude is set up in the root section above (overlay or symlink depending on mode)

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

# Get list of mounted project directories (in user-specified order)
WORKSPACE_DIRS=()
if [ -n "$WORKSPACE_ORDER" ]; then
    # Use order passed from dangerous-claude (colon-separated)
    IFS=: read -ra WORKSPACE_DIRS <<< "$WORKSPACE_ORDER"
else
    # Fallback to glob (alphabetical) if env var not set
    for dir in /workspace/*/; do
        [ -d "$dir" ] && WORKSPACE_DIRS+=("$dir")
    done
fi

# Change to first project directory and add others via --add-dir
# This ensures each project gets its own section in .claude.json,
# avoiding conflicts when running multiple containers simultaneously
if [ ${#WORKSPACE_DIRS[@]} -gt 0 ]; then
    # cd into the first directory (primary project)
    cd "${WORKSPACE_DIRS[0]}"

    # Add remaining directories via --add-dir
    for ((i=1; i<${#WORKSPACE_DIRS[@]}; i++)); do
        CLAUDE_ARGS+=("--add-dir" "${WORKSPACE_DIRS[$i]}")
    done
fi

echo "Starting Claude Code..."
echo "Working directory: $(pwd)"
if [ ${#WORKSPACE_DIRS[@]} -gt 1 ]; then
    echo "Additional directories:"
    for ((i=1; i<${#WORKSPACE_DIRS[@]}; i++)); do
        echo "  ${WORKSPACE_DIRS[$i]}"
    done
fi
echo ""
echo "-------------------------------------------"
echo ""

# Run Claude interactively
exec claude "${CLAUDE_ARGS[@]}"
' -- "$@"
