# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CDS-EV Lab Integration Workspace** - Integration platform combining Reynlab CDS (Content Delivery System) with EV Lab (Battery Lab V3) using a hub-and-spoke architecture. This workspace runs both platforms with different ports from their demo environments, enabling seamless SSO authentication, experiment execution, and result synchronization.

### Core Architecture

**Hub-and-Spoke Pattern with Federated Multi-Tenancy**:
```
CDS (Hub) → Generates SSO tokens → EV Lab (Spoke)
CDS (Hub) ← Receives results via webhook ← EV Lab (Spoke)
```

- **CDS**: Content delivery platform (Node.js + Express + Prisma + PostgreSQL)
- **EV Lab**: Battery simulation platform (Python + FastAPI + PyBaMM + PostgreSQL)
- **Integration Layer**: JWT-based SSO + Webhook-based result sync
- **Multi-Tenant Mapping**: CDS Organizations ↔ EV Lab Institutions

## Quick Command Reference

### Stack Management
```bash
# Start entire integration stack
cd /Volumes/Dev/CDS_Lab_Integration
./scripts/start.sh

# Stop all services
./scripts/stop.sh

# View logs (all services)
./scripts/logs.sh

# View specific service logs
./scripts/logs.sh cds-backend
./scripts/logs.sh ev-lab-api-gateway

# Initial setup (first time only)
./scripts/setup.sh
```

### Service Access Points
- **CDS Frontend**: http://localhost:3010
- **CDS Backend**: http://localhost:3011
- **EV Lab Frontend**: http://localhost:3020
- **EV Lab API**: http://localhost:8010

### Health Checks
```bash
# CDS health
curl http://localhost:3011/health

# EV Lab health
curl http://localhost:8010/health

# Check all services
cd infrastructure && docker-compose ps
```

### Database Operations
```bash
# CDS database (PostgreSQL on port 5433)
docker-compose exec cds-db psql -U cds_user -d cds_integration

# EV Lab database (PostgreSQL on port 5434)
docker-compose exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration

# Reset CDS database (warning: deletes data)
docker-compose down cds-db -v
docker-compose up -d cds-db
docker-compose exec cds-backend npm run prisma:migrate

# Reset EV Lab database (warning: deletes data)
docker-compose down ev-lab-db -v
docker-compose up -d ev-lab-db
docker-compose exec ev-lab-api-gateway alembic upgrade head
```

## Technology Stack

### CDS Platform (Instructor-Centric Delivery)
- **Backend**: Node.js 18+ + TypeScript + Express + Prisma ORM
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS
- **Database**: PostgreSQL 15 (port 5433)
- **Cache**: Redis 7 (port 6380)
- **Testing**: Jest + Supertest (270+ tests, 86.53% coverage)
- **Multi-Tenancy**: Row-level tenancy with organizationId scope

**Key CDS Scripts**:
```bash
# CDS Backend (inside container or locally)
cd cds/backend
npm run dev                    # Start dev server
npm test                       # Run all tests
npm run test:integration       # Integration tests only
npx prisma studio              # Database GUI
npx prisma migrate dev         # Create migration

# CDS Frontend
cd cds/frontend
npm run dev                    # Vite dev server
npm run build                  # Production build
npm run lint                   # ESLint
```

### EV Lab Platform (Battery Simulation)
- **API Gateway**: Python 3.10+ + FastAPI + SQLAlchemy 2.0 + Alembic
- **Frontend**: Next.js 14 + TypeScript + Zustand + Tailwind CSS
- **Simulation Engines**:
  - PyBaMM (port 8011) - Cell-level battery simulation
  - EV_sim (port 8012) - Vehicle dynamics simulation
  - liionpack (port 8013) - Pack-level simulation
  - Motor simulator (client-side Web Worker)
  - Charging simulator (WebSocket state machine)
- **Database**: PostgreSQL 15 (port 5434)
- **Cache**: Redis 7 (port 6381)
- **Testing**: Pytest with async support
- **Multi-Tenancy**: Institution-based with role hierarchy

