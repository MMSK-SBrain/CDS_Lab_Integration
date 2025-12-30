# CDS-EV Lab Integration Strategy

**Date:** December 30, 2025
**Status:** Proposed
**Goal:** Maintain independent repos while enabling seamless integration

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  CDS_Lab_Integration_Workspace (NEW Git Repo)              │
│  Repository: CDS_Lab_Integration                            │
│  Purpose: Integration orchestration, docs, and config       │
│                                                              │
│  ├── .gitmodules                                            │
│  ├── cds/           → Git submodule → Lecture_Delivery      │
│  ├── labs/ev-lab/   → Git submodule → Integrated_EV_Lab     │
│  ├── infrastructure/                                         │
│  ├── scripts/                                                │
│  ├── docs/                                                   │
│  └── .env.example                                            │
└─────────────────────────────────────────────────────────────┘
         ↓ references                    ↓ references
┌──────────────────────┐        ┌──────────────────────────┐
│  Lecture_Delivery    │        │  Integrated_EV_Lab       │
│  (CDS Repo)          │        │  (EV Lab Repo)           │
│                      │        │                          │
│  Branches:           │        │  Branches:               │
│  ✓ main (standalone) │        │  ✓ Dev_V0 (standalone)   │
│  ✓ dev               │        │  ✓ obe-brainstorming     │
│  ✓ integration ← NEW │        │  ✓ integration ← NEW     │
└──────────────────────┘        └──────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Create Integration Branches (Week 1)

#### 1.1 CDS Repository

```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds

# Create integration branch from dev
git checkout -b integration dev

# Commit integration-specific changes
git add backend/src/routes/lab-integration.routes.ts
git add backend/src/types/lab-integration.ts
git add backend/prisma/migrations/20251127_add_evlab_integration/
git add MIGRATION_GUIDE_LAB_INTEGRATION.md

git commit -m "feat: Add EV Lab integration endpoints and database schema

- Add SSO token generation endpoint
- Add lab result webhook receiver
- Add LabPlatform, LabExerciseLink, LabExerciseResult models
- Add organization.evLabEnabled, evLabSsoEnabled feature flags
- Fully backward compatible - integration is opt-in via env vars

Related: CDS-EV Lab Integration Phase 1"

# Push integration branch
git push -u origin integration

# Switch back to dev for regular development
git checkout dev
```

**Branch Purpose:**
- `main`: Stable CDS standalone (no lab integration)
- `dev`: Active CDS development (may include integration features)
- `integration`: Dedicated integration branch (syncs with EV Lab integration)

#### 1.2 EV Lab Repository

```bash
cd /Volumes/Dev/CDS_Lab_Integration/labs/ev-lab

# Create integration branch from obe-brainstorming
git checkout -b integration obe-brainstorming

# Commit integration-specific changes
git add docker/api-gateway/routes/sso_routes.py
git add docker/api-gateway/routes/cds_integration_routes.py
git add docker/api-gateway/database/migrations/add_cds_integration.sql
git add frontend/src/app/sso/
git add sdk/
git add docs/CDS_INTEGRATION_ARCHITECTURE.md
git add CDS_INTEGRATION_IMPLEMENTATION_PLAN.md

git commit -m "feat: Add CDS integration SSO and result submission

- Add SSO login endpoint with JWT validation
- Add CDS result submission via webhook
- Add Institution.cds_organization_id mapping
- Add UserSSOMapping table for SSO tracking
- Add Python and TypeScript SDKs for CDS integration
- Fully backward compatible - integration is opt-in via env vars

Related: CDS-EV Lab Integration Phase 1"

# Push integration branch
git push -u origin integration

# Switch back to obe-brainstorming for regular development
git checkout obe-brainstorming
```

**Branch Purpose:**
- `Dev_V0`: Stable EV Lab standalone (no CDS integration)
- `obe-brainstorming`: Active OBE feature development
- `integration`: Dedicated integration branch (syncs with CDS integration)

---

### Phase 2: Create Integration Workspace Repo (Week 1)

