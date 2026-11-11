# Authentication Guide for OpenShell Claude Code

This guide explains how to configure proper authentication (OAuth2/OIDC) instead of using raw API tokens.

## Overview

OpenShell Claude Code supports three authentication methods:

1. **OIDC (Recommended)** — Industry-standard OpenID Connect with Keycloak, Okta, Google, etc.
2. **OAuth2** — GitHub, Google, Microsoft, or any OAuth2-compatible provider
3. **Unauthenticated (Development Only)** — No authentication (for local testing)

## Why Not API Tokens?

### Problems with Raw API Tokens

❌ **Exposure Risk** — Tokens in environment variables are logged and visible  
❌ **No Revocation** — Hard to revoke individual credentials  
❌ **No Audit Trail** — Can't track who did what  
❌ **Single Identity** — All sandboxes use the same credentials  
❌ **Manual Management** — Must manually rotate credentials  

### Benefits of OIDC/OAuth2

✅ **Secure** — Credentials never exposed to the agent  
✅ **Centralized** — Managed in a central identity provider  
✅ **Auditable** — Full audit trail of who accessed what  
✅ **Per-User** — Each user has their own identity  
✅ **Revocable** — Instantly revoke access  
✅ **Standards-Based** — Industry standard, not vendor-specific  

## Quick Setup: OIDC with Keycloak

### Prerequisites

- Keycloak running (or any OIDC provider)
- OpenShell CLI installed
- Podman and a Podman Compose provider installed

### Step 1: Set Up Keycloak (Optional)

If you don't have Keycloak, set it up locally:

```bash
# Run Keycloak with Podman
podman run -d \
  --name keycloak \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest \
  start-dev

# Wait for Keycloak to start (~10 seconds)
sleep 10

# Access Keycloak admin console
# http://localhost:8080/admin/master/console
# Username: admin
# Password: admin
```

### Step 2: Configure Keycloak

1. **Create a Realm**
   - Go to Admin Console > Create Realm > Name: `openshell`
   - Click Create

2. **Create a Client**
   - In the `openshell` realm, go to Clients > Create client
   - Client ID: `openshell-gateway`
   - Click Next
   - Enable: Client authentication
   - Click Save

3. **Configure Client**
   - Go to the client settings
   - Set Valid Redirect URIs: `http://localhost:8080/oauth2/callback`
   - Click Save

4. **Get Client Secret**
   - Go to Credentials tab
   - Copy the Client Secret

### Step 3: Configure OpenShell Gateway

Edit `docker/gateway.toml`:

```toml
[openshell.gateway.oidc]
issuer_url = "http://localhost:8080/realms/openshell"
client_id = "openshell-gateway"
client_secret = "PASTE_YOUR_CLIENT_SECRET_HERE"
redirect_uri = "http://localhost:8080/oauth2/callback"
scopes = ["openid", "profile", "email"]

# Disable unauthenticated access
[openshell.gateway.auth]
allow_unauthenticated_users = false
```

### Step 4: Start the Gateway

```bash
cd docker
podman compose -f docker-compose.yml up -d

# Verify gateway is running
curl http://localhost:8080/healthz
```

### Step 5: Access the Gateway

1. **CLI Login**
   ```bash
   openshell gateway add http://localhost:8080 --name openshell-oidc
   openshell login  # Opens browser for OIDC login
   ```

2. **Create Users (in Keycloak)**
   - Go to Users > Create user
   - Username: `claude-user`
   - Set password and save
   - Log in with this user via OpenShell CLI

3. **Create Sandboxes**
   ```bash
   openshell sandbox create --name claude-demo \
     --image openshell-claude-code:latest \
     --policy ../policy/base-policy.yaml
   ```

## Alternative: OAuth2 with GitHub

### Prerequisites

- GitHub account
- GitHub OAuth2 application created

### Step 1: Create GitHub OAuth2 Application

1. Go to GitHub > Settings > Developer settings > OAuth Apps
2. Click "New OAuth App"
3. **Application name:** OpenShell Claude
4. **Homepage URL:** `http://localhost:8080`
5. **Authorization callback URL:** `http://localhost:8080/oauth2/callback`
6. Click "Register application"
7. Copy **Client ID** and **Client Secret**

### Step 2: Configure OpenShell Gateway

Edit `docker/gateway.toml`:

```toml
[openshell.gateway.oauth2]
provider = "github"
client_id = "PASTE_YOUR_CLIENT_ID"
client_secret = "PASTE_YOUR_CLIENT_SECRET"
redirect_uri = "http://localhost:8080/oauth2/callback"

# Disable unauthenticated access
[openshell.gateway.auth]
allow_unauthenticated_users = false
```

### Step 3: Restart Gateway

```bash
cd docker
podman compose -f docker-compose.yml restart gateway
```

### Step 4: Login via GitHub

```bash
openshell gateway add http://localhost:8080 --name openshell-github
openshell login  # Opens browser for GitHub login
```

## Alternative: OAuth2 with Google

### Prerequisites

- Google Cloud account
- OAuth2 credentials created

### Step 1: Create Google OAuth2 Credentials

1. Go to Google Cloud Console
2. Create a new project or select existing
3. Enable Google+ API
4. Go to APIs & Services > Credentials
5. Click "Create Credentials" > OAuth 2.0 Client ID
6. Application type: Web application
7. Authorized redirect URIs: `http://localhost:8080/oauth2/callback`
8. Copy **Client ID** and **Client Secret**

