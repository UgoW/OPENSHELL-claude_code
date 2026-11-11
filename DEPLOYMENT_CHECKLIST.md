# 🚀 OpenShell Claude Code — Deployment Checklist

## Pre-Deployment

- [ ] Read `README.md` (10 min)
- [ ] Read `QUICKSTART.md` (5 min)
- [ ] Run `bash scripts/validate.sh` to check prerequisites
- [ ] Verify Podman and its Compose provider are installed and running: `podman ps` and `podman compose version`
- [ ] Verify OpenShell CLI installed: `openshell --version`

## Development Deployment (Insecure - Local Only)

### Option A: Automated Setup
```bash
bash scripts/setup.sh
```
Then follow prompts. ✓ Takes ~3 minutes.

### Option B: Manual Setup
1. Build image: `podman build -f docker/Dockerfile -t openshell-claude-code:latest .`
2. Start gateway: `cd docker && podman compose up -d`
3. Register: `openshell gateway add http://localhost:8080 --name openshell-local`
4. Create sandbox: `openshell sandbox create --name demo --image openshell-claude-code:latest --policy policy/base-policy.yaml`
5. Run: `openshell sandbox run demo -- claude --help`

**Status:** ✅ Ready
**Authentication:** Development mode (unauthenticated)
**Use for:** Learning, testing, local development only

---

## Production Deployment (Secure - Multi-User)

### Prerequisites
- [ ] TLS certificates (mTLS for gateway)
- [ ] OIDC provider (Keycloak, GitHub, Google, or custom)
- [ ] PostgreSQL database (for credential storage)
- [ ] Network with stable DNS resolution

### Step 1: Configure Authentication

#### Option A: Keycloak OIDC (Recommended)

1. Start Keycloak:
```bash
podman run -d -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest start-dev
```

2. Create realm "openshell" and client "openshell-gateway"
3. Set Redirect URI: `https://your-domain:8080/oauth2/callback`
4. Copy Client Secret

5. Update `docker/gateway.toml`:
```toml
[openshell.gateway.oidc]
issuer_url = "https://keycloak.your-domain/realms/openshell"
client_id = "openshell-gateway"
client_secret = "YOUR_SECRET"
redirect_uri = "https://your-domain:8080/oauth2/callback"
```

#### Option B: GitHub OAuth2

1. Create OAuth App at https://github.com/settings/developers
2. Set Authorization callback: `https://your-domain:8080/oauth2/callback`
3. Copy Client ID and Secret

4. Update `docker/gateway.toml`:
```toml
[openshell.gateway.oauth2]
provider = "github"
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_SECRET"
redirect_uri = "https://your-domain:8080/oauth2/callback"
```

#### Option C: Google OAuth2

1. Create credentials at https://console.cloud.google.com
2. Set Authorized redirect: `https://your-domain:8080/oauth2/callback`
3. Copy Client ID and Secret

4. Update `docker/gateway.toml`:
```toml
[openshell.gateway.oauth2]
provider = "google"
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_SECRET"
redirect_uri = "https://your-domain:8080/oauth2/callback"
```

See `auth/AUTHENTICATION.md` for detailed setup guides.

- [ ] Authentication method chosen and configured
- [ ] Credentials verified with provider

### Step 2: Configure TLS

