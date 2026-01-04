#!/bin/bash
#
# Installer for dangerous-claude
# Usage: curl -fsSL https://raw.githubusercontent.com/MattFlower/dangerous-claude/main/install.sh | bash
#

set -e

INSTALL_DIR="$HOME/.dangerous-claude"
REPO_URL="https://github.com/MattFlower/dangerous-claude.git"

echo "Installing dangerous-claude..."
echo ""

# Check for Docker
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is required but not installed."
  echo "Please install Docker first: https://docs.docker.com/get-docker/"
  exit 1
fi

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating existing installation..."
  cd "$INSTALL_DIR" && git pull
else
  echo "Cloning repository..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Determine shell config file
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  SHELL_RC="$HOME/.profile"
fi

# Add to PATH if not already present
if ! grep -q 'dangerous-claude' "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo '# dangerous-claude' >> "$SHELL_RC"
  echo 'export PATH="$PATH:$HOME/.dangerous-claude"' >> "$SHELL_RC"
  echo "Added to PATH in $SHELL_RC"
fi

# Build Docker image
echo ""
echo "Building Docker image (this may take a few minutes on first run)..."
"$INSTALL_DIR/dangerous-claude" build

echo ""
echo "Installation complete!"
echo ""
echo "To start using dangerous-claude, either:"
echo "  1. Run: source $SHELL_RC"
echo "  2. Open a new terminal"
echo ""
echo "Then run: dangerous-claude --help"
