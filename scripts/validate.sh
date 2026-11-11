#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# OpenShell Claude Code - Configuration Validation
#
# This script validates your OpenShell configuration.
#
# Usage:
#   bash scripts/validate.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_DIR="$SCRIPT_DIR/docker"

echo
log_info "OpenShell Claude Code Configuration Validation"
echo

# Test 1: Check prerequisites
log_info "Checking prerequisites..."
local_missing=0

for cmd in podman curl git openshell; do
    if command -v "$cmd" &> /dev/null; then
        version=$("$cmd" --version 2>&1 | head -1)
        log_success "$cmd: $version"
    else
        log_error "$cmd not found"
        local_missing=1
    fi
done

if [ $local_missing -eq 1 ]; then
    echo
    log_error "Missing required tools"
    exit 1
fi

if podman compose version &> /dev/null; then
    log_success "Podman Compose provider is available"
else
    log_error "Podman Compose provider not found (install/configure a provider such as podman-compose)"
    exit 1
fi

echo

# Test 2: Check configuration files
log_info "Checking configuration files..."
local_missing=0

files=(
    "$CONTAINER_DIR/gateway.toml"
    "$CONTAINER_DIR/Dockerfile"
    "$CONTAINER_DIR/docker-compose.yml"
    "$SCRIPT_DIR/policy/base-policy.yaml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        log_success "Found: $file"
    else
        log_warn "Missing: $file"
    fi
done

echo

# Test 3: Check Podman
log_info "Checking Podman..."
if podman ps &> /dev/null; then
    log_success "Podman is running"
else
    log_error "Podman is not running or not accessible"
    exit 1
fi

echo

# Test 4: Check Podman socket
log_info "Checking Podman socket..."
if [ -S /run/podman/podman.sock ]; then
    log_success "Podman socket found at /run/podman/podman.sock"
elif [ -S /run/user/$(id -u)/podman/podman.sock ]; then
    log_success "Podman socket found at /run/user/$(id -u)/podman/podman.sock"
else
    log_warn "Podman socket not found (Podman may not be running)"
fi

echo

# Test 5: Check if gateway is running
log_info "Checking if OpenShell Gateway is running..."
if curl -s http://localhost:8080/healthz &> /dev/null; then
    log_success "Gateway is running on http://localhost:8080"
    
    # Check readiness
    if curl -s http://localhost:8081/readyz &> /dev/null; then
        log_success "Gateway is ready to serve requests"
    else
        log_warn "Gateway is not ready yet"
    fi
else
    log_warn "Gateway is not running"
    log_info "Start it with: cd $CONTAINER_DIR && podman compose up -d"
fi

echo

# Test 6: Check OpenShell CLI configuration
log_info "Checking OpenShell CLI..."
if openshell gateway list &> /dev/null; then
    count=$(openshell gateway list | wc -l)
    log_success "OpenShell CLI is working ($count gateways configured)"
else
    log_warn "OpenShell CLI not fully configured yet"
fi

echo

# Test 7: Check Claude Code image
log_info "Checking Claude Code image..."
if podman images | grep -q "openshell-claude-code"; then
    log_success "Claude Code image found"
else
    log_warn "Claude Code image not found"
    log_info "Build it with: cd $SCRIPT_DIR && podman build -f docker/Dockerfile -t openshell-claude-code:latest ."
fi

echo

# Summary
log_success "Validation complete!"
echo
log_info "Recommended next steps:"
echo "  1. Configure authentication in docker/gateway.toml"
echo "  2. Restart gateway: cd $CONTAINER_DIR && podman compose restart gateway"
echo "  3. Log in: openshell login"
echo "  4. Create sandbox: openshell sandbox create --name demo --image openshell-claude-code:latest"