#### 2.1 Initialize Workspace Repository

```bash
cd /Volumes/Dev/CDS_Lab_Integration

# Initialize git repository
git init

# Add .gitignore
cat > .gitignore << 'EOF'
# Environment files with secrets
.env

# OS files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes

# IDE
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
logs/

# Docker volumes
volumes/

# Temporary files
*.tmp
temp/
EOF

# Create README
cat > README.md << 'EOF'
# CDS-EV Lab Integration Workspace

This workspace orchestrates the integration between:
- **CDS (Content Delivery System)**: Instructor-centric training platform
- **EV Lab (Battery Lab V3)**: Educational battery simulation platform

## Quick Start

```bash
# Clone workspace with submodules
git clone --recursive https://github.com/MMSK-SBrain/CDS_Lab_Integration.git
cd CDS_Lab_Integration

# Initial setup
./scripts/setup.sh

# Start all services
./scripts/start.sh

# Access services
# CDS: http://localhost:3010
# EV Lab: http://localhost:3020
```

## Repository Structure

- `cds/` - Git submodule → [Lecture_Delivery](https://github.com/MMSK-SBrain/Lecture_Delivery) (integration branch)
- `labs/ev-lab/` - Git submodule → [Integrated_EV_Lab](https://github.com/MMSK-SBrain/Integrated_EV_Lab) (integration branch)
- `infrastructure/` - Docker Compose orchestration
- `scripts/` - Management scripts
- `docs/` - Integration documentation

## Documentation

- [Brownfield Architecture](docs/BROWNFIELD_ARCHITECTURE.md) - Complete technical architecture
- [Setup Guide](docs/SETUP.md) - Detailed setup instructions
- [Quick Start](QUICKSTART.md) - 5-minute setup guide

## Independent Usage

Each platform can be used independently:

### CDS Standalone
```bash
cd cds
# Follow cds/README.md for standalone setup
```

### EV Lab Standalone
```bash
cd labs/ev-lab
# Follow labs/ev-lab/README.md for standalone setup
```
EOF
```

#### 2.2 Add Submodules

```bash
# Remove existing directories (backup first!)
mv cds cds.backup
mv labs labs.backup

# Add CDS as submodule (integration branch)
git submodule add -b integration https://github.com/MMSK-SBrain/Lecture_Delivery.git cds

# Add EV Lab as submodule (integration branch)
mkdir -p labs
git submodule add -b integration https://github.com/MMSK-SBrain/Integrated_EV_Lab.git labs/ev-lab

# Initialize and update submodules
git submodule update --init --recursive
```

#### 2.3 Commit Integration Files

```bash
# Add integration-specific files
git add infrastructure/
git add scripts/
git add docs/
git add .env.example
git add CLAUDE.md
git add QUICKSTART.md
git add README.md
git add *.md

# Commit
git commit -m "Initial integration workspace setup

- Add CDS and EV Lab as git submodules (integration branches)
- Add Docker Compose orchestration (10 services)
- Add management scripts (setup, start, stop, logs)
- Add comprehensive integration documentation
- Add brownfield architecture document

Integration supports:
- SSO authentication (JWT-based)
- Result synchronization (webhook-based)
- Multi-tenant mapping (Organization ↔ Institution)
- Independent deployment (each platform can run standalone)"

# Create repository on GitHub
# Then push
git remote add origin https://github.com/MMSK-SBrain/CDS_Lab_Integration.git
git push -u origin main
```

---

### Phase 3: Establish Development Workflow (Week 2)

#### 3.1 Daily Development - Standalone Mode

**Scenario:** Develop new CDS feature (not integration-related)

```bash
# Work in CDS repo independently
cd /Volumes/Dev/CDS_Lab_Integration/cds
git checkout dev

# Make changes
# ... edit files ...

# Commit and push (no impact on integration)
git add .
git commit -m "feat: Add new grading feature"
git push origin dev
```

**Scenario:** Develop new EV Lab experiment (not integration-related)

