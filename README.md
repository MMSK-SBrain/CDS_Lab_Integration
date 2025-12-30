# CDS-EV Lab Integration Workspace

**Version:** 3.0
**Status:** Production Ready
**Last Updated:** December 30, 2025

---

## 🎯 Overview

This is the **integration workspace** for combining **Reynlab CDS (Content Delivery System)** with **EV Lab (Battery Lab V3)** and future lab platforms using a **git submodule architecture** for independent development and deployment.

### Architecture Strategy

This workspace uses **git submodules** to maintain independent repositories while enabling seamless integration:

- **CDS Repository**: `Lecture_Delivery` (integration branch)
- **EV Lab Repository**: `Integrated_EV_Lab` (integration branch)
- **Workspace Repository**: `CDS_Lab_Integration` (orchestration)

**Key Benefits:**
- ✅ Independent development (each platform can be developed separately)
- ✅ Independent deployment (standalone or integrated modes)
- ✅ Clean version control (submodules track specific commits)
- ✅ Feature flags (integration is opt-in via environment variables)

### What's Inside

```
CDS_Lab_Integration/
├── .gitmodules           # Git submodule configuration
├── cds/                  # Git submodule → Lecture_Delivery (integration branch)
├── labs/
│   └── ev-lab/           # Git submodule → Integrated_EV_Lab (integration branch)
├── infrastructure/       # Docker Compose for full stack
├── scripts/              # Management scripts
└── docs/                 # Integration documentation
```

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop (latest version)
- Docker Compose
- Git 2.30+ (with submodule support)
- Node.js 18+ (for local development)
- Python 3.10+ (for local development)

### Clone Workspace (First Time)

```bash
# Clone with submodules (recommended)
git clone --recursive https://github.com/MMSK-SBrain/CDS_Lab_Integration.git
cd CDS_Lab_Integration

# If you already cloned without --recursive, initialize submodules
git submodule update --init --recursive
```

### Initial Setup

```bash
# 1. Run setup script
./scripts/setup.sh

# 2. Copy environment template
cp .env.example .env

# 3. Edit .env with secure values
nano .env
# Replace all 'change-this' placeholders with actual secrets

# 4. Start the stack
./scripts/start.sh
```

### Update Workspace

```bash
# Pull latest changes from workspace and submodules
git pull
git submodule update --remote --merge

# Restart services
./scripts/stop.sh && ./scripts/start.sh
```

### Access Applications

| Application | URL | Description |
|------------|-----|-------------|
| **CDS Frontend** | http://localhost:3010 | Content Delivery System UI |
| **CDS Backend** | http://localhost:3011 | CDS API |
| **EV Lab Frontend** | http://localhost:3020 | Battery Lab UI |
| **EV Lab API** | http://localhost:8010 | EV Lab API Gateway |

**Demo environments remain untouched:**
- Original CDS: http://localhost:3000
- Original EV Lab: http://localhost:3000 (when run separately)

---

## 📦 Port Mapping

### Integration Ports (Different from Demos)

| Service | Demo Port | Integration Port |
|---------|-----------|------------------|
| **CDS** |
| Frontend | 3000 | **3010** |
| Backend | 3001 | **3011** |
| PostgreSQL | 5432 | **5433** |
| Redis | 6379 | **6380** |
| **EV Lab** |
| Frontend | 3000 | **3020** |
| API Gateway | 8000 | **8010** |
| PostgreSQL | 5432 | **5434** |
| Redis | 6379 | **6381** |
| PyBaMM | 8001 | **8011** |
| EV_sim | 8002 | **8012** |
| liionpack | 8003 | **8013** |

**Why different ports?** So you can run demos and integration simultaneously without conflicts!

---

## 🛠️ Management Scripts

All scripts are in `scripts/` directory:

### Setup & Start

```bash
# Initial setup (run once)
./scripts/setup.sh

# Start all services
./scripts/start.sh

# Stop all services
./scripts/stop.sh

# View logs
./scripts/logs.sh          # All services
./scripts/logs.sh cds-backend  # Specific service
```

### Sync from Demo Repos

```bash
# Pull latest changes from original repos
./scripts/sync-repos.sh
```

⚠️ **Warning:** This overwrites local changes. Commit first!

---

## 🏗️ Architecture

### Hub-and-Spoke Pattern

```
┌─────────────────────┐
│    CDS (Hub)        │
│  - SSO Generation   │
│  - Lab Registry     │
│  - Progress Track   │
└──────┬──────┬───────┘
       │      │
   SSO │      │ Results
       │      │
   ┌───┴──────┴───┐
   │              │
   ▼              ▼
┌──────┐      ┌──────┐
│EV Lab│      │Future│
│      │      │ Labs │
└──────┘      └──────┘
```

### Integration Flow

1. **SSO Authentication**
   - Student clicks "Launch Lab" in CDS
   - CDS generates JWT token
   - Student redirects to EV Lab (auto-login)

