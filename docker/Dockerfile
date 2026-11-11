# syntax=docker/dockerfile:1.4

# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Claude Code sandbox image for OpenShell
#
# This image runs Claude Code (Anthropic's coding agent) inside an OpenShell
# sandbox. The sandbox enforces a security policy that restricts file access,
# network endpoints, and process capabilities.
#
# Build:
#   podman build -f docker/Dockerfile \
#     -t openshell-claude-code:latest .
#
# Or with a specific Claude version/variant:
#   podman build --build-arg CLAUDE_VERSION=1.0.0 \
#     -f docker/Dockerfile -t openshell-claude-code:latest .
#
# Use with OpenShell:
#   openshell sandbox create --name claude-demo \
#     --image openshell-claude-code:latest \
#     --policy examples/claude-code/policy.yaml

FROM ubuntu:24.04

# Build arguments
ARG CLAUDE_VERSION=latest
ARG NODE_VERSION=20

# Set working directory for the agent
WORKDIR /sandbox

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    ca-certificates \
    nodejs npm \
    python3 python3-pip python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for the agent
# OpenShell will use this identity; UID/GID are pinned by the sandbox
RUN groupadd -r claude && useradd -r -g claude -u 1000 -d /sandbox claude

# Install Claude Code
# This installs Claude's CLI/SDK for local usage
# For production, you may want to pin a specific version or use prebuilt binaries
RUN npm install -g @anthropic-ai/claude-cli

# Install common Python packages for Claude Code
# (adapt to your specific needs)
RUN pip3 install --no-cache-dir \
    anthropic \
    requests \
    pydantic

# Create workspace directory with proper permissions
RUN mkdir -p /sandbox && chown claude:claude /sandbox

# Set up the user context
USER claude

# Default entrypoint: Claude Code CLI
# Can be overridden with openshell sandbox run
ENTRYPOINT ["claude"]
CMD ["--help"]
