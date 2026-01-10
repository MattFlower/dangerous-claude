FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages (required for core functionality)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    ripgrep \
    fd-find \
    jq \
    ca-certificates \
    gnupg \
    bash \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for --docker flag support)
# Only the CLI is needed - it will communicate with host's Docker daemon via mounted socket
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Create symlink for fd (Ubuntu names it fdfind)
RUN ln -s $(which fdfind) /usr/local/bin/fd

# Copy optional apt packages config and install if present
COPY packages.apt /tmp/packages.apt
RUN if [ -s /tmp/packages.apt ]; then \
        apt-get update && \
        grep -v '^#' /tmp/packages.apt | grep -v '^$' | xargs -r apt-get install -y && \
        rm -rf /var/lib/apt/lists/*; \
    fi && rm -f /tmp/packages.apt

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
    mkdir -p /mnt/gradle-lower && \
    mkdir -p /mnt/m2-lower && \
    chown -R claude:claude /home/claude /workspace

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

# Copy SDKMAN packages config and install
COPY --chown=claude:claude sdkman.txt /tmp/sdkman.txt
RUN if [ -s /tmp/sdkman.txt ]; then \
        bash -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && \
        grep -v "^#" /tmp/sdkman.txt | grep -v "^$" | while read -r tool; do \
            if echo "$tool" | grep -q ":"; then \
                name=$(echo "$tool" | cut -d: -f1); \
                version=$(echo "$tool" | cut -d: -f2); \
                sdk install "$name" "$version"; \
            else \
                sdk install "$tool"; \
            fi; \
        done'; \
    fi && rm -f /tmp/sdkman.txt

# Add sdkman and npm path to bashrc for interactive shells
RUN echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> /home/claude/.bashrc && \
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/claude/.bashrc

# Set working directory
WORKDIR /workspace

# Switch to root to copy entrypoint script
USER root

# Copy entrypoint script (owned by root since it needs to run as root initially)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables
ENV HOME=/home/claude
ENV SDKMAN_DIR=/home/claude/.sdkman

# The entrypoint will handle UID/GID mapping, updating, and starting Claude
ENTRYPOINT ["/entrypoint.sh"]
