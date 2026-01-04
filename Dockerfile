FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    vim \
    nano \
    ripgrep \
    fd-find \
    jq \
    tree \
    htop \
    ca-certificates \
    gnupg \
    build-essential \
    python3 \
    python3-pip \
    # For sdkman
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create symlink for fd (Ubuntu names it fdfind)
RUN ln -s $(which fdfind) /usr/local/bin/fd

# Install Node.js 20.x (LTS)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for better security practices
# Note: Do NOT create /home/claude/.claude here - it will be symlinked at runtime
RUN useradd -m -s /bin/bash claude && \
    mkdir -p /home/claude/.npm-global && \
    mkdir -p /workspace && \
    mkdir -p /mnt/claude-data && \
    chown -R claude:claude /home/claude /workspace /mnt/claude-data

# Switch to claude user
USER claude
WORKDIR /home/claude

# Configure npm to use user directory for global packages
ENV NPM_CONFIG_PREFIX=/home/claude/.npm-global
ENV PATH="/home/claude/.npm-global/bin:$PATH"

# Install Claude Code in user space
RUN npm install -g @anthropic-ai/claude-code

# Install SDKMAN
RUN curl -s "https://get.sdkman.io" | bash

# Install Java via SDKMAN (using bash -l to load sdkman)
RUN bash -c "source /home/claude/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.2-tem"

# Install Gradle via SDKMAN
RUN bash -c "source /home/claude/.sdkman/bin/sdkman-init.sh && sdk install gradle"

# Install Maven via SDKMAN
RUN bash -c "source /home/claude/.sdkman/bin/sdkman-init.sh && sdk install maven"

# Add sdkman and npm path to bashrc for interactive shells
RUN echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> /home/claude/.bashrc && \
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/claude/.bashrc

# Set working directory
WORKDIR /workspace

# Copy entrypoint script
COPY --chown=claude:claude entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

# Environment variables
ENV HOME=/home/claude
ENV SDKMAN_DIR=/home/claude/.sdkman

# The entrypoint will handle updating and starting Claude
ENTRYPOINT ["/home/claude/entrypoint.sh"]