**Key EV Lab Scripts**:
```bash
# EV Lab API Gateway (inside container)
docker-compose exec ev-lab-api-gateway pytest
docker-compose exec ev-lab-api-gateway alembic upgrade head

# EV Lab Frontend
cd labs/ev-lab/frontend
npm run dev                    # Next.js dev server
npm run build                  # Production build
npm run type-check             # TypeScript validation
npm run test                   # Playwright E2E tests

# PyBaMM Simulations (inside container)
docker-compose exec pybamm python /app/scripts/basic_discharge.py
docker-compose exec pybamm python /app/scripts/cc_cv_charging.py
```

## Port Mapping

### Integration Ports (Different from Demos)
| Service | Demo Port | Integration Port | Notes |
|---------|-----------|------------------|-------|
| **CDS Frontend** | 3000 | **3010** | React app |
| **CDS Backend** | 3001 | **3011** | Express API |
| **CDS PostgreSQL** | 5432 | **5433** | Database |
| **CDS Redis** | 6379 | **6380** | Cache |
| **EV Lab Frontend** | 3000 | **3020** | Next.js app |
| **EV Lab API** | 8000 | **8010** | FastAPI gateway |
| **EV Lab PostgreSQL** | 5432 | **5434** | Database |
| **EV Lab Redis** | 6379 | **6381** | Cache |
| **PyBaMM** | 8001 | **8011** | Simulation service |
| **EV_sim** | 8002 | **8012** | Vehicle simulation |
| **liionpack** | 8003 | **8013** | Pack simulation |

## Project Structure

```
CDS_Lab_Integration/
├── cds/                        # Cloned from Reynlab_CDS
│   ├── backend/               # Node.js + TypeScript + Prisma
│   │   ├── src/
│   │   │   ├── controllers/   # Request handlers
│   │   │   ├── services/      # Business logic
│   │   │   ├── routes/        # Express routes
│   │   │   ├── middleware/    # Auth, validation
│   │   │   └── __tests__/     # 270+ Jest tests
│   │   ├── prisma/            # Database schema
│   │   └── package.json       # Backend dependencies
│   └── frontend/              # React + TypeScript + Vite
│       ├── src/
│       │   ├── pages/         # 19 page components
│       │   ├── components/    # 22 reusable components
│       │   ├── services/      # 14 API services
│       │   └── contexts/      # Auth, WebSocket contexts
│       └── package.json       # Frontend dependencies
│
├── labs/
│   └── ev-lab/                # Cloned from Integrated_EV_Lab
│       ├── docker/
│       │   ├── api-gateway/   # FastAPI + SQLAlchemy
│       │   │   ├── routes/    # Modular FastAPI routes
│       │   │   ├── schemas/   # Pydantic validation
│       │   │   ├── services/  # Business logic
│       │   │   ├── alembic/   # Database migrations
│       │   │   └── main.py    # FastAPI app
│       │   ├── pybamm/        # PyBaMM simulation service
│       │   │   └── scripts/   # Experiment scripts
│       │   ├── ev_sim/        # Vehicle simulation (submodule)
│       │   ├── liionpack/     # Pack simulation service
│       │   └── charger-sim/   # Charging simulator
│       ├── frontend/          # Next.js + TypeScript
│       │   ├── src/
│       │   │   ├── app/       # Next.js App Router
│       │   │   ├── components/ # Educational components
│       │   │   ├── stores/    # Zustand state management
│       │   │   └── workers/   # Motor simulation worker
│       │   └── package.json
│       ├── sdk/               # Integration SDKs
│       │   ├── python/        # CDS Lab SDK (Python)
│       │   └── typescript/    # CDS Lab SDK (TypeScript)
│       └── tests/             # Pytest test suite
│
├── infrastructure/            # Docker Compose orchestration
│   └── docker-compose.yml     # Full stack configuration
│
├── scripts/                   # Management scripts
│   ├── setup.sh              # Initial setup
│   ├── start.sh              # Start all services
│   ├── stop.sh               # Stop all services
│   ├── logs.sh               # View logs
│   └── sync-repos.sh         # Sync from demos (⚠️ overwrites)
│
├── docs/                      # Integration documentation
│   ├── CDS_INTEGRATION_ARCHITECTURE.md
│   ├── SETUP.md
│   ├── PHASE_2_DATABASE_INTEGRATION.md
│   └── DATABASE_MIGRATION_GUIDE.md
│
├── README.md                  # Main documentation
├── QUICKSTART.md             # 5-minute setup guide
└── .env                      # Environment secrets (never commit)
```