1. Obtain certificates for your domain (Let's Encrypt, enterprise CA, etc.)
2. Update `docker/gateway.toml`:
```toml
[openshell.gateway]
disable_tls = false

[openshell.gateway.tls]
cert_path = "/etc/openshell/tls/server.crt"
key_path = "/etc/openshell/tls/server.key"
ca_path = "/etc/openshell/tls/ca.crt"
```

3. Mount certificates in `docker/docker-compose.yml`:
```yaml
volumes:
  - /etc/openshell/tls:/etc/openshell/tls:ro
```

- [ ] TLS certificates obtained
- [ ] TLS configuration in gateway.toml
- [ ] Certificates mounted in docker-compose.yml

### Step 3: Configure Database

1. Set up PostgreSQL (managed service or self-hosted)
2. Create database `openshell_credentials`
3. Create user with permissions

4. Update `docker/.env`:
```bash
DATABASE_URL=postgresql://user:password@postgres.your-domain:5432/openshell_credentials
```

5. Update `docker/gateway.toml`:
```toml
[openshell.gateway.database]
url = "${DATABASE_URL}"
```

- [ ] PostgreSQL running and accessible
- [ ] Database created and user configured
- [ ] DATABASE_URL set in .env

### Step 4: Security Hardening

Review security best practices in `auth/AUTHENTICATION.md`:

- [ ] CSRF protection enabled
- [ ] Rate limiting configured
- [ ] TLS certificate pinning (optional)
- [ ] Credential injection validation
- [ ] Audit logging enabled

### Step 5: Deployment

1. Update `docker/gateway.toml` with production settings (see comments)
2. Build image: `podman build -f docker/Dockerfile -t openshell-claude-code:prod .`
3. Deploy to production:

```bash
cd docker
podman compose -f docker-compose.yml down
podman compose -f docker-compose.yml up -d
```

4. Verify:
```bash
curl https://your-domain:8080/healthz
```

5. Register gateway:
```bash
openshell gateway add https://your-domain:8080 \
  --name openshell-prod \
  --ca-cert /path/to/ca.crt
```

- [ ] Production gateway.toml configured
- [ ] Image built for production
- [ ] Gateway deployed and running
- [ ] TLS certificate validated
- [ ] Database connection verified
- [ ] OIDC authentication tested
- [ ] Gateway registered with CLI

### Step 6: Testing

1. Create test sandbox:
```bash
openshell sandbox create --name test-prod \
  --image openshell-claude-code:prod \
  --policy policy/base-policy.yaml
```

2. Run test command:
```bash
openshell sandbox run test-prod -- claude --version
```

3. Verify logs:
```bash
openshell sandbox logs test-prod
```

4. Check policy enforcement:
```bash
openshell sandbox run test-prod -- curl https://api.anthropic.com
# Should succeed

openshell sandbox run test-prod -- curl https://evil.com
# Should fail (blocked by policy)
```

- [ ] Sandbox creation successful
- [ ] Claude CLI accessible
- [ ] Policy enforcement working
- [ ] Logs appear correctly
- [ ] Network restrictions enforced

### Step 7: Monitoring & Maintenance

1. Set up log aggregation (ELK, Datadog, CloudWatch)
2. Configure alerts:
   - Gateway health/uptime
   - Failed authentications
   - Policy violations
   - Database connection errors

3. Scheduled maintenance:
   - Daily: Review error logs
   - Weekly: Update Claude CLI version
   - Monthly: Rotate TLS certificates
   - Quarterly: Security audit

```bash
# Monitor gateway health
watch -n 5 'curl https://your-domain:8080/healthz'

# View all sandboxes
openshell sandbox list

# View gateway logs
podman logs openshell-gateway

# Cleanup old sandboxes
bash scripts/cleanup.sh
```

- [ ] Log aggregation configured
- [ ] Alerts set up
- [ ] Health checks scheduled
- [ ] Monitoring dashboard created
- [ ] On-call rotation established

---

## Kubernetes Deployment (Optional)

For multi-region or highly available deployments:

1. Create Kubernetes manifests in `k8s/`:
   - `gateway-deployment.yaml` — Gateway Deployment + Service
   - `sandbox-pod-template.yaml` — Sandbox pod template
   - `configmap.yaml` — gateway.toml and policies
   - `secret.yaml` — TLS certs, OAuth secrets

2. Deploy:
```bash
kubectl apply -f k8s/
```

See `k8s/README.md` (coming soon) for detailed Kubernetes setup.

- [ ] Kubernetes cluster available
- [ ] Manifests created and tested
- [ ] TLS certificates configured
- [ ] Ingress/load balancer configured
- [ ] Monitoring integrated

---

## Rollback & Disaster Recovery

If issues occur:

1. **Immediate Rollback:**
```bash
podman compose down
podman compose up -d  # Uses previous image tag
```

2. **Full Cleanup:**
```bash
bash scripts/cleanup.sh --confirm
```

3. **Database Backup/Restore:**
```bash
# Backup
pg_dump openshell_credentials > backup.sql

# Restore
psql openshell_credentials < backup.sql
```

4. **Certificate Emergency:**
   - If TLS cert expires: Run Let's Encrypt renewal
   - If OAuth secret compromised: Rotate in provider console
   - If database compromised: Restore from backup

- [ ] Rollback procedure documented
- [ ] Database backups automated
- [ ] Disaster recovery plan reviewed
- [ ] On-call team trained

---

## Post-Deployment

### User Onboarding

1. Users navigate to `https://your-domain:8080`
2. Click "Login with [Provider]"
3. Authenticate with GitHub/Google/Keycloak
4. Gateway redirects with OAuth token
5. User can now create and run sandboxes

### First Sandbox Creation

```bash
# User creates sandbox
openshell sandbox create --name my-project \
  --image openshell-claude-code:prod \
  --policy policy/base-policy.yaml

# User runs Claude Code
openshell sandbox run my-project -- claude chat "Hello"

# User monitors
openshell sandbox watch my-project
```

### Ongoing Support

- Answer questions about `QUICKSTART.md`
- Monitor `TROUBLESHOOTING.md` for common issues
- Review logs for failed authentications
- Update policies as needed

---

## Verification Checklist

### Development
- [ ] `bash scripts/setup.sh` completes successfully
- [ ] `openshell gateway add http://localhost:8080` works
- [ ] `openshell sandbox create` creates sandbox
- [ ] `openshell sandbox run` executes Claude CLI
- [ ] `openshell sandbox logs` shows output

### Production
- [ ] HTTPS certificate valid: `openssl s_client -connect your-domain:8080`
- [ ] OIDC working: Browser redirect and token received
- [ ] Database connected: `psql $DATABASE_URL`
- [ ] Health check passes: `curl https://your-domain:8080/healthz`
- [ ] Sandbox creation succeeds
- [ ] Policy enforcement blocks unauthorized access
- [ ] Logs appear in aggregation system
- [ ] Monitoring dashboard shows metrics

---

## Troubleshooting

### Gateway won't start
```bash
bash scripts/validate.sh
podman logs openshell-gateway
```

### OIDC not working
Check `auth/AUTHENTICATION.md` → Troubleshooting section

### Policy blocking legitimate access
Review `policy/base-policy.yaml` → add missing endpoint

### Database connection error
Verify `DATABASE_URL` in `.env`
Test connection: `psql $DATABASE_URL`

### TLS certificate error
Verify certificate is valid: `openssl x509 -in cert.pem -text`
Check file permissions: `ls -la /etc/openshell/tls/`

---

## Success Criteria

✅ **Development:** Users can run `bash scripts/setup.sh` and have Claude Code running in 5 min  
✅ **Production:** Users can authenticate with OIDC and create secure sandboxes  
✅ **Security:** Credentials never exposed, policy enforcement working  
✅ **Reliability:** Gateway uptime > 99.9%, all logs captured  
✅ **Support:** Users can self-serve from docs and troubleshooting guide  

---

**Ready to deploy?** Start with `bash scripts/setup.sh` or follow Step 1 above.

**Questions?** Check `README.md`, `QUICKSTART.md`, `auth/AUTHENTICATION.md`, or `TROUBLESHOOTING.md`.
