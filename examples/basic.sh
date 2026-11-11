#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Example: Basic Setup (Development Mode)
#
# This example sets up OpenShell Claude Code in development mode (no authentication).
# Suitable for learning and local testing.
#
# Warning: Development mode allows unauthenticated access. Do NOT use in production!
#
# Usage:
#   bash examples/basic.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "OpenShell Claude Code - Basic Setup (Development Mode)"
echo

# Step 1: Build image
echo "1. Building Claude Code image..."
podman build -f docker/Dockerfile -t openshell-claude-code:latest . || {
    echo "Build failed. Ensure Podman is running."
    exit 1
}

# Step 2: Start gateway
echo
echo "2. Starting OpenShell Gateway (development mode)..."
cd docker
podman compose down 2>/dev/null || true
podman compose up -d || {
    echo "Failed to start gateway. Check docker-compose.yml and your Podman Compose provider."
    exit 1
}
cd ..

# Wait for gateway
echo "Waiting for gateway to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8080/healthz > /dev/null 2>&1; then
        echo "Gateway is ready!"
        break
    fi
    sleep 1
done

# Step 3: Register with CLI
echo
echo "3. Registering gateway with OpenShell CLI..."
openshell gateway add http://localhost:8080 --name openshell-dev || {
    echo "Failed to register. Ensure openshell CLI is installed."
    exit 1
}

# Step 4: Create sandbox
echo
echo "4. Creating Claude Code sandbox..."
openshell sandbox create \
    --name claude-basic \
    --image openshell-claude-code:latest \
    --policy policy/base-policy.yaml

# Step 5: Run
echo
echo "5. Ready! Run Claude Code with:"
echo "   openshell sandbox run claude-basic -- claude --help"
echo
echo "Monitor the sandbox:"
echo "   openshell sandbox watch claude-basic"
echo
echo "View logs:"
echo "   openshell sandbox logs claude-basic"
