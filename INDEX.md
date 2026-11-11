# 📑 OpenShell Claude Code Configuration — Complete Index

## 🎯 Start Here

### For Everyone
1. **[README.md](README.md)** — Overview, what this is, how to use it (10 min)
2. **[QUICKSTART.md](QUICKSTART.md)** — Get running in 5 minutes

### For Engineers
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** — How it all works together (15 min)
4. **[auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)** — Secure auth setup (20 min)

### For Operations
5. **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** — Production deployment
6. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Debug common issues

### For Everyone (Reference)
7. **[MANIFEST.md](MANIFEST.md)** — Package overview
8. **[STATUS.md](STATUS.md)** — What's been delivered, status report

---

## 📂 Directory Structure

```
openshell-claude-code-config/
├── 📚 Documentation
│   ├── README.md                   Main entry point
│   ├── QUICKSTART.md               5-minute guide
│   ├── ARCHITECTURE.md             Technical explanation
│   ├── TROUBLESHOOTING.md          Debug help
│   ├── MANIFEST.md                 Package overview
│   ├── DEPLOYMENT_CHECKLIST.md     Production steps
│   ├── STATUS.md                   Status report
│   └── INDEX.md                    This file
│
├── docker/                         Podman deployment configuration
│   ├── Dockerfile                  Container image recipe
│   ├── docker-compose.yml          Local Podman Compose setup
│   ├── gateway.toml                Gateway config (OIDC!)
│   └── .env.example                Environment template
│
├── 🔐 auth/                        Authentication
│   └── AUTHENTICATION.md           Complete auth guide
│
├── 🔒 policy/                      Security
│   └── base-policy.yaml            Filesystem & network rules
│
├── ⚙️ scripts/                     Automation
│   ├── setup.sh                    One-command setup
│   ├── validate.sh                 Configuration validation
│   └── cleanup.sh                  Safe cleanup
│
├── 📚 examples/                    Usage examples
│   ├── basic.sh                    Development setup
│   └── with-keycloak.sh            Production with OIDC
│
└── 🔷 k8s/                         Kubernetes (future)
```

---

## 🚀 Quick Navigation

### "I just want to run it"
→ [QUICKSTART.md](QUICKSTART.md)  
→ `bash scripts/setup.sh`  

### "I want to understand how it works"
→ [ARCHITECTURE.md](ARCHITECTURE.md)  
→ [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)  

### "I need to set up production"
→ [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)  
→ Follow steps 1-7  

### "I'm running into issues"
→ `bash scripts/validate.sh`  
→ [TROUBLESHOOTING.md](TROUBLESHOOTING.md)  

### "Tell me what's included"
→ [MANIFEST.md](MANIFEST.md)  
→ [STATUS.md](STATUS.md)  

---

## 📋 File Guide

| File | Purpose | Time | Audience |
|------|---------|------|----------|
| **README.md** | What, why, how | 10 min | Everyone |
| **QUICKSTART.md** | Get running | 5 min | Impatient users |
| **ARCHITECTURE.md** | Technical details | 15 min | Engineers |
| **auth/AUTHENTICATION.md** | Auth setup guides | 20 min | DevOps/SecOps |
| **TROUBLESHOOTING.md** | Debug guide | Reference | Support/Users |
| **DEPLOYMENT_CHECKLIST.md** | Production steps | Checklist | DevOps |
| **MANIFEST.md** | Package contents | 5 min | Everyone |
| **STATUS.md** | Status report | 10 min | Managers |
| **INDEX.md** | This navigation | 2 min | Everyone |

---

## 🔥 Most Important Files

### To Deploy
1. **[scripts/setup.sh](scripts/setup.sh)** — One command does everything
2. **[docker/gateway.toml](docker/gateway.toml)** — Configuration
3. **[docker/Dockerfile](docker/Dockerfile)** — Container image
4. **[policy/base-policy.yaml](policy/base-policy.yaml)** — Security rules

### To Understand
1. **[README.md](README.md)** — Overview
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** — How it works
3. **[auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)** — Auth mechanism

### To Fix
1. **[scripts/validate.sh](scripts/validate.sh)** — Diagnose
2. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Solutions

---

## 🎓 Learning Paths

### Path 1: Get It Running (15 minutes)
```
QUICKSTART.md
    ↓
bash scripts/setup.sh
    ↓
openshell sandbox run demo -- claude --help
    ↓
Done!
```

### Path 2: Deep Dive (1 hour)
```
README.md (10 min)
    ↓
ARCHITECTURE.md (15 min)
    ↓
bash scripts/setup.sh (5 min)
    ↓
Try examples (20 min)
    ↓
Review auth/AUTHENTICATION.md (10 min)
    ↓
Full understanding
```

