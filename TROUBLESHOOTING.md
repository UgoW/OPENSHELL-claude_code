# OpenShell Claude Code — Troubleshooting Guide

This guide helps resolve common issues with the OpenShell + Claude Code + Podman configuration.

## Prerequisites Checklist

- [ ] Podman installed and running (`podman --version`; start `podman machine` on macOS)
- [ ] Podman Compose provider available (`podman compose version`)
- [ ] OpenShell CLI installed (`openshell --version`)
- [ ] Network access to the internet (for downloading images and API calls)
- [ ] `/var/lib/openshell` directory is writable (or custom path if configured)

## Gateway Issues

### Gateway fails to start

**Symptom:** `podman compose ... up -d` fails or the container exits immediately.

**Solution:**

1. Check logs:
   ```bash
   podman compose -f docker/docker-compose.yml logs gateway
   ```

2. Verify the Podman socket is accessible:
   ```bash
   # On Linux (rootful)
   ls -la /run/podman/podman.sock
   
   # On Linux (rootless)
   ls -la /run/user/$(id -u)/podman/podman.sock
   
   # On macOS (Podman Machine)
   podman machine info
   ```

3. If the socket doesn't exist, start Podman:
   ```bash
   # Linux
   sudo systemctl start podman.socket
   
   # macOS
   podman machine start
   ```

4. Check if the data directory is writable:
   ```bash
   sudo mkdir -p /var/lib/openshell
   sudo chmod 755 /var/lib/openshell
   ```

### Gateway port already in use

**Symptom:** `Error: bind: address already in use`

**Solution:**

Either kill the existing process or use a different port:

```bash
# Option 1: Kill the process using port 8080
lsof -i :8080 | awk 'NR!=1 {print $2}' | xargs kill -9

# Option 2: Use a different port (in docker/.env)
echo "OPENSHELL_PORT=8090" >> .env
podman compose -f docker/docker-compose.yml up -d
```

### Gateway cannot reach Podman

**Symptom:** Gateway logs contain `Cannot connect to Podman` or socket permission errors.

**Solution:**

1. Verify the socket path in `docker/docker-compose.yml` matches your setup:
   - **Linux (rootful):** `/run/podman/podman.sock`
   - **Linux (rootless):** `/run/user/$(id -u)/podman/podman.sock`
   - **macOS (Podman Machine):** May require special handling; see below

2. On macOS with Podman Machine, the socket path differs:
   ```bash
   # Check the socket location
   podman info | grep sock
   
   # Update docker/docker-compose.yml volumes section:
   volumes:
     - /run/user/1000/podman/podman.sock:/run/podman/podman.sock
   ```

3. Ensure the gateway container can access the Podman socket:
   ```bash
   # Grant access to the Podman socket
   sudo chmod 666 /run/podman/podman.sock
   ```

## Image Building Issues

### Container image fails to build

**Symptom:** `podman build` fails with `ERROR` messages.

**Solution:**

1. Check for syntax errors:
   ```bash
   podman build -f docker/Dockerfile --log-level=debug .
   ```

2. Ensure base image is available:
   ```bash
   podman pull ubuntu:24.04
   ```

3. Check network connectivity (if installing packages):
   ```bash
   podman build --no-cache -f docker/Dockerfile .
   ```

4. Common issues:
   - **`npm install` fails:** Increase Podman Machine memory or run without npm in base image
   - **`pip install` fails:** Use `--no-cache-dir` and retry
   - **User creation fails:** Ensure UID 1000 is available in the base image

## Sandbox Creation Issues

### Sandbox creation fails with "image not found"

**Symptom:** `openshell sandbox create ... --image openshell-claude-code:latest` returns "image not found".

**Solution:**

1. Verify the image was built:
   ```bash
   podman images | grep openshell-claude-code
   ```

2. If not present, build it:
   ```bash
   podman build -f docker/Dockerfile -t openshell-claude-code:latest .
   ```

3. Ensure the image name matches exactly (case-sensitive):
   ```bash
   openshell sandbox create --name claude-demo \
     --image openshell-claude-code:latest
   ```

### Sandbox creation fails with "policy invalid"

**Symptom:** `openshell sandbox create ... --policy examples/claude-code/policy.yaml` returns policy validation errors.

**Solution:**

1. Validate the policy file:
   ```bash
   openshell policy validate examples/claude-code/policy.yaml
   ```

2. Common policy errors:
   - **`network_policies: unknown field`** — Use `endpoints`, not `endpoint`
   - **`enforcement: invalid value`** — Use `enforce` or `log`, not `deny`
   - **`access: invalid value`** — Use `read-only` or `read-write` (with hyphen)

