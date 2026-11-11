# Architecture: How It Works

This document explains the architecture of OpenShell Claude Code configuration and how the three components (Gateway Config, container build file, Policy) work together.

## The Three Core Components

### 1. Gateway Configuration (`docker/gateway.toml`)

**Purpose:** Configure the OpenShell control plane

**What it does:**
- Specifies Podman as the compute driver
- Configures image references (sandbox, supervisor)
- Sets up authentication (OIDC, OAuth2, or development mode)
- Defines JWT keys for Gateway ↔ Supervisor communication
- Sets network bindings and health checks

**Key insight:** This is where you choose authentication method (OIDC, OAuth2, or unauthenticated).

---

### 2. Container Image (`docker/Dockerfile`)

**Purpose:** Build a container image with Podman, Claude Code, and all dependencies

**What it does:**
- Starts with Ubuntu 24.04 base
- Installs system packages (Node.js, Python, build tools)
- Installs Claude Code CLI
- Creates non-root user `claude` (UID 1000) — security requirement
- Sets working directory to `/sandbox` (managed by OpenShell)

**Why non-root?** Security. Rootless processes can't escape the sandbox.

**Why `/sandbox`?** OpenShell manages this volume—it's persistent, isolated, and revoked on sandbox deletion.

---

### 3. Security Policy (`policy/base-policy.yaml`)

**Purpose:** Define runtime restrictions for Claude Code

**What it controls:**
- **Filesystem:** Which paths can be read/written (via Landlock kernel interface)
- **Network:** Which API endpoints are allowed (via supervisor proxy)
- **Process:** User identity, no extra capabilities, seccomp enforcement
- **Credentials:** Which binary can use which credentials

**How enforcement works:**
```
Claude Code tries to:
  ├─ Access /etc/passwd?
  │   ├─ Landlock checks: "Is /etc in read_only?"
  │   └─ DENIED ✗
  │
  ├─ Access api.anthropic.com:443?
  │   ├─ Seccomp traps network syscall
  │   ├─ Supervisor checks policy
  │   └─ ALLOWED ✓ (injects API credential)
  │
  └─ Run sudo?
      ├─ Seccomp blocks syscalls (no capabilities)
      └─ DENIED ✗
```

---

## Complete Flow

### 1. Setup Phase (One-time)

```
bash scripts/setup.sh
  │
  ├─ podman build Dockerfile
  │   └─ Creates: openshell-claude-code:latest (with Claude Code)
  │
  ├─ podman compose up
  │   ├─ Starts Gateway container
  │   ├─ Gateway reads gateway.toml
  │   └─ Gateway ready on http://localhost:8080
  │
  └─ openshell gateway add ... 
      └─ CLI can now reach the gateway
```

### 2. Sandbox Creation Phase

```
openshell sandbox create --name demo \
  --image openshell-claude-code:latest \
  --policy policy/base-policy.yaml
  │
  └─ Gateway receives request
      │
      ├─ Reads gateway.toml
      │   └─ Uses Podman driver
      │
      ├─ Creates workload container
      │   ├─ Image: openshell-claude-code:latest
      │   ├─ User: claude (UID 1000)
      │   ├─ Network: none (isolated)
      │   ├─ Filesystem: Landlock enforced
      │   ├─ Mounts: /sandbox (working dir), /.openshell/channel (control)
      │   └─ Seccomp: default (blocks unsafe calls)
      │
      ├─ Creates supervisor container
      │   ├─ Image: ghcr.io/nvidia/openshell/supervisor:latest
      │   ├─ Joined: workload's user namespace (for UID mapping)
      │   ├─ Network: host (can make outbound requests)
      │   ├─ Policy: enforces policy/base-policy.yaml
      │   └─ Credentials: stores (encrypted, never exposed)
      │
      └─ Both containers connected via private UDS socket
          └─ /.openshell/channel/control/control.sock (authenticated gRPC)
```

### 3. Runtime Phase

```
openshell sandbox run demo -- claude --help
  │
  ├─ Claude Code process starts in workload container
  │
  ├─ Claude tries: curl https://api.anthropic.com/v1/...
  │   │
  │   ├─ Seccomp: network syscall detected
  │   ├─ Proxy: seccomp redirects to supervisor
  │   │
  │   ├─ Supervisor validates policy:
  │   │   ├─ Endpoint: api.anthropic.com:443? ✓ YES
  │   │   ├─ Binary: /usr/bin/curl? ✓ YES
  │   │   ├─ Access level: read-write? ✓ YES
  │   │   └─ Credential type: anthropic? ✓ YES (if configured)
  │   │
  │   ├─ Supervisor injects credential
  │   │   └─ NEVER exposes credential to Claude Code
  │   │   └─ Only adds to request headers
  │   │
  │   ├─ Supervisor makes request (host network)
  │   │
  │   └─ Returns response to Claude Code
  │
  ├─ Claude tries: cp /etc/passwd /sandbox/copy.txt
  │   │
  │   ├─ Landlock: write to /etc/passwd detected
  │   ├─ Landlock checks: is /etc in read_only? ✓ YES
  │   └─ DENIED ✗ (filesystem protection)
  │
  └─ Claude Code completes, sandbox stops
      ├─ Data in /sandbox persists (user volume)
      ├─ Credentials deleted
      └─ Workload container removed
```

