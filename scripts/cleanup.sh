#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# OpenShell Claude Code - Cleanup Script
#
# This script removes all OpenShell Claude Code containers and volumes.
# WARNING: This will delete all sandboxes and data!
#
# Usage:
#   bash scripts/cleanup.sh [--confirm]

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
CONFIRM=0

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        --confirm)
            CONFIRM=1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo
log_warn "OpenShell Claude Code Cleanup"
echo
log_error "WARNING: This will delete:"
echo "  - OpenShell Gateway container"
echo "  - All sandbox containers"
echo "  - All volumes (/var/lib/openshell)"
echo "  - Keycloak container (if running)"
echo "  - Claude Code image"
echo
log_warn "This action is IRREVERSIBLE. All data will be lost."
echo

if [ $CONFIRM -eq 0 ]; then
    read -p "Type 'yes' to confirm: " response
    if [ "$response" != "yes" ]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
fi

echo

# Stop Podman Compose services
log_info "Stopping OpenShell Gateway..."
cd "$CONTAINER_DIR"
if podman compose ps | grep -q gateway; then
    if podman compose down; then
        log_success "Gateway stopped"
    else
        log_warn "Failed to stop gateway"
    fi
fi
cd "$SCRIPT_DIR"

echo

# Remove Keycloak
log_info "Removing Keycloak container..."
if podman ps -a | grep -q keycloak; then
    if podman rm -f keycloak; then
        log_success "Keycloak removed"
    else
        log_warn "Failed to remove Keycloak"
    fi
fi

echo

# Remove sandboxes
log_info "Removing OpenShell sandboxes..."
if openshell sandbox list &> /dev/null; then
    sandboxes=$(openshell sandbox list | tail -n +2 | awk '{print $1}')
    for sandbox in $sandboxes; do
        if openshell sandbox delete "$sandbox" &> /dev/null; then
            log_success "Deleted sandbox: $sandbox"
        else
            log_warn "Failed to delete sandbox: $sandbox"
        fi
    done
fi

echo

# Remove volumes
log_info "Removing OpenShell data directory..."
if sudo rm -rf /var/lib/openshell; then
    log_success "Removed /var/lib/openshell"
else
    log_warn "Failed to remove /var/lib/openshell (may require sudo)"
fi

echo

# Remove images
log_info "Removing Claude Code image..."
if podman rmi -f openshell-claude-code:latest 2> /dev/null; then
    log_success "Removed openshell-claude-code:latest"
else
    log_warn "Claude Code image not found"
fi

echo

log_success "Cleanup complete!"
echo
log_info "To rebuild and restart:"
echo "  bash scripts/setup.sh"