### Path 3: Production Deployment (2-4 hours)
```
DEPLOYMENT_CHECKLIST.md
    ├─ Step 1: Configure authentication
    ├─ Step 2: Configure TLS
    ├─ Step 3: Configure database
    ├─ Step 4: Security hardening
    ├─ Step 5: Deploy
    ├─ Step 6: Test
    └─ Step 7: Monitor

Then:
    ↓
auth/AUTHENTICATION.md (for detailed auth setup)
    ↓
Deploy to production
```

---

## 💡 Key Concepts

### Three Layers of Security
1. **Gateway Config** — Controls authentication, images
2. **Container image recipe** — Non-root user, available tools
3. **Kernel Policy** — Landlock, seccomp, network proxy

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

### Authentication (NEW!)
- **Development:** No authentication (unauthenticated_users = true)
- **Production:** OIDC with Keycloak/GitHub/Google
- **Credentials:** Stored encrypted, injected at supervisor level

See [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md) for setup.

### One-Command Deployment
```bash
bash scripts/setup.sh
```
Handles all setup automatically. See [scripts/setup.sh](scripts/setup.sh).

---

## ✅ Checklist for New Users

- [ ] Read [README.md](README.md)
- [ ] Run `bash scripts/validate.sh` to check prerequisites
- [ ] Run `bash scripts/setup.sh` to deploy
- [ ] Create your first sandbox
- [ ] Run Claude Code in the sandbox
- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand how it works
- [ ] Read [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md) for auth details
- [ ] Plan your production deployment using [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

---

## 🆘 Troubleshooting Quick Links

| Issue | File | Section |
|-------|------|---------|
| Setup script fails | [scripts/validate.sh](scripts/validate.sh) | Run first |
| OIDC not working | [auth/AUTHENTICATION.md](auth/AUTHENTICATION.md) | Troubleshooting |
| Policy blocking access | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Policy Issues |
| Podman errors | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Container Issues |
| TLS certificate problems | [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | Step 2 |
| Database connection error | [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | Step 3 |

---

## 📞 Support Resources

### In This Package
- `bash scripts/validate.sh` — Check configuration
- `bash scripts/cleanup.sh` — Clean start
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Common issues
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) — Detailed steps

### External
- [OpenShell Docs](https://docs.nvidia.com/openshell)
- [OIDC](https://openid.net/connect/)
- [Keycloak](https://www.keycloak.org/)

---

## 🎯 Success Criteria

✅ **Setup:** `bash scripts/setup.sh` works and completes in <5 min  
✅ **Sandbox:** Can create and run Claude Code  
✅ **Auth:** OIDC works with Keycloak/GitHub/Google  
✅ **Policy:** Network and filesystem rules are enforced  
✅ **Production:** Can deploy with TLS and OIDC  

---

## 📊 What's Here

- ✅ **23 Files** — All you need to deploy
- ✅ **90+ KB** — Complete documentation
- ✅ **7 Guides** — README, QUICKSTART, ARCHITECTURE, AUTH, TROUBLESHOOTING, DEPLOYMENT, STATUS
- ✅ **3 Scripts** — Setup, validate, cleanup
- ✅ **2 Examples** — Basic and production
- ✅ **4 Configs** — Container image recipe, Compose file, gateway.toml, policy

---

## 🚀 Get Started Now

### Option 1: Fast (5 min)
```bash
cd openshell-claude-code-config
bash scripts/setup.sh
```

### Option 2: Understand First (30 min)
```bash
cd openshell-claude-code-config
cat README.md
cat ARCHITECTURE.md
bash scripts/setup.sh
```

### Option 3: Production (2-4 hours)
```bash
cd openshell-claude-code-config
cat DEPLOYMENT_CHECKLIST.md
# Follow all 7 steps
```

---

## 📖 Recommended Reading Order

1. **[README.md](README.md)** — Start here (everyone)
2. **[QUICKSTART.md](QUICKSTART.md)** — Get running (impatient? here!)
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** — Deep dive (engineers)
4. **[auth/AUTHENTICATION.md](auth/AUTHENTICATION.md)** — Auth setup (production)
5. **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** — Go live (ops)
6. **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Debug (when needed)
7. **[STATUS.md](STATUS.md)** — What's included (reference)

---

**Next Step:** Open [README.md](README.md) →

---

**Version:** 1.0  
**Last Updated:** November 2024  
**Status:** ✅ Production Ready

