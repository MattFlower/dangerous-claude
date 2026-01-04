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
  cd "$INSTALL_DIR" && git pull
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

# Build Docker image
echo ""
echo "Building Docker image (this may take a few minutes on first run)..."
"$INSTALL_DIR/dangerous-claude" build

echo ""
echo "Installation complete!"
echo ""
echo "Open a new terminal, then run: dangerous-claude --help"