```bash
# Work in EV Lab repo independently
cd /Volumes/Dev/CDS_Lab_Integration/labs/ev-lab
git checkout Dev_V0  # or obe-brainstorming

# Make changes
# ... edit files ...

# Commit and push (no impact on integration)
git add .
git commit -m "feat: Add new motor simulator experiment"
git push origin Dev_V0
```

#### 3.2 Integration Development

**Scenario:** Add new lab platform integration to CDS

```bash
# Work in integration workspace
cd /Volumes/Dev/CDS_Lab_Integration

# Update CDS submodule to integration branch
cd cds
git checkout integration
git pull origin integration

# Make CDS changes
# ... edit backend/src/routes/lab-integration.routes.ts ...

# Commit in CDS repo
git add .
git commit -m "feat: Add support for Chemistry Lab platform"
git push origin integration

# Return to workspace and update submodule reference
cd ..
git add cds
git commit -m "Update CDS submodule: Add Chemistry Lab integration"
git push origin main
```

**Scenario:** Add new SSO feature in EV Lab

```bash
cd /Volumes/Dev/CDS_Lab_Integration/labs/ev-lab
git checkout integration
git pull origin integration

# Make changes
# ... edit docker/api-gateway/routes/sso_routes.py ...

# Commit in EV Lab repo
git add .
git commit -m "feat: Add SSO session timeout warning"
git push origin integration

# Update workspace
cd ../..
git add labs/ev-lab
git commit -m "Update EV Lab submodule: SSO timeout feature"
git push origin main
```

#### 3.3 Syncing Integration Changes

**When to merge `integration` → `dev` or `main`:**

```bash
# CDS: Merge integration features to dev when stable
cd /Volumes/Dev/CDS_Lab_Integration/cds
git checkout dev
git merge integration --no-ff -m "Merge integration branch: Lab platform features"

# Run tests
npm test

# If tests pass
git push origin dev

# Eventually merge to main for release
git checkout main
git merge dev --no-ff -m "Release v2.0.0: Lab integration support"
git tag v2.0.0
git push origin main --tags
```

---

## Feature Flag Strategy

Ensure integration features don't break standalone usage.

### CDS Backend (.env)

```env
# Integration feature flags (default: disabled)
ENABLE_LAB_INTEGRATION=false
EV_LAB_API_URL=
EV_LAB_API_KEY=

# When enabled for integration
ENABLE_LAB_INTEGRATION=true
EV_LAB_API_URL=http://ev-lab-api-gateway:8000
EV_LAB_API_KEY=<secret>
```

### CDS Code (backend/src/routes/lab-integration.routes.ts)

```typescript
// Only register integration routes if enabled
if (process.env.ENABLE_LAB_INTEGRATION === 'true') {
  app.use('/api/integrations', labIntegrationRoutes);
  console.log('✅ Lab integration enabled');
} else {
  console.log('⏭️  Lab integration disabled');
}
```

### EV Lab API (.env)

```env
# CDS integration feature flags (default: disabled)
ENABLE_CDS_INTEGRATION=false
CDS_API_URL=
CDS_API_KEY=
JWT_SECRET=

# When enabled for integration
ENABLE_CDS_INTEGRATION=true
CDS_API_URL=http://cds-backend:3001
CDS_API_KEY=<secret>
JWT_SECRET=<shared-secret>
```

### EV Lab Code (docker/api-gateway/main.py)

```python
# Only register SSO routes if enabled
if os.getenv("ENABLE_CDS_INTEGRATION") == "true":
    app.include_router(sso_routes.router)
    app.include_router(cds_integration_routes.router)
    logger.info("✅ CDS integration enabled")
else:
    logger.info("⏭️  CDS integration disabled")
```

---

## SDK Distribution Strategy

The SDKs should be publishable/installable independently.

### Python SDK (for EV Lab)

**Option A: Include in EV Lab repo (Current)**
```bash
# Already in labs/ev-lab/sdk/python/cds_lab_sdk.py
# Imported as: from sdk.python.cds_lab_sdk import CDSLabSDK
```