### Step 2: Configure OpenShell Gateway

Edit `docker/gateway.toml`:

```toml
[openshell.gateway.oauth2]
provider = "google"
client_id = "PASTE_YOUR_CLIENT_ID"
client_secret = "PASTE_YOUR_CLIENT_SECRET"
redirect_uri = "http://localhost:8080/oauth2/callback"

# Disable unauthenticated access
[openshell.gateway.auth]
allow_unauthenticated_users = false
```

### Step 3: Restart and Login

```bash
cd docker
podman compose -f docker-compose.yml restart gateway
openshell gateway add http://localhost:8080 --name openshell-google
openshell login  # Opens browser for Google login
```

## Advanced: Using Environment Variables

Instead of hardcoding secrets in `gateway.toml`, use environment variables:

```toml
[openshell.gateway.oidc]
issuer_url = "${OIDC_ISSUER_URL}"
client_id = "${OIDC_CLIENT_ID}"
client_secret = "${OIDC_CLIENT_SECRET}"
redirect_uri = "${OIDC_REDIRECT_URI}"
```

Then set environment variables before starting:

```bash
export OIDC_ISSUER_URL="http://keycloak:8080/realms/openshell"
export OIDC_CLIENT_ID="openshell-gateway"
export OIDC_CLIENT_SECRET="secret"
export OIDC_REDIRECT_URI="http://localhost:8080/oauth2/callback"

podman compose -f docker-compose.yml up -d
```

## How Authentication Flows Work

### OIDC Flow

```
1. User runs: openshell login
2. Browser opens to: http://localhost:8080/oauth2/authorize
3. Gateway redirects to Keycloak: http://keycloak:8080/auth/...
4. User logs in with username/password
5. Keycloak redirects back with ID token
6. Gateway validates token and creates session
7. User's credentials are stored securely in OpenShell database
8. Sandboxes inherit user credentials (not exposed)
```

### Credential Injection

Unlike raw API tokens, OIDC/OAuth2 credentials are:
1. Stored securely in the database (encrypted)
2. Never exposed to the agent directly
3. Injected by the supervisor into specific API calls
4. Used to authenticate to approved endpoints only

**Example:**
```
User logs in via OIDC
  ↓
OpenShell stores encrypted refresh token
  ↓
User creates sandbox with policy
  ↓
Supervisor injects credentials into Anthropic API calls
  ↓
Claude Code makes authenticated requests
  ↓
Supervisor enforces policy (only Anthropic API allowed)
```

## Security Best Practices

1. **Always Use TLS in Production**
   ```toml
   disable_tls = false
   
   [openshell.gateway.tls]
   cert_path = "/etc/openshell/tls/cert.pem"
   key_path = "/etc/openshell/tls/key.pem"
   ```

2. **Rotate Secrets Regularly**
   - OAuth2 client secrets
   - OIDC signing keys
   - JWT keys

3. **Use Strong Passwords**
   - OIDC provider (Keycloak) admin password
   - Database passwords

4. **Audit Logs**
   - Enable logging in OpenShell: `log_level = "debug"`
   - Store logs centrally
   - Monitor for suspicious activity

5. **Policy Enforcement**
   - Use restrictive policies (read-only by default)
   - Whitelist specific endpoints only
   - Regularly review and update policies

## Troubleshooting

### "Invalid redirect URI" Error

**Cause:** The redirect URI in your OAuth provider doesn't match the one in `gateway.toml`

**Solution:**
```bash
# Check your config
grep redirect_uri openshell-claude-code-config/docker/gateway.toml

# Update in OAuth provider to match exactly
# Example: http://localhost:8080/oauth2/callback
```

### "Client secret invalid" Error

**Cause:** Client secret is outdated or copied incorrectly

**Solution:**
```bash
# Regenerate in your OAuth provider (Keycloak, GitHub, etc.)
# Copy the new secret carefully (no extra spaces)
# Update gateway.toml
# Restart gateway: podman compose restart gateway
```

### "OIDC issuer not reachable" Error

**Cause:** Keycloak or OIDC provider is not running or URL is wrong

**Solution:**
```bash
# Test connectivity
curl http://localhost:8080/realms/openshell/.well-known/openid-configuration

# If fails, Keycloak isn't running:
podman run -d -p 8080:8080 quay.io/keycloak/keycloak:latest start-dev
```

### Users Can't Log In

**Cause:** Users don't exist in OIDC provider or policy prevents access

**Solution:**

1. **For Keycloak:**
   ```bash
   # Create users in Keycloak admin console
   # http://localhost:8080/admin/master/console
   # Users > Create user
   ```

2. **For GitHub:**
   - User must be a member of your GitHub organization
   - Check organization settings > Members

3. **Check policy:**
   ```bash
   openshell sandbox list
   openshell policy get <sandbox-name>
   ```

## References

- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth2 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenShell Gateway Docs](https://docs.nvidia.com/openshell/latest/how-it-works/gateways)

## Summary

| Method | Security | Ease | Production | Recommendation |
|--------|----------|------|------------|-----------------|
| OIDC (Keycloak) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | **Recommended** |
| OAuth2 (GitHub) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | Good |
| API Token | ⭐ | ⭐⭐⭐⭐⭐ | ❌ | Dev only |
| Unauthenticated | ❌ | ⭐⭐⭐⭐⭐ | ❌ | Dev only |
