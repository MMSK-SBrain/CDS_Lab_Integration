# 🚀 Quick Start - CDS-EV Lab Integration

**Get up and running in 5 minutes!**

---

## Prerequisites

- ✅ Docker Desktop installed and running
- ✅ 8GB+ RAM available
- ✅ 20GB free disk space

---

## Setup (First Time Only)

```bash
# 1. Navigate to workspace
cd /Volumes/Dev/CDS_Lab_Integration

# 2. Run setup
./scripts/setup.sh

# 3. Generate secrets
openssl rand -base64 32  # Copy for JWT_SECRET
openssl rand -base64 24  # Copy for CDS_DB_PASSWORD
openssl rand -base64 24  # Copy for EV_LAB_DB_PASSWORD
openssl rand -base64 32  # Copy for EV_LAB_API_KEY
openssl rand -base64 32  # Copy for CDS_API_KEY

# 4. Edit .env and paste secrets
nano .env
# Replace ALL 'change-this' values

# 5. Start services
./scripts/start.sh
```

---

## Access Applications

| App | URL |
|-----|-----|
| **CDS** | http://localhost:3010 |
| **EV Lab** | http://localhost:3020 |

---

## Daily Usage

### Start

```bash
cd /Volumes/Dev/CDS_Lab_Integration
./scripts/start.sh
```

### Stop

```bash
./scripts/stop.sh
```

### View Logs

```bash
./scripts/logs.sh
```

---

## Verify Everything Works

```bash
# Check health
curl http://localhost:3011/health  # CDS: {"status":"ok"}
curl http://localhost:8010/health  # EV Lab: {"status":"healthy"}

# Check services
cd infrastructure && docker-compose ps  # All should be "Up"
```

---

## Troubleshooting

### Port Conflicts?

```bash
# Change ports in docker-compose.yml
# Or kill conflicting process:
lsof -i :3010
kill -9 <PID>
```

### Services Won't Start?

```bash
# Check logs
./scripts/logs.sh

# Rebuild
cd infrastructure
docker-compose down -v
docker-compose build --no-cache
docker-compose up
```

### Environment Not Loading?

```bash
# Verify .env exists and has no 'change-this'
cat .env | grep "change-this"

# Should be empty!
```

---

## Next Steps

1. ✅ Read [SETUP.md](docs/SETUP.md) for detailed guide
2. ✅ Review [Architecture](docs/CDS_INTEGRATION_ARCHITECTURE.md)
3. ✅ Start Phase 2: Database Integration

---

**Demo environments remain untouched:**
- CDS Demo: http://localhost:3000
- EV Lab Demo: http://localhost:3000 (separate run)

**Questions?** Check [README.md](README.md) or [SETUP.md](docs/SETUP.md)

---

*Happy Integrating! 🎉*
