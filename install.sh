#!/bin/bash
#
# Installer for dangerous-claude
# Usage: curl -fsSL https://raw.githubusercontent.com/MattFlower/dangerous-claude/main/install.sh | bash
#

set -e

# Check for Docker first (before doing anything else)
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is required but not installed."
  echo "Please install Docker first: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker info &>/dev/null; then
  echo "Error: Docker is installed but not running."
  echo "Please start Docker and try again."
  exit 1
fi

INSTALL_DIR="$HOME/.dangerous-claude"
REPO_URL="https://github.com/MattFlower/dangerous-claude.git"

echo "Installing dangerous-claude..."
echo ""

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating existing installation..."
  cd "$INSTALL_DIR"

  # Check current branch (same safety checks as --upgrade)
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [ "$current_branch" != "main" ]; then
    echo ""
    echo "Warning: You are on branch '$current_branch', not 'main'."
    echo ""

    # Check if working directory is dirty
    is_dirty=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
      is_dirty=true
    fi

    if [ "$is_dirty" = true ]; then
      echo "Your working directory has uncommitted changes."
      echo ""
    fi

    # Ask user what to do
    echo "Would you like to switch to the main branch to get the latest updates?"
    if [ "$is_dirty" = true ]; then
      echo "(Your uncommitted changes will be stashed and can be restored later)"
    fi
    echo ""
    printf "Switch to main branch? [y/N] "
    read -r REPLY

    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
      # Stash changes if dirty
      if [ "$is_dirty" = true ]; then
        echo "Stashing uncommitted changes..."
        if ! git stash push -m "dangerous-claude upgrade: auto-stash from $current_branch"; then
          echo "Error: Failed to stash changes"
          exit 1
        fi
        echo "Changes stashed. Use 'git -C $INSTALL_DIR stash pop' to restore them later."
        echo ""
      fi

      # Switch to main
      echo "Switching to main branch..."
      if ! git checkout main; then
        echo "Error: Failed to switch to main branch"
        exit 1
      fi
      echo ""

      # Now pull on main
      echo "Pulling latest changes..."
      git pull
    else
      echo "Staying on '$current_branch' branch."
      echo "Skipping git pull to avoid affecting your branch."
      echo "Note: You may not receive the latest updates."
      echo ""
      # Skip pull entirely - user chose to stay on their branch
    fi
  else
    # Already on main, safe to pull
    echo "Pulling latest changes..."
    git pull
  fi
else
  echo "Cloning repository..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Add to PATH in a shell config file
add_to_path() {
  local rc_file="$1"
  if ! grep -q 'dangerous-claude' "$rc_file" 2>/dev/null; then
    echo "" >> "$rc_file"
    echo '# dangerous-claude' >> "$rc_file"
    echo 'export PATH="$PATH:$HOME/.dangerous-claude"' >> "$rc_file"
    echo "Added to PATH in $rc_file"
  fi
}

# Update .bashrc and .zshrc if they exist, otherwise fall back to .profile
UPDATED=false
if [ -f "$HOME/.bashrc" ]; then
  add_to_path "$HOME/.bashrc"
  UPDATED=true
fi
if [ -f "$HOME/.zshrc" ]; then
  add_to_path "$HOME/.zshrc"
  UPDATED=true
fi
if [ "$UPDATED" = false ]; then
  add_to_path "$HOME/.profile"
fi

# Pull or build Docker image
echo ""
echo "Setting up Docker image..."
"$INSTALL_DIR/dangerous-claude" --init

echo ""
echo "Installation complete!"
echo ""
echo "Open a new terminal, then run: dangerous-claude --help"