---

## Security Model: Three Layers

### Layer 1: Gateway Configuration

**Controls:** Image pinning, driver selection, authentication

**Example:**
```toml
sandbox_runtime_image = "ghcr.io/nvidia/openshell/sandbox@sha256:abc123..."
                        # ↑ Pinned digest prevents tampering
```

**Breach scenario:** If compromised, attacker could specify a backdoored image
**Mitigation:** Image signing, secure supply chain, regular audits

---

### Layer 2: Container build file (Container Image)

**Controls:** Available binaries, default user, environment

**Example:**
```dockerfile
USER claude  # Non-root user (can't escalate with sudo)
RUN npm install @anthropic-ai/claude-cli
```

**Breach scenario:** Backdoored image could include malware
**Mitigation:** Image scanning, source verification, regular updates

---

### Layer 3: Policy + Kernel

**Controls:** Fine-grained runtime restrictions (Landlock, seccomp)

**Enforcement:**
```yaml
filesystem_policy:
  read_only: [/bin, /usr, /lib]    # System immutable
  read_write: [/sandbox, /tmp]     # Only workspace writable
```

**Breach scenario:** Even if code is malicious, kernel prevents unauthorized access
**Mitigation:** Kernel controls are **mandatory**, can't be disabled

---

## Why Three Layers?

**Defense in depth:** If one layer is compromised, others still protect.

```
Layer 1 (Config) ← Secure image selection
         ↓
Layer 2 (Image) ← Non-root user, available tools
         ↓
Layer 3 (Policy) ← Landlock blocks file access, seccomp blocks syscalls
         ↓
    SAFE SANDBOX ✓
```

**Example scenario:**
- Layer 2 is compromised: malicious binary in image
- Layer 3 still protects: Landlock blocks unauthorized filesystem access
- Result: Malicious code can't escape the sandbox

---

## Credential Isolation

This is critical and different from traditional VMs.

### Traditional Approach (Insecure)

❌ Bad:
```bash
ANTHROPIC_API_KEY=sk-ant-... podman run claude:latest
# ✗ Key visible in env vars
# ✗ Key exposed in `podman inspect`
# ✗ Key logged in container output
# ✗ Key accessible to all processes in container
```

### OpenShell Approach (Secure)

✅ Good:
```
1. User logs in via OIDC → OpenShell gateway
2. Gateway stores credential (encrypted) in database
3. User creates sandbox
4. Supervisor (not agent) stores credential
5. Agent makes API request → seccomp trap
6. Supervisor intercepts → injects credential into request headers
7. Credential NEVER exposed to agent
8. Agent sees: response only (credential not visible)
```

**Result:** Even if agent is compromised, attacker can't steal credentials.

---

## Network Enforcement

Claude Code can't make arbitrary network calls.

```
Claude Code    Seccomp Trap    Supervisor    Policy Check    Network
──────────────────────────────────────────────────────────────────────
curl api.anthropic.com:443
     ↓          ✓ trapped       ✓ routes       ✓ allowed ✓ endpoint approved
                                   ↓                          ↓
                         Check policy:api.anthropic
                         ├─ host: api.anthropic.com? ✓
                         ├─ port: 443? ✓
                         ├─ binary: curl? ✓
                         └─ access: read-write? ✓
                                   ↓
                         Make request + inject credential
                                   ↓
                    curl --header "Authorization: Bearer <token>" ...

curl api.malicious.com:443
     ↓          ✓ trapped       ✓ routes       ✗ DENIED
                                   ↓
                         Check policy: api.malicious not whitelisted
                                   ↓
                              Connection refused
```

---

## Kubernetes Deployment (Advanced)

For multi-tenant production:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openshell-gateway
spec:
  template:
    spec:
      containers:
      - name: gateway
        image: ghcr.io/nvidia/openshell/gateway:latest
        volumeMounts:
        - name: config
          mountPath: /etc/openshell/gateway.toml
      volumes:
      - name: config
        configMap:
          name: gateway-config
```

Each user gets their own namespace, with RBAC limiting sandbox creation to their own namespace.

---

## GPU Support (Advanced)

If you need GPU access from Claude Code:

```yaml
# In policy/base-policy.yaml
# Add GPU resource:
gpu:
  device: "/dev/nvidia0"  # Map specific GPU
  
# In docker/docker-compose.yml
# Add GPU runtime:
runtime: nvidia
devices:
  - driver: nvidia
    count: 1
    capabilities: [gpu]
```

---

## Summary

| Component | Purpose | Security Role |
|-----------|---------|----------------|
| **Gateway Config** | Control plane settings | Image pinning, auth |
| **Container build file** | Runtime environment | Non-root user, available tools |
| **Policy** | Per-sandbox restrictions | Landlock (files), seccomp (syscalls), network proxy |

**Together:** A secure, isolated sandbox where Claude Code runs with minimal privileges and maximum auditability.

---

## References

- [Landlock: Kernel-Level Sandboxing](https://www.kernel.org/doc/html/latest/userspace-api/landlock.html)
- [Seccomp: System Call Filtering](https://man7.org/linux/man-pages/man2/seccomp.2.html)
- [OpenShell Documentation](https://docs.nvidia.com/openshell)
- [Podman Driver Details](../../crates/openshell-driver-podman/README.md)
