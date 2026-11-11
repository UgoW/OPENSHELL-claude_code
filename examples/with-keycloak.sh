#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Example: Production Setup with Keycloak OIDC
#
# This example sets up OpenShell Claude Code with Keycloak for OIDC authentication.
# Suitable for multi-user production environments.
#
# Prerequisites:
#   - Podman running (start Podman Machine on macOS)
#   - 30 minutes for full setup
#
# Usage:
#   bash examples/with-keycloak.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "OpenShell Claude Code - Production Setup with Keycloak OIDC"
echo

# Step 1: Build image
echo "1. Building Claude Code image..."
podman build -f docker/Dockerfile -t openshell-claude-code:latest . || {
    echo "Build failed. Ensure Podman is running."
    exit 1
}

# Step 2: Start Keycloak
echo
echo "2. Starting Keycloak (OIDC provider)..."
podman run -d \
    --name keycloak \
    -p 8080:8080 \
    -e KEYCLOAK_ADMIN=admin \
    -e KEYCLOAK_ADMIN_PASSWORD=admin \
    quay.io/keycloak/keycloak:latest \
    start-dev

echo "Waiting for Keycloak..."
for i in {1..60}; do
    if curl -s http://localhost:8080/realms/master > /dev/null 2>&1; then
        echo "Keycloak is ready!"
        break
    fi
    sleep 1
done

# Step 3: Configure Keycloak
echo
echo "3. Configuring Keycloak..."
echo "   Manual steps (automated setup coming):"
echo "   1. Open http://localhost:8080/admin/master/console"
echo "   2. Login with admin/admin"
echo "   3. Create Realm 'openshell'"
echo "   4. Create Client 'openshell-gateway'"
echo "   5. Set Redirect URI: http://localhost:8080/oauth2/callback"
echo "   6. Copy Client Secret"
echo
read -p "Press Enter once Keycloak is configured..."

# Step 4: Edit gateway config
echo
echo "4. Editing gateway configuration..."
echo "   Update docker/gateway.toml with Keycloak credentials:"
echo
echo "   [openshell.gateway.oidc]"
echo "   issuer_url = \"http://localhost:8080/realms/openshell\""
echo "   client_id = \"openshell-gateway\""
echo "   client_secret = \"YOUR_CLIENT_SECRET_HERE\""
echo "   redirect_uri = \"http://localhost:8080/oauth2/callback\""
echo
read -p "Press Enter once you've updated gateway.toml..."

# Step 5: Start gateway
echo
echo "5. Starting OpenShell Gateway with OIDC..."
cd docker
podman compose down 2>/dev/null || true
podman compose up -d || {
    echo "Failed to start gateway."
    exit 1
}
cd ..

# Step 6: Register and test
echo
echo "6. Setup complete!"
echo
echo "   Next steps:"
echo "   1. Restart gateway: cd docker && podman compose restart gateway"
echo "   2. Login with OpenShell: openshell login"
echo "   3. Browser will open for OIDC authentication"
echo "   4. Log in with Keycloak user"
echo
echo "   Create sandbox:"
echo "   openshell sandbox create --name claude-prod \\"
echo "     --image openshell-claude-code:latest \\"
echo "     --policy policy/base-policy.yaml"
echo
echo "   Run Claude Code:"
echo "   openshell sandbox run claude-prod -- claude --help"
echo
echo "Keycloak Admin Console: http://localhost:8080/admin"
echo "Username: admin"
echo "Password: admin"