3. Compare with a working example:
   ```bash
   openshell policy validate examples/sandbox-policy-quickstart/policy.yaml
   ```

### Sandbox shows "Ready: false" for too long

**Symptom:** `openshell sandbox watch claude-demo` shows `Ready: false` for 30+ seconds.

**Solution:**

1. Check the supervisor logs:
   ```bash
   podman logs <supervisor_container_id>
   ```

2. Verify the workload is running:
   ```bash
   podman ps | grep openshell
   ```

3. Common causes:
   - **Policy too restrictive:** Supervisor cannot start essential services
   - **Image issue:** The Claude Code image fails to start as `claude` user
   - **Network:** Supervisor cannot reach the gateway

4. Increase logging and try again:
   ```bash
   openshell sandbox delete claude-demo
   # Then check logs during creation:
   RUST_LOG=debug openshell sandbox create ...
   ```

## Network & API Issues

### "Connection refused" when running Claude Code

**Symptom:** Claude Code runs but cannot reach API endpoints (Anthropic, OpenRouter, etc.).

**Solution:**

1. Verify the endpoint is in the policy:
   ```bash
   openshell policy get claude-demo | grep -A 10 network_policies
   ```

2. Check the exact hostname/port:
   - **Anthropic:** `api.anthropic.com:443`
   - **OpenRouter:** `openrouter.ai:443`
   - **PyPI:** `pypi.org:443` and `files.pythonhosted.org:443`

3. Add missing endpoints to the policy:
   ```bash
   # Edit examples/claude-code/policy.yaml, then:
   openshell policy update claude-demo --policy examples/claude-code/policy.yaml
   ```

4. Test DNS resolution:
   ```bash
   openshell sandbox run claude-demo -- nslookup api.anthropic.com
   ```

### Provider credentials not working

**Symptom:** Claude Code can reach the API but authentication fails.

**Solution:**

1. Verify the provider is configured:
   ```bash
   openshell provider list
   ```

2. Recreate the provider with the correct API key:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-YOUR_ACTUAL_KEY \
     openshell provider create --type anthropic --from-existing
   ```

3. Verify the credentials are passed to the sandbox:
   ```bash
   # Check supervisor logs
   podman logs <supervisor_container_id> | grep credential
   ```

4. Ensure the policy allows the binary to make requests:
   ```yaml
   # In policy.yaml
   binaries:
     - path: /usr/bin/python3  # or /usr/bin/curl
   ```

## Cleanup & Recovery

### Remove all containers and start fresh

```bash
# Stop the gateway
podman compose -f docker/docker-compose.yml down

# Remove OpenShell data (WARNING: deletes all sandboxes and credentials)
sudo rm -rf /var/lib/openshell

# Remove images (optional)
podman rmi openshell-claude-code:latest

# Start fresh
podman compose -f docker/docker-compose.yml up -d
```

### Reset the gateway but keep images

```bash
# Stop gateway (keeps data)
podman compose -f docker/docker-compose.yml stop

# Restart
podman compose -f docker/docker-compose.yml start
```

## Performance Tuning

### Slow sandbox creation

**Possible causes:**
- Large image size → cache images locally: `podman pull image-name`
- Network latency → use a registry mirror
- Podman container startup time → use a faster rootfs

**Solutions:**
```bash
# Increase timeouts in gateway config
[openshell.drivers.podman]
stop_timeout_secs = 30  # Increase from default

# Pre-pull images to avoid repeated downloads
podman pull ghcr.io/nvidia/openshell/sandbox:latest
podman pull ghcr.io/nvidia/openshell/supervisor:latest
```

### High memory usage

**Possible causes:**
- Multiple sandboxes running simultaneously
- Large Podman image cache

**Solutions:**
```bash
# Remove unused Podman images
podman image prune

# Reduce the number of concurrent sandboxes
openshell sandbox list | wc -l
openshell sandbox delete <name>  # Remove unused sandboxes
```

## Diagnostics

### Collect debugging information

```bash
# Gateway logs
podman compose -f docker/docker-compose.yml logs gateway > gateway.log

# Podman info
podman info > podman-info.log

# OpenShell diagnostics
openshell gateway info > gateway-info.log
openshell sandbox list > sandbox-list.log

# System info
uname -a > system-info.log
podman --version >> system-info.log
openshell --version >> system-info.log
```

## Getting Help

If issues persist:

1. Check [OpenShell Documentation](https://docs.nvidia.com/openshell)
2. Search [GitHub Issues](https://github.com/NVIDIA/OpenShell/issues)
3. Ask on [GitHub Discussions](https://github.com/NVIDIA/OpenShell/discussions)
4. Review [Podman Driver Documentation](../../crates/openshell-driver-podman/README.md)

Include the diagnostic logs (above) when reporting issues.