**Option B: Separate PyPI package (Future)**
```bash
# Create separate repo: CDS_Lab_SDK_Python
# Publish to PyPI
pip install cds-lab-sdk

# Import in EV Lab
from cds_lab_sdk import CDSLabSDK
```

### TypeScript SDK (for future labs)

**Option A: Include in integration workspace**
```bash
# Available at labs/ev-lab/sdk/typescript/cds-lab-sdk.ts
# Copy to new lab projects
```

**Option B: Separate npm package (Future)**
```bash
# Publish to npm
npm install @cds/lab-sdk

# Import in new lab frontend
import { CDSLabSDK } from '@cds/lab-sdk';
```

---

## Deployment Strategies

### Strategy 1: Integrated Deployment (Current)

```bash
# Clone integration workspace
git clone --recursive https://github.com/MMSK-SBrain/CDS_Lab_Integration.git
cd CDS_Lab_Integration

# Setup environment
cp .env.example .env
# Edit .env with secrets

# Start all services
./scripts/start.sh

# Access:
# CDS: http://localhost:3010
# EV Lab: http://localhost:3020
```

### Strategy 2: Standalone CDS Deployment

```bash
# Clone CDS repo only (main branch - no integration)
git clone https://github.com/MMSK-SBrain/Lecture_Delivery.git
cd Lecture_Delivery

# Standard CDS setup
cd backend
npm install
npx prisma migrate deploy
npm start

cd ../frontend
npm install
npm run build
npm run preview

# No lab integration features
```

### Strategy 3: Standalone EV Lab Deployment

```bash
# Clone EV Lab repo only (Dev_V0 branch - no CDS integration)
git clone -b Dev_V0 https://github.com/MMSK-SBrain/Integrated_EV_Lab.git
cd Integrated_EV_Lab

# Standard EV Lab setup
docker-compose up -d

# Access: http://localhost:3000
# Users register normally (no SSO)
```

---

## Branching Strategy Summary

| Repository | Branch | Purpose | Integration |
|------------|--------|---------|-------------|
| **Lecture_Delivery** | `main` | Stable CDS release | ❌ No |
| | `dev` | Active CDS development | ⚠️ Optional |
| | `integration` | Integration features | ✅ Yes |
| **Integrated_EV_Lab** | `Dev_V0` | Stable EV Lab release | ❌ No |
| | `obe-brainstorming` | OBE feature development | ⚠️ Optional |
| | `integration` | Integration features | ✅ Yes |
| **CDS_Lab_Integration** | `main` | Integration workspace | ✅ Yes (submodules) |

---

## Testing Strategy

### Test Standalone Mode (CI/CD)

**CDS CI Pipeline:**
```yaml
# .github/workflows/ci.yml (in Lecture_Delivery repo)
name: CDS CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      ENABLE_LAB_INTEGRATION: false  # Test without integration
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test
      - name: Coverage
        run: npm run test:coverage
```

**EV Lab CI Pipeline:**
```yaml
# .github/workflows/ci.yml (in Integrated_EV_Lab repo)
name: EV Lab CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      ENABLE_CDS_INTEGRATION: false  # Test without integration
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: pytest
```

### Test Integration Mode (CI/CD)

**Integration Workspace CI:**
```yaml
# .github/workflows/integration-ci.yml (in CDS_Lab_Integration repo)
name: Integration CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive  # Clone submodules

      - name: Setup environment
        run: |
          cp .env.example .env
          # Set test secrets

      - name: Start services
        run: ./scripts/start.sh

      - name: Wait for services
        run: |
          timeout 60 bash -c 'until curl -f http://localhost:3011/health; do sleep 2; done'
          timeout 60 bash -c 'until curl -f http://localhost:8010/health; do sleep 2; done'

      - name: Run integration tests
        run: |
          # Test SSO flow
          cd tests/integration
          pytest test_sso_flow.py
          pytest test_result_submission.py

      - name: Cleanup
        run: ./scripts/stop.sh
```