2. **Experiment Execution**
   - Student completes experiment in EV Lab
   - Results stored locally

3. **Result Synchronization**
   - EV Lab sends results to CDS webhook
   - CDS stores results and updates progress

---

## 📚 Documentation

Comprehensive documentation in `docs/`:

- **[ARCHITECTURE.md](docs/CDS_INTEGRATION_ARCHITECTURE.md)** - Complete integration architecture
- **SETUP.md** - Detailed setup instructions
- **TESTING.md** - Testing guide
- **DEPLOYMENT.md** - Production deployment guide

---

## 🔒 Security

### Environment Variables

**Never commit `.env` to version control!**

Required secrets in `.env`:
- `JWT_SECRET` - Shared between CDS and EV Lab (min 32 chars)
- `CDS_DB_PASSWORD` - CDS database password
- `EV_LAB_DB_PASSWORD` - EV Lab database password
- `EV_LAB_API_KEY` - API key for EV Lab → CDS webhooks
- `CDS_API_KEY` - API key for CDS → EV Lab calls

Generate secure secrets:
```bash
openssl rand -base64 32
```

### Multi-Tenant Isolation

- Each organization in CDS maps to an institution in EV Lab
- Database queries are scoped by organization/institution
- API keys prevent unauthorized cross-system calls

---

## 🧪 Testing

### Run Integration Tests

```bash
# CDS tests
cd cds/backend
npm run test

# EV Lab tests
cd labs/ev-lab
pytest tests/

# E2E tests
# TODO: Add Playwright E2E tests
```

### Health Checks

```bash
# Check all services
cd infrastructure
docker-compose ps

# Check specific service
curl http://localhost:3011/health  # CDS backend
curl http://localhost:8010/health  # EV Lab API
```

---

## 🔧 Development Workflow

### Making Changes

1. **Edit code** in `cds/` or `labs/ev-lab/`
2. **Hot reload** works for both frontend and backend
3. **View logs**: `./scripts/logs.sh`
4. **Restart service** if needed:
   ```bash
   cd infrastructure
   docker-compose restart cds-backend
   ```

### Adding New Features

1. Make changes in integration workspace
2. Test thoroughly
3. Commit to integration workspace git
4. Optionally sync back to demo repos (carefully!)

### Syncing from Demo Repos

If you make improvements in demo repos:

```bash
./scripts/sync-repos.sh
```

---

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check Docker is running
docker ps

# Check logs
./scripts/logs.sh

# Rebuild images
cd infrastructure
docker-compose build --no-cache
docker-compose up
```

### Port Conflicts

```bash
# Check what's using a port
lsof -i :3010

# Kill process if needed
kill -9 <PID>
```

### Database Issues

```bash
# Reset databases (⚠️  deletes all data)
cd infrastructure
docker-compose down -v
docker-compose up -d cds-db ev-lab-db

# Wait for databases to start
sleep 10

# Run migrations
docker-compose exec cds-backend npm run prisma:migrate
```

### Environment Variables Not Loading

```bash
# Check .env exists
ls -la .env

# Verify no syntax errors
cat .env | grep -v '^#' | grep -v '^$'

# Restart services
./scripts/stop.sh
./scripts/start.sh
```

---

## 🚢 Deployment

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for production deployment guide.

**Quick checklist:**
- [ ] All secrets are production-strength
- [ ] HTTPS enabled
- [ ] Rate limiting configured
- [ ] Monitoring set up
- [ ] Backups configured
- [ ] Load testing completed

---

## 📞 Support

### Getting Help

1. Check documentation in `docs/`
2. Review architecture diagram
3. Check logs: `./scripts/logs.sh`
4. Review demo repos for reference

### Contributing

1. Make changes in integration workspace
2. Test thoroughly
3. Document changes
4. Commit with clear messages

---

## 📋 Roadmap

### Phase 1: Workspace Setup ✅
- [x] Create directory structure
- [x] Clone repositories
- [x] Create Docker Compose
- [x] Create setup scripts

### Phase 2: Database Integration (In Progress)
- [ ] Add tenant mapping fields
- [ ] Run migrations
- [ ] Test multi-tenant isolation

### Phase 3: SSO Integration
- [ ] Implement JWT generation
- [ ] Implement token validation
- [ ] Test SSO flow

### Phase 4: Result Synchronization
- [ ] Implement webhook receiver
- [ ] Implement SDK integration
- [ ] Test result flow

### Phase 5: Dashboard
- [ ] Create unified progress view
- [ ] Add lab exercise management
- [ ] Add reporting

### Phase 6: Production Ready
- [ ] Security audit
- [ ] Performance optimization
- [ ] Monitoring setup
- [ ] Documentation complete

---

## 📄 License

This integration workspace combines:
- Reynlab CDS (proprietary)
- EV Lab (proprietary)

See individual repositories for license details.

---

**Built with ❤️ by Reynlab**
**Architecture: Winston (Architect Agent)**
**Date: November 27, 2025**
