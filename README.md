# OpenShell Claude Code Configuration

Complete, consolidated configuration for running Claude Code (Anthropic's autonomous coding agent) in isolated Podman sandboxes with proper OAuth2/OIDC authentication.

## 📋 What's Included

- **Gateway Configuration** — Podman compute driver setup with OIDC/OAuth2 support
- **Container Image** — Claude Code with all dependencies (non-root, secure)
- **Security Policy** — Filesystem + network restrictions, credential injection
- **Podman Compose** — Local development deployment
- **Automated Scripts** — Setup, validation, cleanup
- **Authentication Guide** — OIDC, OAuth2, Keycloak setup
- **Complete Documentation** — Architecture, troubleshooting, examples

## 🚀 Quick Start (5 minutes)

### Prerequisites

```bash
# Verify you have these installed
podman --version    # Start Podman Machine on macOS
podman compose version
openshell --version # OpenShell CLI
```

### One-Command Setup

```bash
# From this directory:
bash scripts/setup.sh

# Optional: with Keycloak for OIDC
bash scripts/setup.sh --with-keycloak
```

This will:
1. ✅ Build the Claude Code image
2. ✅ Start the OpenShell Gateway
3. ✅ Register the gateway with CLI
4. ✅ Display next steps

### Run Claude Code

```bash
# Authenticate
openshell login  # Opens browser (uses dev mode by default)

# Create a sandbox
openshell sandbox create --name claude-demo \
  --image openshell-claude-code:latest \
  --policy policy/base-policy.yaml

# Run Claude Code
openshell sandbox run claude-demo -- claude --help
```

## 📁 Directory Structure

```
openshell-claude-code-config/
├── docker/                    # Podman deployment files
│   ├── Dockerfile            # Claude Code image
│   ├── docker-compose.yml    # Local dev setup
│   ├── gateway.toml          # Gateway config (with OIDC)
│   └── .env.example          # Environment variables
│
├── auth/                      # Authentication
│   └── AUTHENTICATION.md      # Complete auth guide (OAuth2, OIDC, Keycloak)
│
├── policy/                    # Security policies
│   └── base-policy.yaml      # Filesystem + network rules
│
├── scripts/                   # Automation scripts
│   ├── setup.sh              # Automated setup
│   ├── validate.sh           # Validation checks
│   └── cleanup.sh            # Remove everything
│
├── examples/                  # Example configurations
│   ├── basic.sh              # Minimal setup
│   ├── with-keycloak.sh      # Keycloak integration
│   └── production.sh         # Production deployment
│
└── README.md                  # This file
```

## 🔐 Authentication (Important!)

By default, this setup uses **unauthenticated mode for development**. For production, you need proper OAuth2/OIDC authentication.

### Development Mode (Insecure - Local Only)

```toml
# docker/gateway.toml
[openshell.gateway.auth]
allow_unauthenticated_users = true
```

✅ Good for: Learning, testing, local development  
❌ Bad for: Production, shared systems, sensitive data

### Production Mode (Secure)

Configure OAuth2/OIDC in `docker/gateway.toml`:

```toml
# Option 1: OIDC with Keycloak (recommended)
[openshell.gateway.oidc]
issuer_url = "http://keycloak:8080/realms/openshell"
client_id = "openshell-gateway"
client_secret = "your-secret"

# Option 2: OAuth2 with GitHub
[openshell.gateway.oauth2]
provider = "github"
client_id = "your-client-id"
client_secret = "your-client-secret"

# Disable unauthenticated access
[openshell.gateway.auth]
allow_unauthenticated_users = false
```

See **[auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)** for complete setup guides.

## 📚 Documentation

| Document | Contents |
|----------|----------|
| **This README** | Overview, quick start, directory structure |
| **[auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)** | OAuth2, OIDC, Keycloak setup, best practices |
| **[QUICKSTART.md](QUICKSTART.md)** | Step-by-step 5-minute guide |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | How the three components work together |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Common issues and solutions |

## 🛠️ Automation Scripts

### Setup (First Time)

```bash
bash scripts/setup.sh
# Builds image, starts gateway, registers CLI
# Optional: --with-keycloak for OIDC setup
```

### Validate Configuration

```bash
bash scripts/validate.sh
# Checks prerequisites, files, gateway status
```

### Cleanup (Remove Everything)

```bash
bash scripts/cleanup.sh --confirm
# Removes gateway, sandboxes, volumes, images
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│ OpenShell Gateway (Port 8080)               │
│ - OAuth2/OIDC authentication                │
│ - Policy evaluation                         │
│ - Podman compute driver                     │
└─────────────────────────────────────────────┘
         │ (Creates two linked containers)
         │
    ┌────┴────────────────────────────────┐
    │                                      │
┌───────────────────┐         ┌──────────────────────┐
│ openshell-sandbox │         │ openshell-supervisor │
│ (Claude Code)     │         │ (Policy Enforcer)    │
│ UID: 1000 (claude)│◄────────│ UID: 1000 (claude)   │
│ Network: none     │  UDS    │ Network: host        │
│ Filesystem: LUA   │         │ Enforces policy      │
└───────────────────┘         └──────────────────────┘
         │                              │
         └──────────────────┬───────────┘
                            │
              (Only approved API endpoints)
                            │
                    ┌───────────────┐
                    │ External APIs │
                    │ (Anthropic,   │
                    │  OpenRouter)  │
                    └───────────────┘
```

**Security Layers:**
1. **Gateway Config** — Image pinning, JWT keys
2. **Dockerfile** — Non-root user, available tools
3. **Policy + Kernel** — Landlock, seccomp enforcement

## 🎯 Common Tasks

### Enable Keycloak for OIDC

```bash
# Automatic setup
bash scripts/setup.sh --with-keycloak

# Manual setup
podman run -d -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest start-dev

# Configure in gateway.toml and restart
```

See [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md#keycloak-oidc) for details.

### Add New API Endpoint

```bash
# Edit policy/base-policy.yaml
# Add to network_policies:
  your_api:
    name: Your API
    endpoints:
      - host: api.example.com
        port: 443
        protocol: rest
        enforcement: enforce
        access: read-write
    binaries:
      - path: /usr/bin/curl

# Update sandbox policy
openshell policy update claude-demo --policy policy/base-policy.yaml
```

### Switch to Production TLS

```bash
# 1. Generate or acquire certificates
# 2. Edit docker/gateway.toml:
[openshell.gateway.tls]
cert_path = "/etc/openshell/tls/cert.pem"
key_path = "/etc/openshell/tls/key.pem"

# 3. Remove disable_tls = true

# 4. Mount certs in docker-compose.yml:
volumes:
  - /path/to/cert.pem:/etc/openshell/tls/cert.pem:ro
  - /path/to/key.pem:/etc/openshell/tls/key.pem:ro

# 5. Restart gateway
cd docker && podman compose restart gateway
```

### Monitor Sandboxes

```bash
# List all sandboxes
openshell sandbox list

# Watch a sandbox (real-time)
openshell sandbox watch claude-demo

# Get current policy
openshell policy get claude-demo

# View logs
openshell sandbox logs claude-demo
openshell sandbox logs claude-demo --follow
```

## 🔧 Customization

### Change Gateway Port

Edit `docker/.env`:
```bash
OPENSHELL_PORT=8090  # Change from 8080 to 8090
```

### Use Different AI Provider

Edit `policy/base-policy.yaml`, add network policy for your provider:
- OpenRouter → `openrouter.ai:443`
- Hugging Face → `huggingface.co:443`
- Custom API → Your endpoint

### Run with GPU Support

See [ARCHITECTURE.md](ARCHITECTURE.md#gpu-support) for GPU passthrough setup.

## 📊 Status Check

```bash
# Validate everything is working
bash scripts/validate.sh

# Expected output:
# ✓ podman found
# ✓ podman found
# ✓ openshell found
# ✓ Podman is running
# ✓ Podman socket found
# ✓ Gateway is running on http://localhost:8080
# ✓ Gateway is ready to serve requests
# ✓ Claude Code image found
```

## 🐛 Troubleshooting

### Gateway won't start

```bash
cd docker
podman compose logs gateway  # Check logs
podman compose ps            # Check container status
curl http://localhost:8080/healthz  # Health check
```

### API calls denied

```bash
# Check current policy
openshell policy get claude-demo

# Add missing endpoint to policy/base-policy.yaml
# Update sandbox
openshell policy update claude-demo --policy policy/base-policy.yaml
```

### Keycloak not reachable

```bash
# Verify Keycloak is running
podman ps | grep keycloak

# Test connectivity
curl http://localhost:8080/realms/openshell/.well-known/openid-configuration
```

See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for more solutions.

## 📖 Learning Path

1. **Start here:** `README.md` (you are here)
2. **Quick setup:** `bash scripts/setup.sh`
3. **Understand:** [ARCHITECTURE.md](ARCHITECTURE.md)
4. **Configure auth:** [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)
5. **Advanced:** `examples/` directory

## 🔒 Security Best Practices

✅ **Use OIDC in production** — Never expose raw API tokens  
✅ **Enable TLS** — Encrypt all network traffic  
✅ **Restrict policies** — Start with read-only, add access as needed  
✅ **Monitor logs** — Audit who accessed what  
✅ **Rotate credentials** — Change secrets regularly  
✅ **Use namespaces** — Isolate per-user or per-team  

## 🆘 Support

- 📚 [OpenShell Documentation](https://docs.nvidia.com/openshell)
- 🐙 [GitHub Issues](https://github.com/NVIDIA/OpenShell/issues)
- 💬 [GitHub Discussions](https://github.com/NVIDIA/OpenShell/discussions)

## 📝 License

SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
SPDX-License-Identifier: Apache-2.0

---

**Status:** ✅ Production Ready  
**Version:** 1.0  
**Last Updated:** November 2026  
**OpenShell Min Version:** 0.1.0