## Integration Architecture

### SSO Authentication Flow
1. Student clicks "Launch Lab" in CDS
2. CDS generates JWT token with `{ studentId, organizationId, sessionId }`
3. CDS redirects to EV Lab: `http://localhost:3020/sso/login?token=<JWT>`
4. EV Lab validates token using shared `JWT_SECRET`
5. EV Lab creates session and auto-logs in student
6. Student completes experiment in EV Lab

**CDS Backend (Token Generation)**:
```typescript
// cds/backend/src/controllers/lab.controller.ts
const token = jwt.sign({
  studentId: student.id,
  organizationId: batch.organizationId,
  sessionId: session.id,
  exerciseId: 'basic_discharge'
}, process.env.JWT_SECRET, { expiresIn: '1h' });

// Redirect URL
const labUrl = `${EV_LAB_BASE_URL}/sso/login?token=${token}`;
```

**EV Lab API (Token Validation)**:
```python
# labs/ev-lab/docker/api-gateway/routes/sso_routes.py
from sdk.python.cds_lab_sdk import CDSLabSDK

sdk = CDSLabSDK(
    api_key=os.getenv("CDS_API_KEY"),
    webhook_url=os.getenv("CDS_WEBHOOK_URL"),
    jwt_secret=os.getenv("JWT_SECRET_KEY")
)

# Validate SSO token
session = await sdk.validate_sso_token(token)
# Returns: { student_id, organization_id, session_id, exercise_id }
```

### Result Synchronization Flow
1. Student completes experiment in EV Lab
2. EV Lab sends results to CDS webhook: `POST /api/integrations/lab-results`
3. CDS validates API key and stores result
4. CDS updates student progress and compliance tracking

**EV Lab Backend (Submit Results)**:
```python
# labs/ev-lab/docker/api-gateway/routes/cds_integration_routes.py
await sdk.submit_result({
    "exerciseId": "basic_discharge",
    "sessionId": session.session_id,
    "studentId": session.student_id,
    "status": "completed",
    "score": 85.5,
    "maxScore": 100.0,
    "data": {
        "voltage_data": [...],
        "temperature_data": [...]
    }
})
```

**CDS Backend (Receive Results)**:
```typescript
// cds/backend/src/controllers/integration.controller.ts
router.post('/api/integrations/lab-results', async (req, res) => {
  // Validate API key
  // Store result in LabExerciseResult table
  // Update student progress
  // Update session compliance
});
```

### Multi-Tenant Mapping
| CDS Entity | EV Lab Entity | Mapping Logic |
|------------|---------------|---------------|
| Organization | Institution | `cds_organization_id` stored in EV Lab Institution |
| Student | User (role: student) | `cds_student_id` stored in EV Lab User |
| Session | Lab Session | `cds_session_id` linked to experiment progress |
| Batch | N/A | Batch context provided via JWT, not persisted in EV Lab |

## Environment Variables

### Required Secrets (`.env` in root directory)

**Shared Secrets**:
```env
JWT_SECRET=<32-char-secret>              # Must be same in CDS and EV Lab
```

**CDS Configuration**:
```env
CDS_DB_NAME=cds_integration
CDS_DB_USER=cds_user
CDS_DB_PASSWORD=<secure-password>
EV_LAB_BASE_URL=http://localhost:3020   # Frontend URL
EV_LAB_API_URL=http://ev-lab-api-gateway:8000  # Internal Docker URL
EV_LAB_API_KEY=<32-char-api-key>        # For webhooks
```

