# CDS-EV Lab Integration: Brownfield Architecture Document

**Version:** 1.0
**Date:** December 30, 2025
**Status:** Current State Documentation
**Purpose:** Comprehensive guide for building and testing new features

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Executive Summary](#executive-summary)
3. [High-Level Architecture](#high-level-architecture)
4. [Source Tree & Module Organization](#source-tree--module-organization)
5. [Component Deep-Dives](#component-deep-dives)
6. [Integration Flows](#integration-flows)
7. [Database Architecture](#database-architecture)
8. [API Endpoints Reference](#api-endpoints-reference)
9. [Development Workflows](#development-workflows)
10. [Testing Strategies](#testing-strategies)
11. [Troubleshooting Guide](#troubleshooting-guide)

---

## Quick Reference

### Critical Files for Feature Development

**Integration Entry Points:**
- **CDS SSO Token Generation**: `cds/backend/src/routes/lab-integration.routes.ts:449` (POST `/api/integrations/lab-platforms/:platformId/sso-token`)
- **CDS Webhook Receiver**: `cds/backend/src/routes/lab-integration.routes.ts:128` (POST `/api/integrations/lab-results`)
- **EV Lab SSO Handler**: `labs/ev-lab/docker/api-gateway/routes/sso_routes.py:29` (GET `/api/sso/login`)
- **EV Lab Result Submitter**: `labs/ev-lab/docker/api-gateway/routes/cds_integration_routes.py:230` (POST `/api/cds-integration/submit-result`)

**Database Schemas:**
- **CDS Models**: `cds/backend/prisma/schema.prisma` (12 models including LabPlatform, LabExerciseLink, LabExerciseResult)
- **EV Lab Models**: `labs/ev-lab/docker/api-gateway/database/models.py` (Institution, User, UserSSOMapping, etc.)

**Integration SDKs:**
- **Python SDK**: `labs/ev-lab/sdk/python/cds_lab_sdk.py` (650 lines, complete with retry logic)
- **TypeScript SDK**: `labs/ev-lab/sdk/typescript/cds-lab-sdk.ts` (600+ lines)

**Configuration:**
- **Environment Template**: `.env.example` (complete with all integration variables)
- **Docker Orchestration**: `infrastructure/docker-compose.yml` (10 services, full stack)
- **Management Scripts**: `scripts/` (setup.sh, start.sh, stop.sh, logs.sh, sync-repos.sh, seed_test_data.sh)

### Service Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **CDS Frontend** | http://localhost:3010 | Instructor UI, session management |
| **CDS Backend** | http://localhost:3011 | REST API, webhooks, SSO token generation |
| **EV Lab Frontend** | http://localhost:3020 | Student lab interface |
| **EV Lab API Gateway** | http://localhost:8010 | Experiment orchestration, SSO validation |
| **PyBaMM Simulator** | http://localhost:8011 | Battery cell simulations |
| **EV_sim** | http://localhost:8012 | Vehicle dynamics simulations |
| **liionpack** | http://localhost:8013 | Battery pack simulations |
| **CDS PostgreSQL** | localhost:5433 | CDS data (organizations, students, sessions) |
| **EV Lab PostgreSQL** | localhost:5434 | EV Lab data (institutions, users, experiments) |
| **CDS Redis** | localhost:6380 | CDS caching |
| **EV Lab Redis** | localhost:6381 | Experiment result caching |

### Health Check Commands

```bash
# All services status
cd infrastructure && docker-compose ps

# Individual service health checks
curl http://localhost:3011/health          # CDS Backend
curl http://localhost:8010/health          # EV Lab API
curl http://localhost:8010/api/sso/health  # SSO integration status

# Database connections
docker-compose exec cds-db psql -U cds_user -d cds_integration -c "SELECT COUNT(*) FROM organizations;"
docker-compose exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c "SELECT COUNT(*) FROM institutions;"
```

---

## Executive Summary

### What This System Does

The **CDS-EV Lab Integration** is a production-ready platform that enables seamless **Single Sign-On (SSO)** and **result synchronization** between:

1. **Reynlab CDS (Content Delivery System)** - Instructor-centric training platform (Node.js/TypeScript)
2. **EV Lab (Battery Lab V3)** - Educational battery simulation platform (Python/FastAPI)

**Key Integration Capabilities:**
- ✅ **SSO Authentication**: Students launch from CDS → auto-login to EV Lab (JWT-based, 30-min expiry)
- ✅ **Result Sync**: Experiment results from EV Lab → CDS via webhook (retry logic, idempotent)
- ✅ **Multi-Tenant Isolation**: Organization (CDS) ↔ Institution (EV Lab) mapping with row-level tenancy
- ✅ **Extensible Architecture**: Hub-and-spoke pattern supports multiple lab platforms

### Hub-and-Spoke Architecture

```
┌─────────────────────────────────────────────────────────┐
│         CDS (Hub) - Port 3010/3011                      │
│  - SSO Token Generation (JWT)                           │
│  - Lab Platform Registry (LabPlatform table)            │
│  - Result Webhook Receiver                              │
│  - Progress Tracking Aggregation                        │
│  Multi-Tenant: Organizations → Batches → Students       │
└──────┬──────────────────────┬───────────────────────────┘
       │                      │
   SSO Launch            Webhook Results
   (JWT Token)           (API Key Auth)
   30-min expiry         3 retries w/ exp backoff
       │                      │
       ▼                      ▼
┌──────────────────┐    ┌────────────────────────────┐
│   EV Lab (Spoke) │    │  Future Lab Platforms      │
│   Port 3020/8010 │    │  (Engine Lab, Solder Lab)  │
│  - SSO Validation│    │  Same Integration Pattern   │
│  - Simulations   │    │  - SSO endpoint            │
│  - Result Submit │    │  - Webhook submission      │
│  Multi-Tenant:   │    │  - SDK integration         │
│  Institutions    │    └────────────────────────────┘
└──────────────────┘
```

### Current Implementation Status

| Component | Status | Coverage | Notes |
|-----------|--------|----------|-------|
| **SSO Authentication** | ✅ Complete | 100% | JWT validation, user auto-provisioning |
| **Result Synchronization** | ✅ Complete | 100% | Webhook + retry logic via SDK |
| **Multi-Tenant Mapping** | ✅ Complete | 100% | Organization ↔ Institution bidirectional |
| **Database Schemas** | ✅ Complete | 100% | CDS: 12 models + 3 integration; EV Lab: 14 models |
| **Python SDK** | ✅ Complete | 100% | 650 lines, Pydantic validation, retry logic |
| **TypeScript SDK** | ✅ Complete | 100% | 600+ lines (available but not actively used) |
| **Integration Tests** | ⚠️ Partial | ~40% | SSO flow tested; webhook testing incomplete |
| **Dashboard UI** | ⚠️ Partial | ~60% | Backend complete; frontend integration pending |

---

## High-Level Architecture

### Technology Stack Comparison

| Aspect | CDS Platform | EV Lab Platform |
|--------|--------------|-----------------|
| **Backend Language** | TypeScript (Node.js 18+) | Python 3.10+ |
| **Web Framework** | Express.js | FastAPI (async) |
| **ORM** | Prisma 6.17 | SQLAlchemy 2.0 |
| **Frontend** | React 18 + Vite + Tailwind | Next.js 14 + TypeScript + Zustand |
| **Database** | PostgreSQL 15 (port 5433) | PostgreSQL 15 (port 5434) |
| **Cache** | Redis 7 (port 6380) | Redis 7 (port 6381) |
| **Auth** | JWT (jsonwebtoken) | JWT (jose library) |
| **Testing** | Jest + Supertest (270+ tests, 86.53% coverage) | Pytest (async support) |
| **Docker Services** | 4 (frontend, backend, db, redis) | 6 (frontend, api-gateway, pybamm, ev-sim, liionpack, db, redis) |

### Data Flow Patterns

#### Pattern 1: Student Lab Launch (SSO Flow)

```
Student (Browser) → CDS Frontend → CDS Backend → CDS Database
                                       ↓
                                  Generate JWT
                                  (30-min exp)
                                       ↓
                                  Redirect URL
                                       ↓
Student (Browser) → EV Lab Frontend → EV Lab API → Validate JWT
                                          ↓            ↓
                                   Find/Create     Find/Create
                                   Institution      User
                                          ↓            ↓
                                   EV Lab Database (PostgreSQL)
                                          ↓
                                Generate EV Lab Token
                                          ↓
                                   Auto-login Student
```

**Key Files Involved:**
1. `cds/backend/src/routes/lab-integration.routes.ts:449-609` - SSO token generation
2. `labs/ev-lab/docker/api-gateway/routes/sso_routes.py:29-223` - SSO validation
3. `labs/ev-lab/sdk/python/cds_lab_sdk.py:249-290` - JWT validation helper

#### Pattern 2: Result Submission (Webhook Flow)

```
Student Completes Experiment → EV Lab Frontend → EV Lab API
                                                       ↓
                                                Save Locally
                                                (Progress table)
                                                       ↓
                                                 CDS Lab SDK
                                              (submit_result_with_retry)
                                                       ↓
                                                  Retry Logic
                                              (3 attempts, exp backoff)
                                                       ↓
                                     POST /api/integrations/lab-results
                                              (CDS Backend)
                                                       ↓
                                               Validate API Key
                                                       ↓
                                            Find LabExerciseLink
                                                       ↓
                                          Verify Organization Match
                                                       ↓
                                           Upsert LabExerciseResult
                                                       ↓
                                             Success Response
                                                       ↓
                                      EV Lab API (result confirmed)
```

**Key Files Involved:**
1. `labs/ev-lab/docker/api-gateway/routes/cds_integration_routes.py:150-223` - Result submission helper
2. `labs/ev-lab/sdk/python/cds_lab_sdk.py:296-408` - SDK submit_result methods
3. `cds/backend/src/routes/lab-integration.routes.ts:128-292` - Webhook receiver

### Multi-Tenancy Architecture

**CDS Tenancy Model (Row-Level):**
```
Organization (id: UUID)
  └── organizationId (FK in all tables)
      ├── Instructor
      ├── Location
      ├── Batch
      │   └── Student
      │       └── LabExerciseResult
      ├── Session
      │   └── LabExerciseLink
      └── LabPlatform (lab registry)
```

**EV Lab Tenancy Model (Row-Level):**
```
Institution (id: UUID)
  └── institution_id (FK in all tables)
      ├── User (multi-role: student, instructor, admin)
      │   └── sso_mappings (UserSSOMapping)
      │       └── cds_student_id, cds_organization_id
      ├── ExperimentRun
      └── Progress
```

**Tenant Mapping Strategy:**

| CDS Entity | EV Lab Entity | Mapping Field | Location |
|------------|---------------|---------------|----------|
| Organization | Institution | `Institution.cds_organization_id` → `Organization.id` | `labs/ev-lab/docker/api-gateway/database/models.py:36-43` |
| Student | User (role: student) | `UserSSOMapping.cds_student_id` → `Student.id` | `labs/ev-lab/docker/api-gateway/database/models.py:175-180` |
| Session | Lab Session Context | JWT payload (`cds_session_id`) | `labs/ev-lab/sdk/python/cds_lab_sdk.py:78` |

---

## Source Tree & Module Organization

### Integration Workspace Structure

```
/Volumes/Dev/CDS_Lab_Integration/
├── cds/                           # Cloned from Reynlab_CDS
│   ├── backend/                   # Node.js + TypeScript + Prisma
│   │   ├── src/
│   │   │   ├── controllers/       # Request handlers (8 controllers)
│   │   │   ├── services/          # Business logic (8 services)
│   │   │   ├── routes/            # Express routes (12 route files)
│   │   │   │   └── lab-integration.routes.ts ← **KEY: Integration endpoints**
│   │   │   ├── middleware/        # Auth, validation, rate limiting (5 middleware)
│   │   │   ├── types/
│   │   │   │   └── lab-integration.ts ← **KEY: Integration types**
│   │   │   ├── __tests__/         # 270+ Jest tests
│   │   │   ├── db.ts              # Prisma client
│   │   │   ├── redis.ts           # Redis client
│   │   │   └── server.ts          # Express entry point
│   │   ├── prisma/
│   │   │   └── schema.prisma      ← **KEY: 12 models + 3 integration models**
│   │   └── package.json
│   └── frontend/                  # React 18 + Vite + Tailwind
│       ├── src/
│       │   ├── pages/             # 19 page components
│       │   ├── components/        # 22 reusable components
│       │   └── services/          # 14 API client services
│       └── package.json
│
├── labs/
│   └── ev-lab/                    # Cloned from Integrated_EV_Lab
│       ├── docker/
│       │   ├── api-gateway/       # FastAPI + SQLAlchemy
│       │   │   ├── routes/
│       │   │   │   ├── sso_routes.py         ← **KEY: SSO handler**
│       │   │   │   ├── cds_integration_routes.py ← **KEY: Result submission**
│       │   │   │   └── [10 other route files]
│       │   │   ├── database/
│       │   │   │   └── models.py             ← **KEY: 14 SQLAlchemy models**
│       │   │   ├── main.py                   # FastAPI app entry
│       │   │   └── requirements.txt
│       │   ├── pybamm/            # PyBaMM simulation service
│       │   ├── ev_sim/            # Vehicle simulation (git submodule)
│       │   └── liionpack/         # Pack simulation service
│       ├── frontend/              # Next.js 14 + TypeScript
│       │   └── src/
│       │       ├── app/           # Next.js App Router
│       │       ├── components/    # Educational components
│       │       ├── stores/        # Zustand state management
│       │       └── workers/       # Motor simulation Web Worker
│       ├── sdk/                   ← **KEY: Integration SDKs**
│       │   ├── python/
│       │   │   └── cds_lab_sdk.py # 650-line SDK with retry logic
│       │   └── typescript/
│       │       └── cds-lab-sdk.ts # 600+ line SDK
│       └── tests/                 # Pytest test suite
│
├── infrastructure/                ← **KEY: Docker orchestration**
│   └── docker-compose.yml         # 10 services, full stack
│
├── scripts/                       ← **KEY: Management automation**
│   ├── setup.sh                   # Initial setup
│   ├── start.sh                   # Start all services
│   ├── stop.sh                    # Stop all services
│   ├── logs.sh                    # View service logs
│   ├── sync-repos.sh              # Sync from demo repos
│   └── seed_test_data.sh          # Seed integration test data
│
├── docs/                          # Integration documentation
│   ├── CDS_INTEGRATION_ARCHITECTURE.md  # Original design doc
│   ├── SETUP.md
│   ├── PHASE_2_DATABASE_INTEGRATION.md
│   └── DATABASE_MIGRATION_GUIDE.md
│
├── .env.example                   ← **KEY: Environment template**
├── README.md                      # Integration workspace overview
├── QUICKSTART.md                  # 5-minute setup guide
└── CLAUDE.md                      ← **KEY: Development guidance**
```

### Key Module Responsibilities

#### CDS Backend Modules (Node.js/TypeScript)

| Module | Path | Responsibility | Integration Role |
|--------|------|----------------|------------------|
| **Lab Integration Routes** | `src/routes/lab-integration.routes.ts` | SSO token generation, webhook receiver, exercise management | **PRIMARY INTEGRATION ENTRY POINT** |
| **Prisma Schema** | `prisma/schema.prisma` | Database models (Organization, Student, Session, LabPlatform, LabExerciseLink, LabExerciseResult) | Defines integration data structures |
| **Auth Middleware** | `src/middleware/auth.middleware.ts` | JWT validation for CDS users (instructors, students) | **NOT USED FOR LAB SSO** (separate JWT secret) |
| **Validation Middleware** | `src/middleware/validation.middleware.ts` | Request payload validation (Zod schemas) | Used in webhook receiver |

#### EV Lab API Gateway Modules (Python/FastAPI)

| Module | Path | Responsibility | Integration Role |
|--------|------|----------------|------------------|
| **SSO Routes** | `routes/sso_routes.py` | SSO login, token validation, user auto-provisioning | **PRIMARY SSO HANDLER** |
| **CDS Integration Routes** | `routes/cds_integration_routes.py` | Result submission helper, webhook testing | Wrapper around SDK |
| **Database Models** | `database/models.py` | SQLAlchemy 2.0 models (Institution, User, UserSSOMapping, ExperimentRun, Progress) | Multi-tenant data with CDS mapping fields |
| **CDS Lab SDK** | `sdk/python/cds_lab_sdk.py` | Official Python SDK with retry logic, validation | **CORE INTEGRATION LIBRARY** |

---

## Component Deep-Dives

### Component 1: CDS SSO Token Generator

**Location:** `cds/backend/src/routes/lab-integration.routes.ts:449-609`

**Purpose:** Generate JWT tokens for launching students into external lab platforms (EV Lab, future labs).

**How It Works:**

1. **Request Validation** (lines 442-469):
   - Validates `studentId`, `sessionId`, and optional `returnUrl`
   - Uses Zod schema for type-safe validation

2. **Student & Organization Lookup** (lines 476-508):
   ```typescript
   const student = await prisma.student.findUnique({
     where: { id: studentId },
     include: {
       batch: {
         include: {
           instructor: {
             include: {
               organization: {
                 select: {
                   id: true,
                   name: true,
                   evLabInstitutionId: true,
                   evLabEnabled: true,
                   evLabSsoEnabled: true,
                 }
               }
             }
           }
         }
       }
     }
   });
   ```
   - Single query with nested includes for performance
   - Gets organization context for tenant mapping

3. **Feature Flag Check** (lines 511-518):
   - Verifies `organization.evLabEnabled && organization.evLabSsoEnabled`
   - Fails fast if integration not enabled

4. **Lab Platform Verification** (lines 521-544):
   - Looks up registered lab platform by `platformId`
   - Verifies platform is active (`status: 'active'`)
   - Filters by organization (multi-tenant isolation)

5. **JWT Generation** (lines 546-570):
   ```typescript
   const payload = {
     cds_student_id: student.id,
     cds_organization_id: organization.id,
     cds_session_id: sessionId,
     email: student.email || `${student.id}@${organization.name}`,
     name: student.name,
     role: 'student',
     iat: now,
     exp: now + 1800, // 30 minutes
   };
   const token = jwt.sign(payload, jwtSecret);
   ```
   - **Critical:** Uses shared `JWT_SECRET` environment variable
   - **Expiry:** 30 minutes (1800 seconds)
   - **Claims:** Includes both CDS and lab-specific context

6. **SSO URL Construction** (lines 573-575):
   ```typescript
   const ssoUrl = new URL(labPlatform.ssoEndpoint, labPlatform.baseUrl);
   ssoUrl.searchParams.set('token', token);
   ssoUrl.searchParams.set('returnUrl', returnUrl);
   ```
   - Example: `http://localhost:3020/sso/login?token=<JWT>&returnUrl=/experiments/basic_discharge`

**API Contract:**

**Request:**
```http
POST /api/integrations/lab-platforms/ev-lab/sso-token
Content-Type: application/json
Authorization: Bearer <cds-user-jwt>

{
  "studentId": "a1b2c3d4-e5f6-4a5b-8c7d-9e8f7a6b5c4d",
  "sessionId": "f1e2d3c4-b5a6-4c7b-8d9e-0f1a2b3c4d5e",
  "returnUrl": "/experiments/basic_discharge"
}
```

**Response:**
```json
{
  "success": true,
  "message": "SSO token generated successfully",
  "data": {
    "ssoUrl": "http://localhost:3020/sso/login?token=eyJhbGc...&returnUrl=/experiments/basic_discharge",
    "expiresIn": 1800,
    "labPlatform": {
      "id": "lab-platform-uuid",
      "platformId": "ev-lab",
      "name": "Battery Lab V3"
    },
    "token": "eyJhbGc..." // Only in development
  }
}
```

**Testing This Component:**

```bash
# 1. Start services
./scripts/start.sh

# 2. Seed test data (creates organization, student, session)
./scripts/seed_test_data.sh

# 3. Get student ID and session ID from database
docker-compose exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT id, name FROM students LIMIT 1;"
docker-compose exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT id FROM sessions LIMIT 1;"

# 4. Generate SSO token (requires CDS authentication token)
curl -X POST http://localhost:3011/api/integrations/lab-platforms/ev-lab/sso-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <cds-auth-token>" \
  -d '{
    "studentId": "<student-uuid-from-step-3>",
    "sessionId": "<session-uuid-from-step-3>",
    "returnUrl": "/experiments/basic_discharge"
  }'

# 5. Test SSO URL in browser
# Copy ssoUrl from response and paste into browser
# Should redirect to EV Lab and auto-login student
```

---

### Component 2: EV Lab SSO Validator

**Location:** `labs/ev-lab/docker/api-gateway/routes/sso_routes.py:29-223`

**Purpose:** Validate SSO tokens from CDS, auto-provision users, and redirect to lab interface.

**How It Works:**

1. **Token Decoding & Validation** (lines 56-99):
   ```python
   payload = jwt.decode(
       token,
       jwt_secret,
       algorithms=["HS256"]
   )

   required_fields = ["cds_student_id", "cds_organization_id", "email", "name"]
   missing_fields = [field for field in required_fields if field not in payload]
   if missing_fields:
       raise HTTPException(status_code=400, detail=f"Invalid SSO token: missing fields {', '.join(missing_fields)}")
   ```
   - **Critical:** Uses same `JWT_SECRET` as CDS
   - Validates required fields before processing
   - Handles `ExpiredSignatureError` gracefully

2. **Institution Lookup/Creation** (lines 103-122):
   ```python
   result = await db.execute(
       select(Institution).where(
           Institution.cds_organization_id == cds_organization_id,
           Institution.cds_enabled == True,
           Institution.cds_sso_enabled == True,
           Institution.status == "active"
       )
   )
   institution = result.scalar_one_or_none()

   if not institution:
       raise HTTPException(
           status_code=404,
           detail="Institution not registered or SSO not enabled. Contact administrator."
       )
   ```
   - **Tenant Mapping:** Links `cds_organization_id` → `Institution.id`
   - **Feature Flags:** Respects `cds_enabled` and `cds_sso_enabled`
   - **Fail-Safe:** Returns 404 if organization not registered

3. **User Auto-Provisioning** (lines 124-157):
   ```python
   user = result.scalar_one_or_none()

   if not user:
       # Auto-provision user for SSO
       name_parts = name.split(maxsplit=1)
       first_name = name_parts[0] if name_parts else "Unknown"
       last_name = name_parts[1] if len(name_parts) > 1 else ""

       user = User(
           email=email,
           first_name=first_name,
           last_name=last_name,
           role=role,
           institution_id=institution.id,
           password_hash="",  # No password for SSO users
           is_active=True,
           approval_status="approved",  # Auto-approve SSO users
           email_verified=True,  # Trust CDS email verification
       )
       db.add(user)
       await db.flush()  # Get user.id
   else:
       # Update last login
       user.last_login_at = datetime.now(timezone.utc)
   ```
   - **Idempotent:** Finds existing user or creates new one
   - **Trust Model:** Auto-approves SSO users (trusts CDS authentication)
   - **Password-less:** SSO users have empty `password_hash`

4. **SSO Mapping Tracking** (lines 159-183):
   ```python
   mapping = result.scalar_one_or_none()

   if not mapping:
       mapping = UserSSOMapping(
           user_id=user.id,
           institution_id=institution.id,
           cds_student_id=cds_student_id,
           cds_organization_id=cds_organization_id,
           login_count=1
       )
       db.add(mapping)
   else:
       mapping.login_count += 1
       mapping.last_login_at = datetime.now(timezone.utc)
   ```
   - **Audit Trail:** Tracks SSO usage (login_count, last_login_at)
   - **Multi-Org Support:** One EV Lab user can map to multiple CDS organizations

5. **EV Lab Token Generation & Redirect** (lines 186-213):
   ```python
   token_data = {
       "user_id": str(user.id),
       "email": user.email,
       "role": user.role,
       "institution_id": str(institution.id),
   }

   if cds_session_id:
       token_data["cds_session_id"] = cds_session_id

   access_token = create_access_token(data=token_data)

   response = RedirectResponse(url=returnUrl, status_code=303)
   response.set_cookie(
       key="access_token",
       value=access_token,
       httponly=True,
       secure=True,  # HTTPS only
       samesite="lax",
       max_age=86400,  # 24 hours
   )
   ```
   - Generates EV Lab JWT token (24-hour expiry)
   - Sets secure HTTP-only cookie
   - Redirects to `returnUrl` (default: `/`)

**API Contract:**

**Request:**
```http
GET /api/sso/login?token=<JWT>&returnUrl=/experiments/basic_discharge
```

**Response:** (HTTP 303 Redirect with Set-Cookie)
```http
HTTP/1.1 303 See Other
Location: /experiments/basic_discharge
Set-Cookie: access_token=<ev-lab-jwt>; HttpOnly; Secure; SameSite=Lax; Max-Age=86400
```

**Testing This Component:**

```bash
# 1. Get SSO token from CDS (see Component 1 test)
SSO_URL="<copy-from-cds-response>"

# 2. Extract token from URL
TOKEN=$(echo $SSO_URL | grep -oP 'token=\K[^&]+')

# 3. Test SSO endpoint directly
curl -v "http://localhost:8010/api/sso/login?token=$TOKEN&returnUrl=/"

# 4. Check EV Lab database for created user
docker-compose exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT id, email, role, is_active FROM users ORDER BY created_at DESC LIMIT 5;"

# 5. Check SSO mapping
docker-compose exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT user_id, cds_student_id, login_count FROM user_sso_mappings;"
```

---

### Component 3: CDS Webhook Receiver

**Location:** `cds/backend/src/routes/lab-integration.routes.ts:128-292`

**Purpose:** Receive and store lab exercise results submitted by external lab platforms (EV Lab).

**How It Works:**

1. **API Key Validation Middleware** (lines 60-121):
   ```typescript
   async function validateApiKey(req, res, next) {
     const { apiKey, labPlatformId } = req.body;

     const labPlatform = await prisma.labPlatform.findUnique({
       where: { platformId: labPlatformId },
       select: { id: true, apiKey: true, status: true, organizationId: true },
     });

     if (!labPlatform) {
       return res.status(404).json({ success: false, message: 'Lab platform not found' });
     }

     if (labPlatform.apiKey !== apiKey) {
       return res.status(401).json({ success: false, message: 'Invalid API key' });
     }

     if (labPlatform.status !== 'active') {
       return res.status(403).json({ success: false, message: 'Lab platform not active' });
     }

     req.labPlatform = labPlatform; // Attach for route handler
     next();
   }
   ```
   - **Security:** Validates API key against database (not hardcoded)
   - **Active Check:** Only accepts results from active platforms
   - **Multi-Tenant:** Filters by organization

2. **Payload Validation** (lines 134-149):
   ```typescript
   const LabResultWebhookSchema = z.object({
     apiKey: z.string().min(32),
     labPlatformId: z.string().min(1),
     exerciseId: z.string().min(1),
     sessionId: z.string().uuid(),
     studentId: z.string().uuid(),
     status: z.enum(['not_started', 'in_progress', 'completed', 'failed', 'timeout']),
     startedAt: z.string().datetime().optional(),
     completedAt: z.string().datetime().optional(),
     timeSpentSeconds: z.number().int().min(0).optional(),
     score: z.number().min(0).optional(),
     maxScore: z.number().min(0).optional(),
     passed: z.boolean().optional(),
     attemptNumber: z.number().int().min(1).default(1),
     evidenceUrls: z.array(z.string().url()).optional().default([]),
     resultData: z.record(z.string(), z.any()).optional(),
     metadata: z.record(z.string(), z.any()).optional(),
   });
   ```
   - **Type Safety:** Zod validates types, formats, and constraints
   - **Detailed Errors:** Returns specific validation error messages

3. **Exercise Link Verification** (lines 160-180):
   ```typescript
   const link = await prisma.labExerciseLink.findFirst({
     where: {
       sessionId: payload.sessionId,
       exerciseId: payload.exerciseId,
       labPlatform: {
         platformId: payload.labPlatformId,
       },
       organizationId: labPlatform.organizationId,
     },
     select: { id: true },
   });

   if (!link) {
     return res.status(404).json({ success: false, message: 'Lab exercise link not found' });
   }
   ```
   - **Authorization:** Verifies this exercise was actually assigned to this session
   - **Prevents Spoofing:** Can't submit results for unlinked exercises

4. **Student Verification** (lines 184-216):
   ```typescript
   const student = await prisma.student.findUnique({
     where: { id: payload.studentId },
     include: {
       batch: {
         include: {
           instructor: { select: { organizationId: true } }
         }
       }
     }
   });

   if (!student) {
     return res.status(404).json({ success: false, message: 'Student not found' });
   }

   if (student.batch.instructor.organizationId !== labPlatform.organizationId) {
     return res.status(403).json({ success: false, message: 'Organization mismatch' });
   }
   ```
   - **Multi-Tenant Security:** Verifies student belongs to same organization as lab platform
   - **Data Isolation:** Prevents cross-organization data leakage

5. **Result Upsert (Idempotent)** (lines 218-264):
   ```typescript
   const result = await prisma.labExerciseResult.upsert({
     where: {
       linkId_studentId_attemptNumber: {
         linkId: link.id,
         studentId: payload.studentId,
         attemptNumber: payload.attemptNumber,
       },
     },
     update: {
       status: payload.status,
       startedAt: payload.startedAt ? new Date(payload.startedAt) : undefined,
       completedAt: payload.completedAt ? new Date(payload.completedAt) : undefined,
       score: payload.score,
       maxScore: payload.maxScore,
       percentage,
       passed: payload.passed,
       resultData: payload.resultData,
       evidenceUrls: payload.evidenceUrls,
       timeSpentSeconds: payload.timeSpentSeconds,
       metadata: payload.metadata,
       updatedAt: new Date(),
     },
     create: {
       linkId: link.id,
       studentId: payload.studentId,
       status: payload.status,
       startedAt: payload.startedAt ? new Date(payload.startedAt) : null,
       completedAt: payload.completedAt ? new Date(payload.completedAt) : null,
       score: payload.score,
       maxScore: payload.maxScore,
       percentage,
       passed: payload.passed,
       resultData: payload.resultData,
       evidenceUrls: payload.evidenceUrls,
       attemptNumber: payload.attemptNumber,
       timeSpentSeconds: payload.timeSpentSeconds,
       metadata: payload.metadata,
       organizationId: labPlatform.organizationId,
     },
   });
   ```
   - **Idempotent:** Handles duplicate webhook deliveries gracefully
   - **Unique Constraint:** `(linkId, studentId, attemptNumber)` prevents duplicate attempts
   - **Calculated Fields:** Auto-calculates `percentage` from `score` / `maxScore`

**API Contract:**

**Request:**
```http
POST /api/integrations/lab-results
Content-Type: application/json

{
  "apiKey": "change-this-32-char-api-key-abc123def456ghi789jkl012mno345pq",
  "labPlatformId": "ev-lab",
  "exerciseId": "basic_discharge",
  "sessionId": "f1e2d3c4-b5a6-4c7b-8d9e-0f1a2b3c4d5e",
  "studentId": "a1b2c3d4-e5f6-4a5b-8c7d-9e8f7a6b5c4d",
  "status": "completed",
  "startedAt": "2025-01-15T10:30:00Z",
  "completedAt": "2025-01-15T10:45:00Z",
  "timeSpentSeconds": 900,
  "score": 85.5,
  "maxScore": 100.0,
  "passed": true,
  "attemptNumber": 1,
  "evidenceUrls": [
    "https://evlab.reynlab.edu/reports/discharge-001.pdf"
  ],
  "resultData": {
    "chemistry": "NMC",
    "c_rate": 1.0,
    "temperature": 25,
    "final_soc": 0.0
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Lab result received and stored successfully",
  "resultId": "result-uuid-12345"
}
```

**Testing This Component:**

```bash
# 1. Get API key from environment
API_KEY=$(grep EV_LAB_API_KEY .env | cut -d '=' -f2)

# 2. Get session and student IDs from database
SESSION_ID=$(docker-compose exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM sessions LIMIT 1;" | xargs)
STUDENT_ID=$(docker-compose exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM students LIMIT 1;" | xargs)

# 3. Submit test result
curl -X POST http://localhost:3011/api/integrations/lab-results \
  -H "Content-Type: application/json" \
  -d "{
    \"apiKey\": \"$API_KEY\",
    \"labPlatformId\": \"ev-lab\",
    \"exerciseId\": \"basic_discharge\",
    \"sessionId\": \"$SESSION_ID\",
    \"studentId\": \"$STUDENT_ID\",
    \"status\": \"completed\",
    \"startedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"completedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"timeSpentSeconds\": 900,
    \"score\": 85.5,
    \"maxScore\": 100.0,
    \"passed\": true,
    \"attemptNumber\": 1,
    \"evidenceUrls\": [],
    \"resultData\": {\"chemistry\": \"NMC\", \"c_rate\": 1.0}
  }"

# 4. Verify result stored in database
docker-compose exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT id, status, score, passed FROM lab_exercise_results ORDER BY created_at DESC LIMIT 5;"

# 5. Test idempotency (submit same result again)
# Should update existing record, not create duplicate
```

---

### Component 4: Python SDK (Result Submission with Retry)

**Location:** `labs/ev-lab/sdk/python/cds_lab_sdk.py`

**Purpose:** Official Python library for lab platforms to integrate with CDS. Handles SSO validation, result submission, retry logic, and error handling.

**Key Classes:**

1. **CDSLabSDK** (lines 182-475):
   - Main SDK class
   - Async HTTP client (httpx)
   - Configuration validation (Pydantic)
   - Automatic retry logic (tenacity)

2. **SSOTokenPayload** (lines 75-92):
   - Pydantic model for decoded JWT
   - Validates required fields: `sub`, `session_id`, `student_id`, `organization_id`, `exercise_id`

3. **ResultSubmission** (lines 95-127):
   - Pydantic model for result data
   - Type-safe fields with validation
   - URL validation for evidence_urls

**How It Works:**

1. **SDK Initialization** (lines 192-231):
   ```python
   sdk = CDSLabSDK(
       cds_base_url="https://cds.reynlab.edu",
       lab_platform_id="battery-lab",
       api_key=os.getenv("CDS_API_KEY"),
       jwt_secret=os.getenv("JWT_SECRET"),
       timeout=30.0,
       enable_retry=True,
       max_retries=3
   )
   ```
   - **Config Validation:** Uses Pydantic to validate all parameters
   - **HTTP Client:** Creates async httpx client with timeout
   - **Webhook URL:** Auto-constructs from `cds_base_url`

2. **SSO Token Validation** (lines 249-290):
   ```python
   def validate_sso_token(self, token: str) -> SSOTokenPayload:
       try:
           decoded = jwt.decode(
               token,
               self.config.jwt_secret,
               algorithms=["HS256"]
           )

           payload = SSOTokenPayload(**decoded)

           if payload.lab_platform_id != self.config.lab_platform_id:
               raise SSOTokenValidationError(
                   f"Token is for {payload.lab_platform_id}, expected {self.config.lab_platform_id}"
               )

           return payload

       except jwt.ExpiredSignatureError:
           raise SSOTokenValidationError("Token has expired")
       except jwt.InvalidTokenError as e:
           raise SSOTokenValidationError(f"Invalid token: {str(e)}")
   ```
   - **Security:** Validates signature, expiry, and lab platform match
   - **Type Safety:** Returns Pydantic model (not raw dict)

3. **Result Submission** (lines 296-368):
   ```python
   async def submit_result(self, result: ResultSubmission) -> ResultSubmissionResponse:
       payload = {
           "apiKey": self.config.api_key,
           "labPlatformId": self.config.lab_platform_id,
           "exerciseId": result.exercise_id,
           "sessionId": result.session_id,
           "studentId": result.student_id,
           "status": result.status.value,
           "startedAt": result.started_at.isoformat() if result.started_at else None,
           "completedAt": result.completed_at.isoformat() if result.completed_at else None,
           "timeSpentSeconds": result.time_spent_seconds,
           "score": result.score,
           "maxScore": result.max_score,
           "passed": result.passed,
           "attemptNumber": result.attempt_number,
           "evidenceUrls": result.evidence_urls,
           "resultData": result.result_data,
           "metadata": result.metadata
       }

       try:
           response = await self.client.post(
               "/api/integrations/lab-results",
               json=payload
           )
           response.raise_for_status()
           data = response.json()
           return ResultSubmissionResponse(**data)

       except httpx.HTTPStatusError as e:
           raise ResultSubmissionError(
               f"CDS webhook failed: {e.response.status_code}",
               status_code=e.response.status_code
           )
       except httpx.RequestError as e:
           raise ResultSubmissionError("Failed to connect to CDS. Service may be unavailable.")
   ```
   - **Payload Construction:** Converts Pydantic model to JSON
   - **ISO 8601 Dates:** Converts datetime objects to strings
   - **Error Handling:** Distinguishes HTTP errors from network errors

4. **Retry Logic** (lines 370-408):
   ```python
   @retry(
       stop=stop_after_attempt(3),
       wait=wait_exponential(multiplier=1, min=4, max=10),
       retry=retry_if_exception_type(httpx.RequestError),
       before_sleep=before_sleep_log(logger, logging.WARNING),
       reraise=True
   )
   async def submit_result_with_retry(
       self,
       result: ResultSubmission,
       max_retries: Optional[int] = None
   ) -> ResultSubmissionResponse:
       return await self.submit_result(result)
   ```
   - **Retry Strategy:** Exponential backoff (4s, 8s, 10s)
   - **Retry Conditions:** Only retries on network errors (not 4xx client errors)
   - **Logging:** Logs each retry attempt
   - **Customizable:** Can override `max_retries` per call

**Usage Example:**

```python
from sdk.python.cds_lab_sdk import CDSLabSDK, ResultSubmission, ResultStatus
from datetime import datetime
import os

# Initialize SDK
sdk = CDSLabSDK(
    cds_base_url=os.getenv("CDS_BASE_URL"),
    lab_platform_id="ev-lab",
    api_key=os.getenv("CDS_API_KEY"),
    jwt_secret=os.getenv("JWT_SECRET")
)

# Validate SSO token
try:
    session = sdk.validate_sso_token(sso_token)
    print(f"Student: {session.student_name} ({session.roll_number})")
except SSOTokenValidationError as e:
    print(f"SSO validation failed: {e}")
    return

# Submit result with automatic retry
result = ResultSubmission(
    session_id=session.session_id,
    student_id=session.student_id,
    exercise_id="basic_discharge",
    status=ResultStatus.COMPLETED,
    started_at=datetime.utcnow(),
    completed_at=datetime.utcnow(),
    time_spent_seconds=900,
    score=85.5,
    max_score=100.0,
    passed=True,
    attempt_number=1,
    evidence_urls=["https://evlab.reynlab.edu/reports/discharge-001.pdf"],
    result_data={
        "chemistry": "NMC",
        "c_rate": 1.0,
        "temperature": 25
    }
)

try:
    response = await sdk.submit_result_with_retry(result)
    print(f"Result submitted successfully! ID: {response.result_id}")
except ResultSubmissionError as e:
    print(f"Result submission failed: {e}")
finally:
    await sdk.close()
```

---

## Integration Flows

### Flow 1: Complete Student Lab Launch Journey

**Scenario:** Student "Jane Doe" launches Battery Lab from CDS session.

**Step-by-Step Execution:**

1. **Instructor Creates Session** (CDS Frontend → Backend)
   - Instructor navigates to batch details
   - Creates new session: "Battery Fundamentals Lab"
   - Links lab exercise: "basic_discharge" (EV Lab)
   - Database creates:
     - `Session` record (id: `session-123`)
     - `LabExerciseLink` record (links session → ev-lab → basic_discharge)

2. **Student Clicks "Launch Lab"** (CDS Frontend)
   - Button click triggers:
   ```typescript
   // cds/frontend/src/services/lab.service.ts
   const response = await api.post(
     `/api/integrations/lab-platforms/ev-lab/sso-token`,
     {
       studentId: 'student-456',
       sessionId: 'session-123',
       returnUrl: '/experiments/basic_discharge'
     }
   );
   const { ssoUrl } = response.data.data;
   window.location.href = ssoUrl; // Redirect to EV Lab
   ```

3. **CDS Generates SSO Token** (CDS Backend)
   - Executes `lab-integration.routes.ts:449-609`
   - Queries database:
     - Student: `SELECT * FROM students WHERE id = 'student-456'`
     - Organization: (via nested include)
     - Lab Platform: `SELECT * FROM lab_platforms WHERE platformId = 'ev-lab'`
   - Generates JWT:
   ```json
   {
     "cds_student_id": "student-456",
     "cds_organization_id": "org-789",
     "cds_session_id": "session-123",
     "email": "jane.doe@university.edu",
     "name": "Jane Doe",
     "role": "student",
     "iat": 1704034800,
     "exp": 1704036600
   }
   ```
   - Returns SSO URL: `http://localhost:3020/sso/login?token=<JWT>&returnUrl=/experiments/basic_discharge`

4. **Browser Redirects to EV Lab** (Client-side)
   - GET `http://localhost:3020/sso/login?token=<JWT>&returnUrl=/experiments/basic_discharge`

5. **EV Lab Validates Token** (EV Lab API Gateway)
   - Executes `sso_routes.py:29-223`
   - Decodes JWT using shared `JWT_SECRET`
   - Queries database:
     - Institution: `SELECT * FROM institutions WHERE cds_organization_id = 'org-789'`
       - **If not found:** Returns 404 (institution not registered)
       - **If found:** Proceeds to user lookup
     - User: `SELECT * FROM users WHERE email = 'jane.doe@university.edu'`
       - **If not found:** Auto-provisions user:
       ```python
       user = User(
           email='jane.doe@university.edu',
           first_name='Jane',
           last_name='Doe',
           role='student',
           institution_id=institution.id,
           password_hash='',  # No password for SSO users
           is_active=True,
           approval_status='approved',
           email_verified=True
       )
       ```
     - SSO Mapping: `INSERT INTO user_sso_mappings (...) ON CONFLICT UPDATE login_count`

6. **EV Lab Generates Token & Redirects** (EV Lab API Gateway)
   - Creates EV Lab JWT (24-hour expiry):
   ```json
   {
     "user_id": "ev-lab-user-101",
     "email": "jane.doe@university.edu",
     "role": "student",
     "institution_id": "institution-202",
     "cds_session_id": "session-123"
   }
   ```
   - Sets HTTP-only cookie: `access_token=<EV-LAB-JWT>`
   - Redirects: `HTTP/1.1 303 See Other` → `/experiments/basic_discharge`

7. **Student Sees Lab Interface** (EV Lab Frontend)
   - Next.js loads `/experiments/basic_discharge` page
   - Cookie authentication automatically logs in student
   - UI fetches experiment configuration from `/api/experiments/basic_discharge`

**Database State After Flow:**

```sql
-- CDS Database (cds_integration)
SELECT * FROM sessions WHERE id = 'session-123';
-- Result: Session exists with instructor, batch, location

SELECT * FROM lab_exercise_links WHERE session_id = 'session-123';
-- Result: Link to ev-lab/basic_discharge created

SELECT * FROM students WHERE id = 'student-456';
-- Result: Student "Jane Doe" belongs to batch

-- EV Lab Database (ev_lab_integration)
SELECT * FROM institutions WHERE cds_organization_id = 'org-789';
-- Result: Institution "University XYZ" mapped to CDS org

SELECT * FROM users WHERE email = 'jane.doe@university.edu';
-- Result: User auto-provisioned, role=student, is_active=true

SELECT * FROM user_sso_mappings WHERE cds_student_id = 'student-456';
-- Result: Mapping created, login_count=1
```

**Failure Scenarios & Handling:**

| Failure Point | Error | HTTP Status | User Impact |
|---------------|-------|-------------|-------------|
| CDS: Organization not found | `Student not found` | 404 | "Student does not exist" |
| CDS: EV Lab integration disabled | `EV Lab SSO is not enabled` | 403 | "Contact administrator to enable EV Lab integration" |
| CDS: Lab platform inactive | `Lab platform not active` | 404 | "Platform must be registered and active" |
| EV Lab: Institution not registered | `Institution not registered` | 404 | "Institution not registered or SSO not enabled. Contact administrator." |
| EV Lab: JWT expired | `Token has expired` | 401 | "SSO token has expired. Please request a new link from CDS." |
| EV Lab: Invalid JWT signature | `Invalid SSO token` | 401 | "Invalid SSO token" |

---

### Flow 2: Complete Result Submission Journey

**Scenario:** Student "Jane Doe" completes "basic_discharge" experiment in EV Lab, results sync to CDS.

**Step-by-Step Execution:**

1. **Student Completes Experiment** (EV Lab Frontend → API Gateway)
   - Student runs simulation in EV Lab
   - Frontend submits completion:
   ```typescript
   // labs/ev-lab/frontend/src/stores/experimentStore.ts
   const response = await fetch('/api/experiments/execute', {
     method: 'POST',
     headers: {
       'Content-Type': 'application/json',
       'Authorization': `Bearer ${accessToken}`
     },
     body: JSON.stringify({
       experiment_type: 'basic_discharge',
       chemistry: 'NMC',
       parameters: {
         c_rate: 1.0,
         initial_soc: 1.0,
         final_voltage: 2.5
       }
     })
   });
   ```

2. **EV Lab API Executes Simulation** (API Gateway → PyBaMM)
   - API Gateway calls PyBaMM service:
   ```python
   # labs/ev-lab/docker/api-gateway/experiment_routes.py
   response = requests.post(
       f"{PYBAMM_HOST}:8001/execute",
       json=payload,
       timeout=PYBAMM_SIMULATION_TIMEOUT
   )
   results = response.json()
   ```
   - PyBaMM returns simulation data:
   ```json
   {
     "voltage": [4.2, 4.1, 4.0, ...],
     "current": [50, 50, 50, ...],
     "soc": [1.0, 0.9, 0.8, ...],
     "temperature": [25, 26, 27, ...]
   }
   ```

3. **EV Lab Saves Result Locally** (API Gateway → PostgreSQL)
   - Creates `ExperimentRun` record:
   ```python
   run = ExperimentRun(
       user_id=user.id,
       institution_id=user.institution_id,
       experiment_type='basic_discharge',
       chemistry='NMC',
       parameters={'c_rate': 1.0, 'initial_soc': 1.0},
       status='completed',
       results=results,
       started_at=started_at,
       completed_at=datetime.utcnow(),
       execution_time_seconds=900
   )
   db.add(run)
   await db.commit()
   ```
   - Updates `Progress` record:
   ```python
   progress = await db.get(Progress, (user.id, 'basic_discharge'))
   progress.completed = True
   progress.score = 85.5
   progress.attempts += 1
   await db.commit()
   ```

4. **EV Lab Submits to CDS** (API Gateway → CDS Lab SDK)
   - Checks if CDS integration enabled:
   ```python
   if os.getenv("ENABLE_CDS_INTEGRATION") == "true":
       sdk = CDSLabSDK(
           cds_base_url=os.getenv("CDS_BASE_URL"),
           lab_platform_id="ev-lab",
           api_key=os.getenv("CDS_API_KEY"),
           jwt_secret=os.getenv("JWT_SECRET")
       )
   ```
   - Constructs result submission:
   ```python
   result = ResultSubmission(
       session_id=cds_session_id,  # From JWT payload
       student_id=cds_student_id,  # From SSO mapping
       exercise_id='basic_discharge',
       status=ResultStatus.COMPLETED,
       started_at=run.started_at,
       completed_at=run.completed_at,
       time_spent_seconds=900,
       score=85.5,
       max_score=100.0,
       passed=True,
       attempt_number=1,
       evidence_urls=[],
       result_data={
           'ev_lab_run_id': str(run.id),
           'chemistry': 'NMC',
           'c_rate': 1.0,
           'final_voltage': 2.5
       }
   )
   ```
   - Submits with retry:
   ```python
   try:
       response = await sdk.submit_result_with_retry(result, max_retries=3)
       logger.info(f"Result submitted to CDS: {response.result_id}")
   except ResultSubmissionError as e:
       logger.error(f"Failed to submit result to CDS: {e}")
       # Don't fail experiment completion if CDS sync fails
   ```

5. **CDS Receives Webhook** (CDS Backend)
   - POST `/api/integrations/lab-results` executed
   - Validates API key (see Component 3)
   - Finds `LabExerciseLink`:
   ```typescript
   const link = await prisma.labExerciseLink.findFirst({
     where: {
       sessionId: 'session-123',
       exerciseId: 'basic_discharge',
       labPlatform: { platformId: 'ev-lab' }
     }
   });
   ```
   - Verifies student organization match
   - Upserts `LabExerciseResult`:
   ```typescript
   const result = await prisma.labExerciseResult.upsert({
     where: {
       linkId_studentId_attemptNumber: {
         linkId: link.id,
         studentId: 'student-456',
         attemptNumber: 1
       }
     },
     update: {
       status: 'completed',
       score: 85.5,
       maxScore: 100.0,
       percentage: 85.5,
       passed: true,
       completedAt: new Date(),
       resultData: {
         ev_lab_run_id: 'run-789',
         chemistry: 'NMC'
       }
     },
     create: { /* same fields */ }
   });
   ```

6. **CDS Responds Success** (CDS Backend → SDK)
   - Returns:
   ```json
   {
     "success": true,
     "message": "Lab result received and stored successfully",
     "resultId": "result-uuid-12345"
   }
   ```

7. **EV Lab Confirms Success** (API Gateway)
   - Logs confirmation:
   ```python
   logger.info(f"CDS sync successful: result_id={response.result_id}")
   ```

**Retry Scenarios:**

| Attempt | CDS Status | SDK Action | Delay | Final Outcome |
|---------|------------|------------|-------|---------------|
| 1 | CDS down (connection refused) | Retry | Wait 4s | - |
| 2 | CDS down (connection refused) | Retry | Wait 8s | - |
| 3 | CDS back up (200 OK) | Success | - | Result saved |

**Database State After Flow:**

```sql
-- EV Lab Database (ev_lab_integration)
SELECT * FROM experiment_runs WHERE user_id = 'ev-lab-user-101' ORDER BY created_at DESC LIMIT 1;
-- Result: Run completed, status='completed', score=85.5

SELECT * FROM progress WHERE user_id = 'ev-lab-user-101' AND experiment_id = 'basic_discharge';
-- Result: Progress updated, completed=true, score=85.5, attempts=1

-- CDS Database (cds_integration)
SELECT * FROM lab_exercise_results WHERE student_id = 'student-456' ORDER BY created_at DESC LIMIT 1;
-- Result: Result saved, status='completed', score=85.5, passed=true, percentage=85.5

SELECT
  s.name AS student,
  ler.status,
  ler.score,
  ler.passed,
  ler.completed_at
FROM lab_exercise_results ler
JOIN students s ON ler.student_id = s.id
WHERE ler.student_id = 'student-456'
ORDER BY ler.created_at DESC;
-- Result: Jane Doe | completed | 85.5 | true | 2025-01-15 10:45:00
```

**Idempotency Test:**

```bash
# Submit same result twice (simulate duplicate webhook)
curl -X POST http://localhost:3011/api/integrations/lab-results \
  -H "Content-Type: application/json" \
  -d '{
    "apiKey": "...",
    "labPlatformId": "ev-lab",
    "sessionId": "session-123",
    "studentId": "student-456",
    "exerciseId": "basic_discharge",
    "status": "completed",
    "score": 85.5,
    "attemptNumber": 1
  }'

# First call: INSERT (creates new record)
# Second call: UPDATE (updates existing record with same linkId, studentId, attemptNumber)
# Result: Only ONE record in database
```

---

## Database Architecture

### CDS Database Schema (Prisma)

**Core Multi-Tenant Models:**

```prisma
model Organization {
  id   String @id @default(uuid())
  name String

  // EV Lab Integration Fields (Phase 2)
  evLabInstitutionId UUID?   @unique  // Maps to EV Lab Institution.id
  evLabEnabled       Boolean @default(false)  // Feature flag
  evLabSsoEnabled    Boolean @default(false)  // SSO feature flag

  locations    Location[]
  instructors  Instructor[]
  labPlatforms LabPlatform[]  // Lab registry
}

model Student {
  id         String @id @default(uuid())
  name       String
  rollNumber String  // Auto-generated: YYStateCode-NNN
  email      String?
  batchId    String

  batch              Batch                 @relation(...)
  labExerciseResults LabExerciseResult[]  // Results from external labs
}

model Session {
  id                   String @id @default(uuid())
  batchId              String
  instructorId         String
  moduleId             String  // Reference to course.modules[].id
  lessonId             String  // Reference to course.modules[].lessons[].id
  checkpointsCovered   Json    // Array of teaching point IDs
  compliancePercentage Float   @default(0)

  labExerciseLinks LabExerciseLink[]  // Links to external lab exercises
}
```

**Integration-Specific Models:**

```prisma
// Lab Platform Registry
model LabPlatform {
  id              String @id @default(uuid())
  platformId      String @unique  // 'ev-lab', 'engine-lab', etc.
  name            String          // 'Battery Lab V3'
  description     String?
  baseUrl         String          // 'https://evlab.reynlab.edu'
  ssoEndpoint     String          // '/sso/login'
  healthEndpoint  String @default("/health")
  apiKey          String          // Shared secret for webhooks
  status          String @default("active")  // 'active' | 'inactive' | 'maintenance'
  organizationId  String

  organization Organization       @relation(...)
  exercises    LabExerciseLink[]

  @@index([organizationId])
  @@index([status])
}

// Links Session → Lab Exercise
model LabExerciseLink {
  id               String @id @default(uuid())
  sessionId        String
  labPlatformId    String
  exerciseId       String  // 'basic_discharge', 'engine_timing_adjustment'
  exerciseName     String  // 'Basic Battery Discharge Analysis'
  description      String?
  launchUrl        String  // Full URL with placeholders
  requiredRole     String @default("student")  // 'student' | 'instructor'
  estimatedMinutes Int?
  isRequired       Boolean @default(false)
  displayOrder     Int     @default(0)
  organizationId   String  // Multi-tenant isolation

  session     Session             @relation(...)
  labPlatform LabPlatform         @relation(...)
  results     LabExerciseResult[]

  @@index([sessionId])
  @@index([labPlatformId])
  @@index([organizationId])
}

// Student Results from External Labs
model LabExerciseResult {
  id               String    @id @default(uuid())
  linkId           String
  studentId        String
  startedAt        DateTime?
  completedAt      DateTime?
  status           String  // 'not_started' | 'in_progress' | 'completed' | 'failed' | 'timeout'
  score            Float?
  maxScore         Float?
  percentage       Float?  // Calculated: (score / maxScore) * 100
  passed           Boolean?
  resultData       Json?   // Opaque lab-specific data
  evidenceUrls     String[]  // URLs to reports, photos, videos
  attemptNumber    Int     @default(1)
  timeSpentSeconds Int?
  metadata         Json?
  organizationId   String  // Multi-tenant isolation

  link    LabExerciseLink @relation(...)
  student Student         @relation(...)

  @@unique([linkId, studentId, attemptNumber])  // Idempotency constraint
  @@index([studentId])
  @@index([linkId])
  @@index([organizationId])
  @@index([status])
  @@index([completedAt])
}
```

**Key Relationships:**

```
Organization
  └── LabPlatform (lab registry)
        └── LabExerciseLink (session → exercise mapping)
              └── LabExerciseResult (student results)
                    └── Student
```

### EV Lab Database Schema (SQLAlchemy 2.0)

**Core Multi-Tenant Models:**

```python
class Institution(Base):
    __tablename__ = "institutions"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    domain: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    subdomain: Mapped[str] = mapped_column(String(63), unique=True, index=True)

    # CDS Integration Fields (Phase 2)
    cds_organization_id: Mapped[Optional[UUID]] = mapped_column(
        UUID(as_uuid=True),
        unique=True,
        nullable=True,
        index=True,
        comment="Maps to CDS Organization.id for SSO and result sync"
    )
    cds_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    cds_sso_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    cds_webhook_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    # Lab access configuration
    available_labs: Mapped[Optional[list]] = mapped_column(
        JSON, nullable=True, default=None
    )  # List of lab IDs or null for all labs

    # Relationships
    users: Mapped[List["User"]] = relationship("User", back_populates="institution")

class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))  # Empty for SSO users
    first_name: Mapped[str] = mapped_column(String(100))
    last_name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(50), default="student")
    institution_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("institutions.id"), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    approval_status: Mapped[str] = mapped_column(String(50), default="pending")

    # Relationships
    institution: Mapped["Institution"] = relationship("Institution", back_populates="users")
    sso_mappings: Mapped[List["UserSSOMapping"]] = relationship("UserSSOMapping", back_populates="user")
    experiment_runs: Mapped[List["ExperimentRun"]] = relationship("ExperimentRun", back_populates="user")
    progress_records: Mapped[List["Progress"]] = relationship("Progress", back_populates="user")
```

**Integration-Specific Models:**

```python
class UserSSOMapping(Base):
    """Maps CDS students to EV Lab users for SSO"""
    __tablename__ = "user_sso_mappings"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)

    # EV Lab side
    user_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("users.id"), index=True)
    institution_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("institutions.id"), index=True)

    # CDS side
    cds_student_id: Mapped[UUID] = mapped_column(UUID, index=True, comment="CDS Student.id")
    cds_organization_id: Mapped[UUID] = mapped_column(UUID, index=True, comment="CDS Organization.id")

    # SSO metadata
    first_login_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_login_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    login_count: Mapped[int] = mapped_column(Integer, default=0)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="sso_mappings")
    institution: Mapped["Institution"] = relationship("Institution")

    # Indexes
    __table_args__ = (
        Index('idx_cds_student_org', 'cds_student_id', 'cds_organization_id', unique=True),
        Index('idx_user_institution', 'user_id', 'institution_id'),
    )

class ExperimentRun(Base):
    """Records every experiment execution"""
    __tablename__ = "experiment_runs"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("users.id"), index=True)
    institution_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("institutions.id"), index=True)
    experiment_type: Mapped[str] = mapped_column(String(100))
    chemistry: Mapped[str] = mapped_column(String(50))
    parameters: Mapped[dict] = mapped_column(JSON)
    status: Mapped[str] = mapped_column(String(50), default="pending")
    results: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="experiment_runs")

class Progress(Base):
    """Tracks student learning progress"""
    __tablename__ = "progress"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("users.id"), index=True)
    institution_id: Mapped[UUID] = mapped_column(UUID, ForeignKey("institutions.id"), index=True)
    experiment_id: Mapped[str] = mapped_column(String(100), index=True)
    status: Mapped[str] = mapped_column(String(50), default="not_started")
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="progress_records")

    __table_args__ = (
        Index("ix_progress_user_experiment", "user_id", "experiment_id"),
    )
```

**Key Relationships:**

```
Institution
  └── User (multi-role: student, instructor, admin)
        ├── UserSSOMapping (links to CDS Student)
        ├── ExperimentRun
        └── Progress
```

### Multi-Tenant Data Isolation Queries

**CDS - Get All Student Lab Results for Organization:**
```typescript
const results = await prisma.labExerciseResult.findMany({
  where: {
    organizationId: userOrganizationId,  // Multi-tenant filter
    status: 'completed'
  },
  include: {
    student: {
      select: { name: true, rollNumber: true }
    },
    link: {
      include: {
        labPlatform: {
          select: { name: true, platformId: true }
        }
      }
    }
  },
  orderBy: { completedAt: 'desc' }
});
```

**EV Lab - Get All Experiments for Institution:**
```python
async with get_db() as db:
    result = await db.execute(
        select(ExperimentRun)
        .where(ExperimentRun.institution_id == user.institution_id)  # Multi-tenant filter
        .options(joinedload(ExperimentRun.user))
        .order_by(ExperimentRun.created_at.desc())
    )
    runs = result.scalars().all()
```

---

## API Endpoints Reference

### CDS Backend (Port 3011)

#### Integration Endpoints

| Method | Endpoint | Auth | Purpose | File |
|--------|----------|------|---------|------|
| **POST** | `/api/integrations/lab-platforms/:platformId/sso-token` | CDS User JWT | Generate SSO token for lab launch | `lab-integration.routes.ts:449` |
| **POST** | `/api/integrations/lab-results` | Lab API Key (body) | Receive results from lab platforms | `lab-integration.routes.ts:128` |
| **GET** | `/api/integrations/lab-platforms` | CDS User JWT | List registered lab platforms | `lab-integration.routes.ts:299` |
| **GET** | `/api/integrations/session/:sessionId/exercises` | CDS User JWT | Get lab exercises for session | `lab-integration.routes.ts:347` |
| **GET** | `/api/integrations/student/:studentId/results` | CDS User JWT | Get all lab results for student | `lab-integration.routes.ts:398` |

### EV Lab API Gateway (Port 8010)

#### Integration Endpoints

| Method | Endpoint | Auth | Purpose | File |
|--------|----------|------|---------|------|
| **GET** | `/api/sso/login?token=<JWT>` | CDS JWT (query param) | SSO login from CDS | `sso_routes.py:29` |
| **GET** | `/api/sso/status` | None | Check SSO configuration | `sso_routes.py:226` |
| **GET** | `/api/sso/health` | None | SSO health check | `sso_routes.py:260` |
| **POST** | `/api/cds-integration/submit-result` | EV Lab User JWT | Submit result to CDS (internal) | `cds_integration_routes.py:230` |
| **GET** | `/api/cds-integration/health` | None | Integration health check | `cds_integration_routes.py:302` |

---

## Development Workflows

### Workflow 1: Set Up Integration Environment (First Time)

**Goal:** Get complete integration stack running from scratch.

**Commands:**

```bash
# 1. Navigate to workspace
cd /Volumes/Dev/CDS_Lab_Integration

# 2. Run setup script (installs dependencies, builds images)
./scripts/setup.sh
# Expected output:
#   ✓ Prerequisites OK
#   ✓ Repositories ready
#   ✓ Directories created
#   ✓ Docker images built
#   ✓ CDS dependencies installed
#   ✓ EV Lab dependencies installed
#   ⚠️  Please edit .env with your actual values

# 3. Configure environment variables
cp .env.example .env
nano .env
# Edit these critical variables:
#   JWT_SECRET=<openssl rand -base64 32>
#   CDS_DB_PASSWORD=<secure-password>
#   EV_LAB_DB_PASSWORD=<secure-password>
#   EV_LAB_API_KEY=<openssl rand -base64 32>
#   CDS_API_KEY=<openssl rand -base64 32>

# 4. Start all services
./scripts/start.sh
# Expected output:
#   Starting CDS services...
#   Starting EV Lab services...
#   ✓ All services started successfully
#   CDS Frontend: http://localhost:3010
#   EV Lab Frontend: http://localhost:3020

# 5. Wait for services to be healthy (30-60 seconds)
watch -n 2 'docker-compose -f infrastructure/docker-compose.yml ps'
# Wait until all services show "healthy"

# 6. Run database migrations
docker-compose -f infrastructure/docker-compose.yml exec cds-backend npm run prisma:migrate:deploy
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-api-gateway alembic upgrade head

# 7. Seed test data
./scripts/seed_test_data.sh
# Creates:
#   - Test organization "Test University"
#   - Test instructor "Test Instructor"
#   - Test batch "Test Batch 2025"
#   - Test students (5 students)
#   - Test session with lab exercise link
#   - Lab platform registration

# 8. Verify health
curl http://localhost:3011/health          # CDS Backend
curl http://localhost:8010/health          # EV Lab API
curl http://localhost:8010/api/sso/health  # SSO integration

# 9. Access frontends
open http://localhost:3010  # CDS (login with test instructor)
open http://localhost:3020  # EV Lab (will auto-login via SSO)
```

**Verification Checklist:**

```bash
# ✓ All 10 Docker services running
docker-compose -f infrastructure/docker-compose.yml ps | grep "Up"

# ✓ CDS database has data
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT COUNT(*) FROM organizations;"
# Expected: 1

# ✓ EV Lab database has institutions
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT COUNT(*) FROM institutions WHERE cds_enabled = true;"
# Expected: 1

# ✓ Lab platform registered
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT platform_id, status FROM lab_platforms;"
# Expected: ev-lab | active
```

---

### Workflow 2: Test Complete SSO Flow

**Goal:** Verify end-to-end SSO authentication from CDS to EV Lab.

**Prerequisites:**
- Services running (`./scripts/start.sh`)
- Test data seeded (`./scripts/seed_test_data.sh`)

**Steps:**

```bash
# 1. Get test student ID
STUDENT_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM students WHERE name = 'Test Student 1';" | xargs)
echo "Student ID: $STUDENT_ID"

# 2. Get test session ID
SESSION_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM sessions LIMIT 1;" | xargs)
echo "Session ID: $SESSION_ID"

# 3. Get CDS instructor auth token
# (Login to CDS frontend and extract token from localStorage or use API)
CDS_TOKEN="<get-from-browser-devtools>"

# 4. Generate SSO token
SSO_RESPONSE=$(curl -s -X POST http://localhost:3011/api/integrations/lab-platforms/ev-lab/sso-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CDS_TOKEN" \
  -d "{
    \"studentId\": \"$STUDENT_ID\",
    \"sessionId\": \"$SESSION_ID\",
    \"returnUrl\": \"/experiments/basic_discharge\"
  }")

echo "SSO Response:"
echo $SSO_RESPONSE | jq .

# 5. Extract SSO URL
SSO_URL=$(echo $SSO_RESPONSE | jq -r .data.ssoUrl)
echo "SSO URL: $SSO_URL"

# 6. Open SSO URL in browser (auto-redirects to EV Lab)
open "$SSO_URL"
# Or use curl to follow redirects:
curl -v -L "$SSO_URL"

# 7. Verify user created in EV Lab
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT id, email, role, is_active, approval_status FROM users ORDER BY created_at DESC LIMIT 1;"
# Expected: test-student-1@test-university.edu | student | true | approved

# 8. Verify SSO mapping created
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT user_id, cds_student_id, login_count FROM user_sso_mappings ORDER BY created_at DESC LIMIT 1;"
# Expected: <ev-lab-user-id> | <cds-student-id> | 1

# 9. Test SSO URL expiry (wait 30+ minutes and try again)
# Should fail with "Token has expired"
```

**Expected Browser Flow:**

1. Browser loads: `http://localhost:3020/sso/login?token=<JWT>&returnUrl=/experiments/basic_discharge`
2. EV Lab validates token, creates/updates user
3. Browser receives Set-Cookie header with EV Lab JWT
4. Browser redirects to: `http://localhost:3020/experiments/basic_discharge`
5. Student is logged in and sees experiment interface

**Common Issues:**

| Issue | Symptom | Fix |
|-------|---------|-----|
| JWT_SECRET mismatch | "Invalid SSO token" | Ensure JWT_SECRET is identical in CDS and EV Lab `.env` |
| Institution not registered | "Institution not registered" | Run seed script or manually create institution with `cds_enabled=true` |
| Token expired | "Token has expired" | Generate new SSO token (30-min expiry) |
| CORS error | Browser console shows CORS | Check `CORS_ORIGINS` in docker-compose.yml |

---

### Workflow 3: Test Result Submission

**Goal:** Verify experiment results flow from EV Lab to CDS.

**Prerequisites:**
- SSO flow tested (Workflow 2)
- Student has EV Lab access token

**Steps:**

```bash
# 1. Get test data IDs
STUDENT_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM students LIMIT 1;" | xargs)
SESSION_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM sessions LIMIT 1;" | xargs)
CDS_API_KEY=$(grep CDS_API_KEY .env | cut -d '=' -f2)

# 2. Submit result directly to CDS webhook (simulating EV Lab)
RESULT_RESPONSE=$(curl -s -X POST http://localhost:3011/api/integrations/lab-results \
  -H "Content-Type: application/json" \
  -d "{
    \"apiKey\": \"$CDS_API_KEY\",
    \"labPlatformId\": \"ev-lab\",
    \"exerciseId\": \"basic_discharge\",
    \"sessionId\": \"$SESSION_ID\",
    \"studentId\": \"$STUDENT_ID\",
    \"status\": \"completed\",
    \"startedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"completedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"timeSpentSeconds\": 900,
    \"score\": 85.5,
    \"maxScore\": 100.0,
    \"passed\": true,
    \"attemptNumber\": 1,
    \"evidenceUrls\": [],
    \"resultData\": {
      \"chemistry\": \"NMC\",
      \"c_rate\": 1.0,
      \"temperature\": 25,
      \"final_voltage\": 2.5
    }
  }")

echo "Result Response:"
echo $RESULT_RESPONSE | jq .

# 3. Verify result stored in CDS database
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT id, status, score, passed, percentage, attempt_number FROM lab_exercise_results ORDER BY created_at DESC LIMIT 1;"

# 4. Test idempotency (submit same result again)
curl -s -X POST http://localhost:3011/api/integrations/lab-results \
  -H "Content-Type: application/json" \
  -d "{
    \"apiKey\": \"$CDS_API_KEY\",
    \"labPlatformId\": \"ev-lab\",
    \"exerciseId\": \"basic_discharge\",
    \"sessionId\": \"$SESSION_ID\",
    \"studentId\": \"$STUDENT_ID\",
    \"status\": \"completed\",
    \"score\": 85.5,
    \"attemptNumber\": 1
  }"

# 5. Verify only ONE result exists (idempotency)
RESULT_COUNT=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT COUNT(*) FROM lab_exercise_results WHERE student_id = '$STUDENT_ID' AND attempt_number = 1;" | xargs)
echo "Result count (should be 1): $RESULT_COUNT"

# 6. Test retry logic using Python SDK
cd labs/ev-lab
python3 -c "
import asyncio
import os
from sdk.python.cds_lab_sdk import CDSLabSDK, ResultSubmission, ResultStatus
from datetime import datetime

async def test_retry():
    sdk = CDSLabSDK(
        cds_base_url='http://localhost:3011',
        lab_platform_id='ev-lab',
        api_key='$CDS_API_KEY',
        jwt_secret='$(grep JWT_SECRET ../../.env | cut -d '=' -f2)'
    )

    result = ResultSubmission(
        session_id='$SESSION_ID',
        student_id='$STUDENT_ID',
        exercise_id='basic_discharge',
        status=ResultStatus.COMPLETED,
        score=90.0,
        max_score=100.0,
        passed=True,
        attempt_number=2
    )

    try:
        response = await sdk.submit_result_with_retry(result, max_retries=3)
        print(f'Success: {response.result_id}')
    except Exception as e:
        print(f'Failed: {e}')
    finally:
        await sdk.close()

asyncio.run(test_retry())
"

# 7. Verify second attempt stored
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT attempt_number, score, status FROM lab_exercise_results WHERE student_id = '$STUDENT_ID' ORDER BY attempt_number;"
# Expected: 2 rows (attempt 1 with score 85.5, attempt 2 with score 90.0)
```

**Testing Retry Logic (Simulate CDS Downtime):**

```bash
# 1. Stop CDS backend
docker-compose -f infrastructure/docker-compose.yml stop cds-backend

# 2. Try to submit result (will retry 3 times with exponential backoff)
time curl -X POST http://localhost:3011/api/integrations/lab-results \
  -H "Content-Type: application/json" \
  -d '{"apiKey": "..."}'
# Expected: Connection refused after ~22 seconds (4s + 8s + 10s)

# 3. Restart CDS backend
docker-compose -f infrastructure/docker-compose.yml start cds-backend

# 4. Wait for backend to be healthy
sleep 10

# 5. Retry submission (should succeed)
curl -X POST http://localhost:3011/api/integrations/lab-results \
  -H "Content-Type: application/json" \
  -d "{...}"
# Expected: HTTP 200, result stored
```

---

### Workflow 4: Daily Development

**Goal:** Make changes to integration code and test without full restart.

**Scenario:** Update SSO token expiry from 30 minutes to 1 hour.

**Steps:**

```bash
# 1. Services already running
./scripts/logs.sh cds-backend  # Monitor logs in separate terminal

# 2. Edit CDS code
nano cds/backend/src/routes/lab-integration.routes.ts
# Line 556: Change `exp: now + 1800` to `exp: now + 3600`

# 3. Wait for hot reload (Nodemon detects change and restarts)
# Check logs for: [nodemon] restarting due to changes...

# 4. Test change immediately
curl -X POST http://localhost:3011/api/integrations/lab-platforms/ev-lab/sso-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CDS_TOKEN" \
  -d '{"studentId": "...", "sessionId": "..."}'

# 5. Decode JWT to verify expiry
JWT=$(curl -s ... | jq -r .data.token)
echo $JWT | cut -d '.' -f2 | base64 -d | jq .exp
# Expected: now + 3600 seconds

# 6. If editing EV Lab Python code
nano labs/ev-lab/docker/api-gateway/routes/sso_routes.py
# FastAPI auto-reloads on file change

# 7. If editing database schema (Prisma)
nano cds/backend/prisma/schema.prisma
# Must run migration:
docker-compose -f infrastructure/docker-compose.yml exec cds-backend npx prisma migrate dev --name <name>
docker-compose -f infrastructure/docker-compose.yml exec cds-backend npx prisma generate

# 8. If editing frontend
nano cds/frontend/src/pages/SessionDetails.tsx
# Vite hot module replacement (HMR) updates browser automatically
```

**Hot Reload Configuration:**

| Service | Hot Reload | Restart Required |
|---------|------------|------------------|
| CDS Backend | ✅ Nodemon | Only for package.json changes |
| CDS Frontend | ✅ Vite HMR | Only for config changes |
| EV Lab API | ✅ FastAPI --reload | Only for requirements.txt changes |
| EV Lab Frontend | ✅ Next.js Fast Refresh | Only for config changes |
| PyBaMM Scripts | ❌ Manual | Volume mounted, but must re-run experiment |
| Database Schemas | ❌ Manual | Must run migrations |
| Docker Compose | ❌ Manual | Must recreate services |

**Restart Individual Service:**

```bash
# Restart single service without affecting others
docker-compose -f infrastructure/docker-compose.yml restart cds-backend

# Rebuild and restart (after Dockerfile changes)
docker-compose -f infrastructure/docker-compose.yml up -d --build cds-backend

# View logs for specific service
./scripts/logs.sh ev-lab-api-gateway
```

---

## Testing Strategies

### Integration Test Matrix

| Test Scenario | CDS Component | EV Lab Component | Expected Outcome | Priority |
|---------------|---------------|------------------|------------------|----------|
| **SSO Happy Path** | SSO token generator | SSO validator | User auto-provisioned, redirected to lab | P0 (Critical) |
| **SSO Expired Token** | SSO token generator (30-min exp) | SSO validator | HTTP 401, "Token has expired" | P0 |
| **SSO Invalid Secret** | JWT_SECRET=different | JWT_SECRET=different | HTTP 401, "Invalid SSO token" | P0 |
| **SSO Institution Not Found** | Valid token, org not in EV Lab | Institution lookup | HTTP 404, "Institution not registered" | P1 |
| **SSO Feature Disabled** | org.evLabSsoEnabled=false | N/A | HTTP 403, "SSO not enabled" | P1 |
| **Result Happy Path** | Webhook receiver | SDK submit_result | Result stored, HTTP 200 | P0 (Critical) |
| **Result Invalid API Key** | Webhook receiver | SDK with wrong key | HTTP 401, "Invalid API key" | P0 |
| **Result Link Not Found** | Webhook receiver | Unlinked exercise | HTTP 404, "Lab exercise link not found" | P1 |
| **Result Org Mismatch** | Webhook receiver | Student from different org | HTTP 403, "Organization mismatch" | P0 (Security) |
| **Result Idempotency** | Webhook receiver (upsert) | Submit same result twice | Only 1 record created | P0 |
| **Result Retry Success** | Webhook receiver (down, then up) | SDK retry 3x | Result stored after retry | P1 |
| **Multi-Tenant Isolation** | Query with org filter | Query with institution filter | No cross-org data leakage | P0 (Security) |

### Test Case Example: SSO Happy Path

**File:** `tests/integration/test_sso_flow.py` (to be created)

```python
import pytest
from datetime import datetime, timedelta
import jwt
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_sso_happy_path(
    test_organization,
    test_student,
    test_session,
    test_institution,
    jwt_secret
):
    """Test complete SSO flow from token generation to user auto-provisioning."""

    # Step 1: Generate SSO token in CDS
    async with AsyncClient(base_url="http://cds-backend:3001") as client:
        response = await client.post(
            f"/api/integrations/lab-platforms/ev-lab/sso-token",
            json={
                "studentId": str(test_student.id),
                "sessionId": str(test_session.id),
                "returnUrl": "/experiments/basic_discharge"
            },
            headers={"Authorization": f"Bearer {cds_auth_token}"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

        sso_url = data["data"]["ssoUrl"]
        token = sso_url.split("token=")[1].split("&")[0]

        # Verify token payload
        decoded = jwt.decode(token, jwt_secret, algorithms=["HS256"])
        assert decoded["cds_student_id"] == str(test_student.id)
        assert decoded["cds_organization_id"] == str(test_organization.id)
        assert decoded["cds_session_id"] == str(test_session.id)
        assert decoded["email"] == test_student.email
        assert decoded["name"] == test_student.name

        # Verify expiry (30 minutes)
        exp_time = datetime.fromtimestamp(decoded["exp"])
        now = datetime.utcnow()
        assert (exp_time - now) > timedelta(minutes=29)
        assert (exp_time - now) < timedelta(minutes=31)

    # Step 2: Validate token in EV Lab
    async with AsyncClient(base_url="http://ev-lab-api-gateway:8000") as client:
        response = await client.get(
            f"/api/sso/login",
            params={
                "token": token,
                "returnUrl": "/experiments/basic_discharge"
            },
            follow_redirects=False
        )

        # Should redirect with Set-Cookie
        assert response.status_code == 303
        assert "Location" in response.headers
        assert response.headers["Location"] == "/experiments/basic_discharge"

        # Verify EV Lab token set in cookie
        cookies = response.cookies
        assert "access_token" in cookies
        ev_lab_token = cookies["access_token"]

        # Decode EV Lab token
        ev_decoded = jwt.decode(ev_lab_token, jwt_secret, algorithms=["HS256"])
        assert ev_decoded["email"] == test_student.email
        assert ev_decoded["role"] == "student"
        assert "institution_id" in ev_decoded

    # Step 3: Verify user created in EV Lab database
    async with get_db() as db:
        result = await db.execute(
            select(User).where(User.email == test_student.email)
        )
        user = result.scalar_one()

        assert user.first_name == test_student.name.split()[0]
        assert user.role == "student"
        assert user.is_active is True
        assert user.approval_status == "approved"
        assert user.email_verified is True
        assert user.password_hash == ""  # No password for SSO users

        # Verify SSO mapping created
        result = await db.execute(
            select(UserSSOMapping).where(
                UserSSOMapping.cds_student_id == test_student.id
            )
        )
        mapping = result.scalar_one()

        assert mapping.user_id == user.id
        assert mapping.cds_organization_id == test_organization.id
        assert mapping.login_count == 1
```

### Test Case Example: Result Submission with Retry

**File:** `tests/integration/test_result_retry.py` (to be created)

```python
import pytest
from datetime import datetime
from sdk.python.cds_lab_sdk import CDSLabSDK, ResultSubmission, ResultStatus
import asyncio

@pytest.mark.asyncio
async def test_result_submission_retry_on_network_failure(
    test_student,
    test_session,
    test_lab_link,
    monkeypatch
):
    """Test SDK retry logic when CDS is temporarily unavailable."""

    sdk = CDSLabSDK(
        cds_base_url="http://cds-backend:3001",
        lab_platform_id="ev-lab",
        api_key=os.getenv("CDS_API_KEY"),
        jwt_secret=os.getenv("JWT_SECRET"),
        max_retries=3
    )

    result = ResultSubmission(
        session_id=str(test_session.id),
        student_id=str(test_student.id),
        exercise_id="basic_discharge",
        status=ResultStatus.COMPLETED,
        score=85.5,
        max_score=100.0,
        passed=True
    )

    # Simulate network failure for first 2 attempts
    call_count = 0
    original_post = sdk.client.post

    async def mock_post(*args, **kwargs):
        nonlocal call_count
        call_count += 1

        if call_count <= 2:
            # First 2 attempts fail
            raise httpx.RequestError("Connection refused")
        else:
            # Third attempt succeeds
            return await original_post(*args, **kwargs)

    monkeypatch.setattr(sdk.client, "post", mock_post)

    # Submit with retry (should succeed on 3rd attempt)
    start_time = datetime.utcnow()
    response = await sdk.submit_result_with_retry(result)
    end_time = datetime.utcnow()

    # Verify success
    assert response.success is True
    assert response.result_id is not None

    # Verify retry count
    assert call_count == 3

    # Verify exponential backoff (4s + 8s = ~12s total)
    elapsed = (end_time - start_time).total_seconds()
    assert elapsed > 11  # At least 4s + 8s - 1s tolerance
    assert elapsed < 15  # But not too long

    # Verify result stored in CDS
    async with get_cds_db() as db:
        result_db = await db.execute(
            select(LabExerciseResult).where(
                LabExerciseResult.student_id == test_student.id,
                LabExerciseResult.link_id == test_lab_link.id
            )
        )
        stored_result = result_db.scalar_one()

        assert stored_result.status == "completed"
        assert stored_result.score == 85.5
```

---

## Troubleshooting Guide

### Issue 1: "Invalid SSO token" Error

**Symptom:**
```json
{
  "detail": "Invalid SSO token: Signature verification failed"
}
```

**Root Cause:** JWT_SECRET mismatch between CDS and EV Lab.

**Diagnosis:**

```bash
# Check CDS JWT_SECRET
docker-compose -f infrastructure/docker-compose.yml exec cds-backend env | grep JWT_SECRET

# Check EV Lab JWT_SECRET
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-api-gateway env | grep JWT_SECRET

# Compare (must be identical)
```

**Fix:**

```bash
# 1. Edit .env file
nano .env
# Ensure JWT_SECRET is same for both platforms

# 2. Restart services
./scripts/stop.sh
./scripts/start.sh

# 3. Verify fix
curl -X GET "http://localhost:8010/api/sso/login?token=<new-token>"
```

---

### Issue 2: "Institution not registered" Error

**Symptom:**
```json
{
  "detail": "Institution not registered or SSO not enabled. Contact administrator."
}
```

**Root Cause:** CDS Organization not mapped to EV Lab Institution.

**Diagnosis:**

```bash
# Check CDS Organization
ORG_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM organizations WHERE name = 'Test University';" | xargs)
echo "CDS Organization ID: $ORG_ID"

# Check if Institution exists in EV Lab
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT id, name, cds_organization_id, cds_enabled, cds_sso_enabled FROM institutions WHERE cds_organization_id = '$ORG_ID';"
# Expected: 1 row with cds_enabled=true, cds_sso_enabled=true
# Actual: 0 rows (NOT FOUND)
```

**Fix:**

```bash
# Create Institution in EV Lab mapped to CDS Organization
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c "
INSERT INTO institutions (
  id,
  name,
  domain,
  subdomain,
  contact_email,
  cds_organization_id,
  cds_enabled,
  cds_sso_enabled,
  status,
  subscription_status,
  student_seats,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'Test University',
  'test-university.edu',
  'test-uni',
  'admin@test-university.edu',
  '$ORG_ID',
  true,
  true,
  'active',
  'active',
  100,
  NOW(),
  NOW()
);"

# Verify creation
docker-compose -f infrastructure/docker-compose.yml exec ev-lab-db psql -U ev_lab_user -d ev_lab_integration -c \
  "SELECT id, name, cds_organization_id, cds_enabled, cds_sso_enabled FROM institutions WHERE cds_organization_id = '$ORG_ID';"
```

---

### Issue 3: Webhook Returns "Lab exercise link not found"

**Symptom:**
```json
{
  "success": false,
  "message": "Lab exercise link not found",
  "errors": ["No link found for session ... and exercise ..."]
}
```

**Root Cause:** Session does not have a `LabExerciseLink` for the submitted exercise.

**Diagnosis:**

```bash
# Check if link exists
SESSION_ID="<from-webhook-payload>"
EXERCISE_ID="<from-webhook-payload>"

docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT id, session_id, exercise_id, lab_platform_id FROM lab_exercise_links WHERE session_id = '$SESSION_ID' AND exercise_id = '$EXERCISE_ID';"
# Expected: 1 row
# Actual: 0 rows
```

**Fix:**

```bash
# Get lab platform ID
LAB_PLATFORM_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT id FROM lab_platforms WHERE platform_id = 'ev-lab';" | xargs)

# Get organization ID from session
ORG_ID=$(docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -t -c \
  "SELECT i.organization_id FROM sessions s
   JOIN batches b ON s.batch_id = b.id
   JOIN instructors i ON b.instructor_id = i.id
   WHERE s.id = '$SESSION_ID';" | xargs)

# Create lab exercise link
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c "
INSERT INTO lab_exercise_links (
  id,
  session_id,
  lab_platform_id,
  exercise_id,
  exercise_name,
  launch_url,
  organization_id,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  '$SESSION_ID',
  '$LAB_PLATFORM_ID',
  'basic_discharge',
  'Basic Battery Discharge',
  '/experiments/basic_discharge',
  '$ORG_ID',
  NOW(),
  NOW()
);"

# Verify creation
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -d cds_integration -c \
  "SELECT id, exercise_id, exercise_name FROM lab_exercise_links WHERE session_id = '$SESSION_ID';"
```

---

### Issue 4: Services Won't Start / Port Conflicts

**Symptom:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:3010: bind: address already in use
```

**Root Cause:** Another process using integration ports.

**Diagnosis:**

```bash
# Check what's using port 3010
lsof -i :3010

# Check all integration ports
for port in 3010 3011 3020 8010 8011 8012 8013 5433 5434 6380 6381; do
  echo "Port $port:"
  lsof -i :$port
done
```

**Fix:**

```bash
# Option 1: Kill conflicting processes
lsof -ti :3010 | xargs kill -9

# Option 2: Stop demo environments (if running)
cd /Volumes/Dev/Reynlab_CDS
docker-compose down

cd /Volumes/Dev/Integrated_EV_Lab
docker-compose down

# Option 3: Change integration ports (edit docker-compose.yml)
nano infrastructure/docker-compose.yml
# Change ports: "3010:3000" → "4010:3000" (example)

# Restart integration
cd /Volumes/Dev/CDS_Lab_Integration
./scripts/start.sh
```

---

### Issue 5: Database Migration Failures

**Symptom:**
```
Error: P1001: Can't reach database server at `cds-db:5432`
```

**Root Cause:** Database not ready before migration runs.

**Diagnosis:**

```bash
# Check database health
docker-compose -f infrastructure/docker-compose.yml exec cds-db pg_isready -U cds_user

# Check if database exists
docker-compose -f infrastructure/docker-compose.yml exec cds-db psql -U cds_user -l
```

**Fix:**

```bash
# 1. Wait for database to be healthy
docker-compose -f infrastructure/docker-compose.yml up -d cds-db
sleep 10
docker-compose -f infrastructure/docker-compose.yml exec cds-db pg_isready -U cds_user

# 2. Run migrations manually
docker-compose -f infrastructure/docker-compose.yml exec cds-backend npx prisma migrate deploy

# 3. If migrations corrupted, reset and re-run
docker-compose -f infrastructure/docker-compose.yml exec cds-backend npx prisma migrate reset --force
docker-compose -f infrastructure/docker-compose.yml exec cds-backend npx prisma migrate deploy
```

---

## Appendix: Environment Variable Reference

```bash
# ==================================================================
# Shared Configuration (MUST BE IDENTICAL)
# ==================================================================
JWT_SECRET=<openssl rand -base64 32>  # Min 32 chars, used by both CDS and EV Lab

# ==================================================================
# CDS Configuration
# ==================================================================
CDS_DB_NAME=cds_integration
CDS_DB_USER=cds_user
CDS_DB_PASSWORD=<secure-password>

# Ports (different from demo: 3000, 3001, 5432, 6379)
CDS_FRONTEND_PORT=3010
CDS_BACKEND_PORT=3011
CDS_DB_PORT=5433
CDS_REDIS_PORT=6380

# EV Lab Integration
EV_LAB_BASE_URL=http://localhost:3020          # Frontend URL (browser redirect)
EV_LAB_API_URL=http://localhost:8010           # API URL (server-to-server)
EV_LAB_API_KEY=<openssl rand -base64 32>       # For webhook authentication (CDS → EV Lab)

# ==================================================================
# EV Lab Configuration
# ==================================================================
EV_LAB_DB_NAME=ev_lab_integration
EV_LAB_DB_USER=ev_lab_user
EV_LAB_DB_PASSWORD=<secure-password>

# Ports (different from demo: 3000, 8000, 5432, 6379)
EV_LAB_FRONTEND_PORT=3020
EV_LAB_API_PORT=8010
EV_LAB_DB_PORT=5434
EV_LAB_REDIS_PORT=6381
PYBAMM_PORT=8011
EVSIM_PORT=8012
LIIONPACK_PORT=8013

# CDS Integration
CDS_BASE_URL=http://localhost:3010             # CDS Frontend URL
CDS_BACKEND_URL=http://localhost:3011          # CDS Backend API URL
CDS_API_KEY=<openssl rand -base64 32>          # For webhook authentication (EV Lab → CDS)
CDS_WEBHOOK_URL=http://cds-backend:3001/api/integrations/lab-results  # Docker internal URL
ENABLE_CDS_INTEGRATION=true                    # Feature flag

# ==================================================================
# Development Settings
# ==================================================================
NODE_ENV=integration
ENVIRONMENT=integration
LOG_LEVEL=debug

# Timeouts (seconds)
PYBAMM_SIMULATION_TIMEOUT=300
EVSIM_SIMULATION_TIMEOUT=120
LIIONPACK_SIMULATION_TIMEOUT=120
```

**Security Best Practices:**

1. **Generate Unique Secrets:**
   ```bash
   openssl rand -base64 32  # For JWT_SECRET
   openssl rand -base64 32  # For EV_LAB_API_KEY
   openssl rand -base64 32  # For CDS_API_KEY
   openssl rand -base64 24  # For DB passwords
   ```

2. **Never Commit `.env`:** Already in `.gitignore`

3. **Rotate Secrets Regularly:** Every 90 days recommended

4. **Use HTTPS in Production:** Add `HTTPS_ENABLED=true`, TLS certificates

5. **Separate Environments:** Use different `.env` files for dev/staging/prod

---

**Document Owner:** Winston (Architect Agent)
**Last Updated:** December 30, 2025
**Version:** 1.0
**Status:** Production-Ready Documentation

---

This architecture document provides comprehensive coverage for building and testing new features in the CDS-EV Lab Integration. For questions or updates, consult the integration team or update this document following the version control process.
