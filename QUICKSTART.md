# Quick Start — 5 Minutes

Get Claude Code running in OpenShell sandboxes in just 5 minutes.

## Prerequisites (2 min)

Ensure you have:

```bash
podman --version    # Podman (start Podman Machine on macOS)
podman compose version
openshell --version # OpenShell CLI

# All missing? Install them first, then come back
```

## Setup (3 min)

From this directory (`openshell-claude-code-config/`):

```bash
# Run the setup script
bash scripts/setup.sh

# Wait for it to complete... ✓
```

That's it! The script:
- Builds the Claude Code image
- Starts the OpenShell Gateway
- Registers it with your CLI
- Shows next steps

## Run Claude Code (< 1 min)

```bash
# 1. Create a sandbox
openshell sandbox create --name demo \
  --image openshell-claude-code:latest \
  --policy policy/base-policy.yaml

# 2. Run Claude Code
openshell sandbox run demo -- claude --help

# 3. Watch it in action
openshell sandbox watch demo
```

## Done! 🎉

Your Claude Code agent is now running securely in a sandbox!

## What Happened?

1. **docker/Dockerfile** — Built the Claude Code container image with Podman
2. **docker/gateway.toml** — Configured Podman as the compute driver
3. **docker/docker-compose.yml** — Started the Gateway
4. **policy/base-policy.yaml** — Applied security restrictions

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

## Next Steps

### Customize

- **Add API endpoints** — Edit `policy/base-policy.yaml`
- **Change ports** — Edit `docker/.env`
- **Enable authentication** — See [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)

### Production Setup

- **Enable TLS** — See [README.md#switch-to-production-tls](README.md#switch-to-production-tls)
- **Set up Keycloak** — `bash scripts/setup.sh --with-keycloak`
- **Deploy to Kubernetes** — See examples in `examples/` directory

### Troubleshooting

```bash
# Validate setup
bash scripts/validate.sh

# Check status
openshell sandbox list
openshell sandbox watch demo
openshell sandbox logs demo

# Debug
podman compose -f docker/docker-compose.yml logs gateway
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.

## Reset Everything

```bash
# Remove all containers and data
bash scripts/cleanup.sh --confirm

# Start fresh
bash scripts/setup.sh
```

---

**Ready to explore?** See [README.md](README.md) for full documentation.