**EV Lab Configuration**:
```env
EV_LAB_DB_NAME=ev_lab_integration
EV_LAB_DB_USER=ev_lab_user
EV_LAB_DB_PASSWORD=<secure-password>
CDS_BASE_URL=http://cds-backend:3001    # Internal Docker URL
CDS_API_KEY=<32-char-api-key>           # For result submission
CDS_WEBHOOK_URL=http://cds-backend:3001/api/integrations/lab-results
ENABLE_CDS_INTEGRATION=true
```

**Generate Secure Secrets**:
```bash
openssl rand -base64 32  # For JWT_SECRET
openssl rand -base64 32  # For EV_LAB_API_KEY
openssl rand -base64 32  # For CDS_API_KEY
openssl rand -base64 24  # For DB passwords
```

## Development Workflow

### Daily Development
```bash
# 1. Start services
cd /Volumes/Dev/CDS_Lab_Integration
./scripts/start.sh

# 2. Develop in respective directories
# CDS: Edit files in cds/backend or cds/frontend
# EV Lab: Edit files in labs/ev-lab

# 3. Hot reload works automatically
# - CDS Backend: Nodemon watches TypeScript files
# - CDS Frontend: Vite hot module replacement
# - EV Lab API: FastAPI auto-reload
# - EV Lab Frontend: Next.js Fast Refresh

# 4. View logs
./scripts/logs.sh

# 5. Stop when done
./scripts/stop.sh
```

### Testing Integration Flow
```bash
# 1. Start stack
./scripts/start.sh

# 2. Seed test data (creates test organization and students)
cd cds/backend && npm run seed:test

# 3. Test SSO flow
# - Login to CDS at http://localhost:3010
# - Navigate to batch details
# - Click "Launch Lab" for a student
# - Should auto-login to EV Lab at http://localhost:3020

# 4. Complete experiment in EV Lab
# - Run basic_discharge experiment
# - Check results sent to CDS

# 5. Verify results in CDS
# - Check session compliance updated
# - Check student progress reflected
```

### Syncing from Demo Repos
```bash
# ⚠️ WARNING: This overwrites local changes
# Commit your work first!

git add . && git commit -m "WIP: save before sync"

# Sync from original repos
./scripts/sync-repos.sh

# Review changes
git diff HEAD~1

# If needed, revert
git reset --hard HEAD~1
```

### Docker Troubleshooting
```bash
# Rebuild specific service
cd infrastructure
docker-compose build --no-cache cds-backend
docker-compose up -d cds-backend

# Full reset (deletes all data)
docker-compose down -v
docker-compose up -d

# Check container logs
docker logs -f cds-backend-integration
docker logs -f ev-lab-api-integration

# Exec into container
docker-compose exec cds-backend sh
docker-compose exec ev-lab-api-gateway bash

# Check resource usage
docker stats
```

## Database Schema Overview

### CDS Database Models (Prisma)
**Core Entities**:
- `Organization` - Training institutions (multi-tenant root)
- `Instructor` - Teachers with location assignments
- `Batch` - Student cohorts with multi-course support
- `Student` - End users with auto-generated roll numbers
- `Session` - Lecture/lab sessions with compliance tracking

**Integration Models** (NEW):
- `LabPlatform` - External lab registry (EV Lab, future labs)
- `LabExerciseLink` - Session → Lab exercise mapping
- `LabExerciseResult` - Student lab results from external platforms

**Key Relationships**:
```
Organization → Instructor, Batch, Student
Batch → BatchCourse (many-to-many with Course)
Session → LabExerciseLink → LabPlatform
Student → LabExerciseResult (from external labs)
```

### EV Lab Database Models (SQLAlchemy)
**Core Entities**:
- `Institution` - Educational institutions (multi-tenant root)
- `User` - Multi-role users (super_admin, institution_admin, instructor, student)
- `ExperimentProgress` - Tracks student progress across experiments
- `LabSession` - Experiment execution records

**Integration Fields** (NEW):
- `Institution.cds_organization_id` - Maps to CDS Organization
- `User.cds_student_id` - Maps to CDS Student
- `LabSession.cds_session_id` - Links to CDS Session

