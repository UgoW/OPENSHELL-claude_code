#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# OpenShell Claude Code Configuration - Automated Setup
#
# This script automates the complete setup of OpenShell with Claude Code and Podman.
#
# Usage:
#   bash scripts/setup.sh [--with-keycloak] [--with-k8s] [--production]
#
# Options:
#   --with-keycloak    Set up Keycloak for OIDC (recommended for production)
#   --with-k8s         Set up Kubernetes deployment (requires k3d or kind)
#   --production       Configure for production (TLS, strict auth, etc.)
#   --help             Show this help message

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_DIR="$SCRIPT_DIR/docker"
AUTH_DIR="$SCRIPT_DIR/auth"
POLICY_DIR="$SCRIPT_DIR/policy"

# Defaults
WITH_KEYCLOAK=0
WITH_K8S=0
PRODUCTION=0

# Helper functions
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        --with-keycloak)
            WITH_KEYCLOAK=1
            shift
            ;;
        --with-k8s)
            WITH_K8S=1
            shift
            ;;
        --production)
            PRODUCTION=1
            shift
            ;;
        --help)
            grep "^#" "$0" | head -n 20 | tail -n +3 | cut -c 3-
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=0
    
    for cmd in podman curl git; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd not found"
            missing=1
        else
            log_success "$cmd found"
        fi
    done

    if command -v podman &> /dev/null; then
        if podman compose version &> /dev/null; then
            log_success "Podman Compose provider is available"
        else
            log_error "Podman Compose provider not found (install/configure a provider such as podman-compose)"
            missing=1
        fi
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Some prerequisites are missing"
        return 1
    fi
    
    return 0
}

# Create environment file
setup_environment() {
    log_info "Setting up environment..."
    
    if [ -f "$CONTAINER_DIR/.env" ]; then
        log_warn "$CONTAINER_DIR/.env already exists, skipping"
        return 0
    fi
    
    cp "$CONTAINER_DIR/.env.example" "$CONTAINER_DIR/.env"
    log_success "Created $CONTAINER_DIR/.env"
    
    # Customize for production if requested
    if [ $PRODUCTION -eq 1 ]; then
        # Disable TLS by default (requires manual cert setup)
        # Users should set up TLS themselves
        log_info "For production TLS, see auth/AUTHENTICATION.md"
    fi
}

# Build Claude Code image
build_image() {
    log_info "Building Claude Code image..."
    
    if podman images | grep -q "openshell-claude-code"; then
        log_warn "Image already exists, skipping build"
        return 0
    fi
    
    if podman build -f "$CONTAINER_DIR/Dockerfile" \
        -t openshell-claude-code:latest "$SCRIPT_DIR"; then
        log_success "Built openshell-claude-code:latest"
        return 0
    else
        log_error "Failed to build image"
        return 1
    fi
}

# Start Keycloak (optional)
setup_keycloak() {
    if [ $WITH_KEYCLOAK -eq 0 ]; then
        return 0
    fi
    
    log_info "Setting up Keycloak..."
    
    if podman ps | grep -q keycloak; then
        log_warn "Keycloak already running, skipping"
        return 0
    fi
    
    podman run -d \
        --name keycloak \
        -p 8080:8080 \
        -e KEYCLOAK_ADMIN=admin \
        -e KEYCLOAK_ADMIN_PASSWORD=admin \
        quay.io/keycloak/keycloak:latest \
        start-dev
    
    log_success "Keycloak started (http://localhost:8080)"
    log_info "Admin credentials: admin / admin"
    log_info "For setup instructions, see auth/AUTHENTICATION.md"
}

# Start OpenShell Gateway
start_gateway() {
    log_info "Starting OpenShell Gateway..."
    
    cd "$CONTAINER_DIR"
    
    if podman compose ps | grep -q gateway; then
        log_warn "Gateway already running, skipping"
        cd "$SCRIPT_DIR"
        return 0
    fi
    
    if podman compose -f docker-compose.yml up -d; then
        log_success "Gateway started"
        cd "$SCRIPT_DIR"
        
        # Wait for readiness
        log_info "Waiting for gateway to be ready..."
        local retries=30
        while [ $retries -gt 0 ]; do
            if curl -s http://localhost:8080/healthz > /dev/null 2>&1; then
                log_success "Gateway is ready on http://localhost:8080"
                return 0
            fi
            retries=$((retries - 1))
            sleep 1
        done
        
        log_error "Gateway did not become ready"
        return 1
    else
        log_error "Failed to start gateway"
        cd "$SCRIPT_DIR"
        return 1
    fi
}

# Register gateway with CLI
register_gateway() {
    log_info "Registering gateway with OpenShell CLI..."
    
    if openshell gateway list 2>/dev/null | grep -q "openshell-local"; then
        log_warn "Gateway already registered, skipping"
        return 0
    fi
    
    if openshell gateway add http://localhost:8080 --name openshell-local; then
        log_success "Gateway registered as 'openshell-local'"
        return 0
    else
        log_error "Failed to register gateway"
        log_info "Try manually: openshell gateway add http://localhost:8080 --name openshell-local"
        return 1
    fi
}

# Copy policy file
setup_policy() {
    log_info "Setting up policy..."
    
    if [ ! -f "$POLICY_DIR/base-policy.yaml" ]; then
        log_warn "Policy not found at $POLICY_DIR/base-policy.yaml"
        log_info "Copy from examples/claude-code/policy.yaml if needed"
        return 0
    fi
    
    log_success "Policy ready at $POLICY_DIR/base-policy.yaml"
    return 0
}

# Display next steps
show_next_steps() {
    echo
    log_success "Setup complete!"
    echo
    log_info "Next steps:"
    echo
    echo "1. Configure authentication:"
    echo "   - Edit: $CONTAINER_DIR/gateway.toml"
    echo "   - Follow: $AUTH_DIR/AUTHENTICATION.md"
    echo
    echo "2. Restart gateway with auth config:"
    echo "   cd $CONTAINER_DIR"
    echo "   podman compose restart gateway"
    echo
    echo "3. Log in to gateway:"
    echo "   openshell login  # Opens browser for authentication"
    echo
    echo "4. Create a sandbox:"
    echo "   openshell sandbox create --name claude-demo \\"
    echo "     --image openshell-claude-code:latest \\"
    echo "     --policy $POLICY_DIR/base-policy.yaml"
    echo
    echo "5. Run Claude Code:"
    echo "   openshell sandbox run claude-demo -- claude --help"
    echo
    
    if [ $WITH_KEYCLOAK -eq 1 ]; then
        echo "Keycloak is running at: http://localhost:8080"
        echo "Admin console: http://localhost:8080/admin/master/console"
        echo "Credentials: admin / admin"
        echo
    fi
    
    log_info "For more information, see:"
    echo "   - README.md — Overview"
    echo "   - QUICKSTART.md — 5-minute setup"
    echo "   - $AUTH_DIR/AUTHENTICATION.md — Authentication guide"
}

# Main execution
main() {
    echo
    log_info "OpenShell Claude Code Setup"
    echo
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo
    
    if ! setup_environment; then
        exit 1
    fi
    
    if ! build_image; then
        exit 1
    fi
    
    echo
    
    setup_keycloak || {
        log_warn "Keycloak setup failed (continuing without it)"
    }
    
    echo
    
    if ! start_gateway; then
        exit 1
    fi
    
    echo
    
    if ! register_gateway; then
        log_warn "Gateway registration failed (you can do it manually)"
    fi
    
    echo
    
    setup_policy || {
        log_warn "Policy setup incomplete"
    }
    
    show_next_steps
}

# Run main
main "$@"