---

## Migration Path

### Step 1: Commit Current Changes ✅

```bash
# CDS
cd /Volumes/Dev/CDS_Lab_Integration/cds
git checkout -b integration dev
git add <integration-files>
git commit -m "feat: Add lab integration"
git push -u origin integration

# EV Lab
cd /Volumes/Dev/CDS_Lab_Integration/labs/ev-lab
git checkout -b integration obe-brainstorming
git add <integration-files>
git commit -m "feat: Add CDS integration"
git push -u origin integration
```

### Step 2: Create Workspace Repo ✅

```bash
cd /Volumes/Dev/CDS_Lab_Integration
git init
# Add submodules
# Commit workspace files
# Push to GitHub
```

### Step 3: Update Documentation ✅

```bash
# Add this strategy document to workspace
git add INTEGRATION_STRATEGY.md
git commit -m "docs: Add integration strategy"

# Update README files in each repo
cd cds
# Edit README.md to mention integration branch
git commit -m "docs: Add integration branch info"

cd ../labs/ev-lab
# Edit README.md to mention integration branch
git commit -m "docs: Add integration branch info"
```

### Step 4: Validate ✅

```bash
# Test cloning from scratch
cd /tmp
git clone --recursive https://github.com/MMSK-SBrain/CDS_Lab_Integration.git
cd CDS_Lab_Integration
./scripts/setup.sh
./scripts/start.sh
# Verify all services work
```

---

## Benefits Summary

✅ **Independent Development**
- CDS and EV Lab can be developed separately
- No coupling between repos
- Different release cycles

✅ **Independent Deployment**
- Each platform can run standalone
- Feature flags disable integration when not needed
- No extra dependencies in standalone mode

✅ **Clean Integration**
- Integration workspace tracks orchestration
- Submodules point to specific commits
- Clear separation of concerns

✅ **Version Control**
- All integration changes tracked
- Rollback to any previous integration state
- Submodule SHAs act as "lock file"

✅ **Scalability**
- Easy to add more lab platforms
- Each lab can have its own integration branch
- SDK can be reused across labs

---

## Future Enhancements

1. **SDK as Separate Package**
   - Publish `cds-lab-sdk` to PyPI and npm
   - Versioned independently
   - Easier to update across labs

2. **Integration Tests in Workspace**
   - Add `tests/integration/` directory
   - E2E tests for complete SSO flow
   - Automated in CI/CD

3. **Multi-Lab Support**
   - Add Chemistry Lab, Physics Lab, etc.
   - Each as a submodule with integration branch
   - Reuse same SSO and webhook patterns

4. **Configuration Management**
   - Use `docker-compose.override.yml` for local dev
   - Kubernetes manifests for production
   - Helm charts for easy deployment

---

## Questions & Decisions

### Q: Should integration branches merge back to main?
**A:** Yes, when integration features are stable and well-tested. Use feature flags to ensure backward compatibility.

### Q: What if someone clones CDS `main` branch?
**A:** They get standalone CDS with no integration code. Integration code only exists in `integration` branch.

### Q: How to handle breaking changes in CDS that affect integration?
**A:**
1. Make changes in CDS `integration` branch first
2. Test in integration workspace
3. Update EV Lab integration branch if needed
4. Then merge to CDS `main`

### Q: Can we deploy only EV Lab from the workspace?
**A:** Yes! Modify `docker-compose.yml` to comment out CDS services, or create `docker-compose.evlab-only.yml`.

---

## Conclusion

This strategy provides:
- **Separation**: Independent repos, independent development
- **Integration**: Clean orchestration via workspace repo
- **Flexibility**: Deploy together or separately
- **Safety**: Feature flags prevent breaking changes
- **Scalability**: Easy to add more lab platforms

**Next Steps:**
1. Review and approve this strategy
2. Create `integration` branches in both repos
3. Create `CDS_Lab_Integration` workspace repo on GitHub
4. Follow migration path (Steps 1-4)
5. Update team documentation