## API Endpoints

### CDS Backend (port 3011)

**Integration Endpoints**:
- `POST /api/integrations/lab/launch` - Generate SSO token and redirect URL
- `POST /api/integrations/lab-results` - Receive results from lab (API key auth)
- `GET /api/integrations/lab-platforms` - List registered lab platforms

**Core Endpoints**:
- `POST /api/auth/register` - Register instructor
- `POST /api/auth/login` - Login with JWT
- `GET /api/batches` - List batches (organizationId filtered)
- `POST /api/sessions` - Create session
- `GET /api/students/:id/progress` - Student progress summary

### EV Lab API (port 8010)

**Integration Endpoints**:
- `GET /api/sso/login?token=<JWT>` - SSO login endpoint
- `POST /api/cds/results` - Submit results to CDS (internal use)

**Core Endpoints**:
- `POST /api/auth/register` - Register user
- `POST /api/auth/login` - Login with JWT
- `POST /api/experiments/execute` - Run PyBaMM experiment
- `POST /api/vehicle/simulate` - Run EV_sim simulation
- `POST /api/pack/simulate` - Run liionpack simulation
- `GET /api/progress` - Get experiment progress

## Testing

### CDS Testing
```bash
cd cds/backend

# Run all tests (270+ tests)
npm test

# Run with coverage (86.53% coverage)
npm test -- --coverage

# Run specific test suite
npm test auth.test
npm test integration.test

# Run tests in watch mode
npm run test:watch
```

### EV Lab Testing
```bash
cd labs/ev-lab

# Run all pytest tests
pytest

# Run with coverage
pytest --cov

# Run specific test categories
pytest -m "unit"
pytest -m "integration"

# Run E2E tests (Playwright)
cd frontend
npm run test              # Run all E2E tests
npm run test:ui           # UI mode
npm run test:debug        # Debug mode
```

## Key Configuration Files

### Docker Compose
- `infrastructure/docker-compose.yml` - Full stack orchestration
- Defines 10 services: CDS (4 services) + EV Lab (6 services)
- Health checks for all services
- Volume mounts for hot reload
- Network: `cds-lab-network` (bridge)

### CDS Configuration
- `cds/backend/prisma/schema.prisma` - Database schema (12 models)
- `cds/backend/package.json` - Dependencies and scripts
- `cds/frontend/package.json` - Frontend dependencies
- `cds/backend/tsconfig.json` - TypeScript strict mode

### EV Lab Configuration
- `labs/ev-lab/docker/api-gateway/requirements.txt` - Python dependencies
- `labs/ev-lab/docker/config/experiments.yaml` - 50+ experiments
- `labs/ev-lab/docker/config/chemistries.yaml` - NMC, LFP configs
- `labs/ev-lab/frontend/package.json` - Next.js dependencies
- `labs/ev-lab/pytest.ini` - Pytest configuration

## Best Practices

### Code Quality
1. **Always write tests first** (TDD approach for CDS)
2. **Run type-check before commits** (`npm run type-check` in frontends)
3. **Multi-tenant queries**: Always filter by `organizationId` (CDS) or `institution_id` (EV Lab)
4. **Validate API keys**: All webhook endpoints must validate API keys
5. **Use TypeScript strict mode**: Both platforms enforce strict typing

### Security
1. **Never commit `.env`** - Contains production secrets
2. **Rotate API keys regularly** - Use 32+ character keys
3. **Validate JWT tokens** - Check expiry and signature
4. **Scope database queries** - Always filter by tenant ID
5. **Use HTTPS in production** - Enable TLS for all external communication

### Performance
1. **Use Redis caching** - Both platforms have Redis for caching
2. **Implement pagination** - All list endpoints should paginate
3. **Optimize database queries** - Use indexes, avoid N+1 queries
4. **Monitor container resources** - `docker stats` for resource usage

### Integration
1. **Idempotent webhooks** - Handle duplicate result submissions
2. **Retry logic** - Implement exponential backoff for webhook failures
3. **Graceful degradation** - CDS should work if EV Lab is down
4. **Audit logging** - Log all SSO logins and result submissions

