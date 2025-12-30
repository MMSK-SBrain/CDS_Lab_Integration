# CDS-EV Lab Integration - Setup Guide

**Version:** 1.0
**Last Updated:** November 27, 2025

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Environment Configuration](#environment-configuration)
4. [Running the Stack](#running-the-stack)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

| Software | Minimum Version | Download |
|----------|----------------|----------|
| Docker Desktop | 24.0+ | https://docker.com/products/docker-desktop |
| Docker Compose | 2.20+ | Included with Docker Desktop |
| Node.js | 18.0+ | https://nodejs.org |
| Python | 3.10+ | https://python.org |
| Git | 2.40+ | https://git-scm.com |

### System Requirements

- **RAM**: 8GB minimum, 16GB recommended
- **Disk Space**: 20GB free space
- **OS**: macOS, Linux, or Windows with WSL2

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker-compose --version

# Check Node.js
node --version
npm --version

# Check Python
python3 --version

# Check Git
git --version
```

---

## Initial Setup

### Step 1: Navigate to Workspace

```bash
cd /Volumes/Dev/CDS_Lab_Integration
```

### Step 2: Run Setup Script

```bash
./scripts/setup.sh
```

The setup script will:
1. ✅ Check prerequisites
2. ✅ Verify repository structure
3. ✅ Create `.env` from template
4. ✅ Install CDS dependencies
5. ✅ Install EV Lab dependencies
6. ✅ Build Docker images
7. ✅ Initialize databases
8. ✅ Create shared types

**Expected duration:** 15-30 minutes (first time)

### Step 3: Review Script Output

Look for green checkmarks (✓) indicating success:

```
✓ Docker found: Docker version 24.0.6
✓ Docker Compose found: Docker Compose version v2.23.0
✓ Node.js found: v18.17.0
✓ Python found: Python 3.10.12
✓ CDS repository found
✓ EV Lab repository found
✓ Created .env from template
...
✓ Setup Complete!
```

---

## Environment Configuration

### Step 1: Edit Environment File

```bash
nano .env
```

### Step 2: Replace All Placeholders

**Critical:** Replace ALL `change-this` values with secure secrets!

#### JWT Secret (Most Important!)

```bash
# Generate secure JWT secret
openssl rand -base64 32
```

Copy the output and paste into `.env`:

```env
JWT_SECRET=your-generated-secret-here
```

⚠️ **CRITICAL:** This secret MUST be identical for both CDS and EV Lab!

#### Database Passwords

Generate secure passwords:

```bash
# Generate database passwords
openssl rand -base64 24
openssl rand -base64 24
```

Update in `.env`:

```env
CDS_DB_PASSWORD=first-generated-password
EV_LAB_DB_PASSWORD=second-generated-password
```

#### API Keys

Generate API keys (32+ characters):

```bash
# Generate API keys
openssl rand -base64 32
openssl rand -base64 32
```

Update in `.env`:

```env
EV_LAB_API_KEY=first-generated-api-key
CDS_API_KEY=second-generated-api-key
```

### Step 3: Verify Configuration

```bash
# Check no 'change-this' placeholders remain
grep -n "change-this" .env

# Should output nothing (empty)
# If you see any lines, replace those values!
```

### Example Complete .env

```env
# Shared
JWT_SECRET=A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9t0U1v2W3x4Y5z6

# CDS Database
CDS_DB_NAME=cds_integration
CDS_DB_USER=cds_user
CDS_DB_PASSWORD=SecurePassword123!@#CDS

# EV Lab Database
EV_LAB_DB_NAME=ev_lab_integration
EV_LAB_DB_USER=ev_lab_user
EV_LAB_DB_PASSWORD=SecurePassword456!@#EVLab

# API Keys
EV_LAB_API_KEY=abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
CDS_API_KEY=xyz789abc012def345ghi678jkl901mno234pqr567stu890vw

# Integration
ENABLE_CDS_INTEGRATION=true
```

---

## Running the Stack

### Start All Services

```bash
./scripts/start.sh
```

Output:
```
╔═══════════════════════════════════════════════════════════╗
║   Starting CDS-EV Lab Integration Stack                  ║
╚═══════════════════════════════════════════════════════════╝

▶ Starting all services...

Creating network "cds-lab-network" ... done
Creating volume "cds-db-data" ... done
Creating volume "ev-lab-db-data" ... done
Creating cds-postgres-integration ... done
Creating ev-lab-postgres-integration ... done
Creating cds-redis-integration ... done
Creating ev-lab-redis-integration ... done
Creating pybamm-integration ... done
Creating ev-sim-integration ... done
Creating liionpack-integration ... done
Creating cds-backend-integration ... done
Creating ev-lab-api-integration ... done
Creating cds-frontend-integration ... done
Creating ev-lab-frontend-integration ... done

✓ All services started!

Access points:
  CDS Frontend:     http://localhost:3010
  CDS Backend:      http://localhost:3011
  EV Lab Frontend:  http://localhost:3020
  EV Lab API:       http://localhost:8010
```

### Check Service Status

```bash
cd infrastructure
docker-compose ps
```

All services should show "Up" status:

```
NAME                            STATUS
cds-backend-integration         Up
cds-frontend-integration        Up
cds-postgres-integration        Up (healthy)
cds-redis-integration           Up (healthy)
ev-lab-api-integration          Up (healthy)
ev-lab-frontend-integration     Up
ev-lab-postgres-integration     Up (healthy)
ev-lab-redis-integration        Up (healthy)
pybamm-integration              Up (healthy)
ev-sim-integration              Up (healthy)
liionpack-integration           Up (healthy)
```

### View Logs

```bash
# All services
./scripts/logs.sh

# Specific service
./scripts/logs.sh cds-backend
./scripts/logs.sh ev-lab-api-gateway
```

---

## Verification

### Step 1: Check Health Endpoints

```bash
# CDS Backend
curl http://localhost:3011/health

# Expected: {"status":"ok"}

# EV Lab API
curl http://localhost:8010/health

# Expected: {"status":"healthy"}
```

### Step 2: Access Frontend Applications

Open in browser:

1. **CDS Frontend**: http://localhost:3010
   - Should show CDS login page
   - No errors in browser console

2. **EV Lab Frontend**: http://localhost:3020
   - Should show EV Lab home page
   - No errors in browser console

### Step 3: Verify Database Connections

```bash
# CDS Database
docker-compose exec cds-db psql -U cds_user -d cds_integration -c "SELECT 1;"

# Expected:
#  ?column?
# ----------
#         1

# EV Lab Database
docker-compose exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c "SELECT 1;"

# Expected:
#  ?column?
# ----------
#         1
```

### Step 4: Verify Services Can Communicate

```bash
# Test CDS can reach EV Lab API
docker-compose exec cds-backend curl http://ev-lab-api-gateway:8000/health

# Expected: {"status":"healthy"}

# Test EV Lab can reach CDS Backend
docker-compose exec ev-lab-api-gateway curl http://cds-backend:3001/health

# Expected: {"status":"ok"}
```

### Step 5: Check Docker Networks

```bash
docker network inspect cds-lab-network
```

Verify all services are connected to `cds-lab-network`.

---

## Troubleshooting

### Issue: Services Won't Start

**Symptoms:**
- `docker-compose up` fails
- Services show "Exit 1" status

**Solution:**

```bash
# Check logs
./scripts/logs.sh

# Rebuild images
cd infrastructure
docker-compose build --no-cache

# Remove old containers
docker-compose down -v

# Start fresh
./scripts/start.sh
```

### Issue: Port Already in Use

**Symptoms:**
```
Error: bind: address already in use
```

**Solution:**

```bash
# Find process using port (example: 3010)
lsof -i :3010

# Kill process
kill -9 <PID>

# Or change ports in docker-compose.yml
```

### Issue: Database Connection Errors

**Symptoms:**
- "Connection refused" errors
- "Database does not exist"

**Solution:**

```bash
# Reset databases
cd infrastructure
docker-compose down -v  # ⚠️ Deletes all data!

# Start databases only
docker-compose up -d cds-db ev-lab-db

# Wait for healthy status
docker-compose ps

# Run migrations
docker-compose up -d cds-backend
docker-compose exec cds-backend npm run prisma:migrate

# Start remaining services
docker-compose up -d
```

### Issue: .env Not Loaded

**Symptoms:**
- Environment variables are undefined
- Services can't connect to each other

**Solution:**

```bash
# Verify .env exists
ls -la .env

# Check syntax
cat .env | grep -v '^#' | grep -v '^$'

# Restart services
./scripts/stop.sh
./scripts/start.sh
```

### Issue: Docker Out of Memory

**Symptoms:**
- Services crash randomly
- Docker Desktop shows high memory usage

**Solution:**

1. Open Docker Desktop → Settings → Resources
2. Increase Memory to at least 8GB
3. Increase Swap to 2GB
4. Click "Apply & Restart"

### Issue: Hot Reload Not Working

**Symptoms:**
- Code changes don't reflect in running app

**Solution:**

```bash
# Restart specific service
cd infrastructure
docker-compose restart cds-frontend

# Or rebuild
docker-compose up -d --build cds-frontend
```

### Issue: Permission Denied

**Symptoms:**
```
bash: ./scripts/setup.sh: Permission denied
```

**Solution:**

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run again
./scripts/setup.sh
```

---

## Next Steps

After successful setup:

1. ✅ **Test SSO Flow** - Implement SSO integration (Phase 3)
2. ✅ **Configure Webhooks** - Set up result synchronization (Phase 4)
3. ✅ **Run Integration Tests** - Verify end-to-end flow
4. ✅ **Create Test Data** - Seed databases with sample organizations/students
5. ✅ **Review Security** - Audit secrets and access controls

---

## Additional Resources

- [Architecture Documentation](CDS_INTEGRATION_ARCHITECTURE.md)
- [Main README](../README.md)
- [Troubleshooting Guide](#troubleshooting)
- [CDS Documentation](../cds/CLAUDE.md)
- [EV Lab Documentation](../labs/ev-lab/CLAUDE.md)

---

**Questions or Issues?**
Check logs first: `./scripts/logs.sh`

**Setup Complete?**
Move to Phase 2: Database Integration

---

*Setup Guide v1.0 - November 27, 2025*