## Troubleshooting

### Port Conflicts
```bash
# Check what's using a port
lsof -i :3010

# Kill process
kill -9 <PID>

# Or change port in docker-compose.yml
```

### Database Connection Errors
```bash
# Check database is running
docker-compose ps cds-db ev-lab-db

# Restart database
docker-compose restart cds-db

# Reset database (warning: deletes data)
docker-compose down cds-db -v
docker-compose up -d cds-db
```

### JWT Token Validation Fails
```bash
# Verify JWT_SECRET is same in both platforms
docker-compose exec cds-backend env | grep JWT_SECRET
docker-compose exec ev-lab-api-gateway env | grep JWT_SECRET

# Should be identical!
```

### Results Not Syncing
```bash
# Check CDS webhook URL is correct
docker-compose exec ev-lab-api-gateway env | grep CDS_WEBHOOK_URL

# Check API key is valid
docker-compose exec cds-backend env | grep EV_LAB_API_KEY
docker-compose exec ev-lab-api-gateway env | grep CDS_API_KEY

# View webhook logs
docker logs -f ev-lab-api-integration | grep "CDS webhook"
docker logs -f cds-backend-integration | grep "lab-results"
```

### Hot Reload Not Working
```bash
# Check volume mounts in docker-compose.yml
docker-compose config | grep volumes

# Restart service
docker-compose restart cds-backend

# Full rebuild
docker-compose build --no-cache cds-backend
docker-compose up -d cds-backend
```

## References

### Documentation
- **Main README**: `README.md` - Complete integration overview
- **Quick Start**: `QUICKSTART.md` - 5-minute setup guide
- **Architecture**: `docs/CDS_INTEGRATION_ARCHITECTURE.md` - Detailed design
- **Setup Guide**: `docs/SETUP.md` - Step-by-step setup
- **Phase 2 Guide**: `docs/PHASE_2_DATABASE_INTEGRATION.md` - Database integration

### Individual Platform Docs
- **CDS CLAUDE.md**: `cds/CLAUDE.md` - CDS-specific development guide
- **EV Lab CLAUDE.md**: `labs/ev-lab/CLAUDE.md` - EV Lab-specific guide
- **Integration SDKs**: `labs/ev-lab/sdk/README.md` - SDK documentation

### External Resources
- [Prisma Docs](https://www.prisma.io/docs/) - CDS ORM
- [FastAPI Docs](https://fastapi.tiangolo.com/) - EV Lab API framework
- [PyBaMM Docs](https://docs.pybamm.org/) - Battery simulation
- [Next.js Docs](https://nextjs.org/docs) - EV Lab frontend framework

## Working with Claude Code

When asking for help:

1. **Specify the platform**: "In CDS backend..." or "In EV Lab API..."
2. **Reference existing patterns**: "Follow the same pattern as auth.test.ts in CDS"
3. **Request incremental changes**: "First add the service layer, then controller"
4. **Provide context**: "This is multi-tenant - filter by organizationId"
5. **Ask for integration tests**: "Test the complete SSO flow from CDS to EV Lab"

Example prompts:

```
"I need to implement SSO token generation in CDS backend.
Reference the existing JWT implementation in src/middleware/auth.middleware.ts.
Create a service method that generates a token with studentId, organizationId,
sessionId, and exerciseId. Add comprehensive tests first (TDD approach)."
```

```
"I need to add result submission webhook in CDS backend.
Create a new integration controller that:
1. Validates EV_LAB_API_KEY from headers
2. Accepts result payload with exerciseId, sessionId, studentId, score
3. Stores result in LabExerciseResult table
4. Updates session compliance
Include tests for authentication, validation, and happy path."
```

## Important Notes

- **Demo environments remain untouched**: This workspace runs on different ports
- **Never commit secrets**: `.env` is in `.gitignore`
- **Multi-tenant isolation**: Always filter queries by organization/institution
- **Sync carefully**: `./scripts/sync-repos.sh` overwrites local changes
- **Test before deploying**: Run full test suites for both platforms
