# CDS-EV Lab Integration Architecture

**Version:** 2.0
**Date:** November 26, 2025
**Status:** Architecture Design
**Architect:** Winston

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Integration Workspace Strategy](#integration-workspace-strategy)
4. [Multi-Tenant Integration Architecture](#multi-tenant-integration-architecture)
5. [Technical Integration Design](#technical-integration-design)
6. [Future Lab Extensibility](#future-lab-extensibility)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Risk Analysis & Mitigation](#risk-analysis--mitigation)

---

## Executive Summary

### Purpose

This document defines the architecture for integrating **Reynlab CDS (Content Delivery System)** with **EV Lab (Battery Lab V3)** while:
- Preserving existing demo environments (untouched)
- Maintaining multi-tenancy in both systems
- Enabling future addition of multiple lab platforms
- Creating a production-ready integration workspace

### Architecture Pattern: Hub-and-Spoke with Federated Multi-Tenancy

```
┌─────────────────────────────────────────────────────────────┐
│                    CDS (Hub Platform)                        │
│  Multi-Tenant: Organizations → Batches → Students           │
│  - SSO Token Generation (JWT)                                │
│  - Lab Platform Registry                                     │
│  - Unified Progress Tracking                                 │
│  - Multi-Organization Support                                │
└──────┬──────────────────────┬──────────────────────────────┘
       │                      │
   SSO Launch            Webhook Results
   (JWT Token)           (API Key Auth)
       │                      │
       ├──────────────────────┴──────────────────────┐
       │                                              │
       ▼                                              ▼
┌──────────────────┐                        ┌──────────────────┐
│   EV Lab         │                        │  Future Lab 2    │
│   (Spoke 1)      │                        │  (Spoke N)       │
│                  │                        │                  │
│  Multi-Tenant:   │                        │  Multi-Tenant:   │
│  Institutions    │                        │  (Any Model)     │
│  - SSO Auth      │                        │  - SSO Auth      │
│  - Experiments   │                        │  - Experiments   │
│  - Results       │                        │  - Results       │
│  - Progress      │                        │  - Progress      │
└──────────────────┘                        └──────────────────┘
```

### Key Design Decisions

1. **Federated Multi-Tenancy**: Each system maintains its own tenant model; mapping occurs at integration layer
2. **SSO-First Authentication**: Single sign-on prevents duplicate credentials and provides seamless UX
3. **Async Result Submission**: Labs push results asynchronously with retry logic (no polling)
4. **Lab Platform Registry**: CDS maintains registry of available lab platforms (extensible)
5. **Workspace Isolation**: Integration workspace separate from demo environments

---

## Current State Analysis

### System 1: Reynlab CDS

**Location:** `/Volumes/Dev/Reynlab_CDS/`

**Architecture:**
- **Stack:** Node.js + Express + Prisma + PostgreSQL + Redis
- **Frontend:** React + TypeScript + Tailwind CSS
- **Multi-Tenancy Model:**
  ```
  Organization (Top Level)
    └── Instructor
        └── Batch
            └── Student
                └── Session (Lecture/Lab)
  ```

**Key Features:**
- Course/session management
- Teaching point compliance tracking
- QR code-based student check-ins
- Learning outcome tracking (OBE)
- Multi-organization support

**Database Models (Relevant to Integration):**
- `Organization` - Training institutions/companies
- `Instructor` - Teachers/trainers
- `Batch` - Student cohorts
- `Student` - End users
- `Session` - Lecture/lab sessions
- `LabPlatform` - External lab registry (NEW)
- `LabExerciseLink` - Session → Lab exercise mapping (NEW)
- `LabExerciseResult` - Student lab results (NEW)

**Port:** 3000 (frontend), 3001 (backend)

---

### System 2: Integrated EV Lab (Battery Lab V3)

**Location:** `/Volumes/Dev/Integrated_EV_Lab/`

**Architecture:**
- **Stack:** Python + FastAPI + Docker + PostgreSQL + Redis
- **Frontend:** Next.js 14 + TypeScript + Zustand
- **Simulation Engines:**
  - PyBaMM (cell-level battery simulation)
  - EV_sim (vehicle dynamics, git submodule)
  - liionpack (battery pack simulation)
  - Motor Simulator (client-side Web Worker)
  - Charging Simulator (WebSocket state machine)

**Multi-Tenancy Model:**
```
Institution (Top Level)
  └── User (Role: super_admin, institution_admin, instructor, student)
      └── Experiment Progress
          └── Lab Sessions
```

**Key Features:**
- 50+ battery experiments across 9 modules
- Real-time simulation and visualization
- Multi-chemistry support (NMC, LFP)
- Experiment progress tracking
- Challenge system for learning
- Report generation

**Database Models (Relevant to Integration):**
- `Institution` - Educational/training institutions
- `User` - Multi-role users (students, instructors, admins)
- `ExperimentProgress` - Tracks student progress
- `LabSession` - Experiment execution records

**Ports:** 3000 (frontend), 8000 (API gateway), 8001 (PyBaMM), 8002 (EV_sim), 8003 (liionpack)

---

### Integration SDK (Already Developed)

**Location:** `/Volumes/Dev/Integrated_EV_Lab/sdk/`

**Components:**
- `typescript/cds-lab-sdk.ts` - TypeScript/JavaScript SDK (600+ lines)
- `python/cds_lab_sdk.py` - Python SDK (650+ lines)

**Key Features:**
- JWT token validation (SSO)
- Result submission with retry
- Batch operations
- Error handling and logging

**Status:** ✅ Complete, ready for integration testing

---

## Integration Workspace Strategy

### Workspace Structure

Create a new integration workspace that combines both systems without modifying originals:

```
/Volumes/Dev/
├── Reynlab_CDS/              # ORIGINAL - Keep for demos
├── Integrated_EV_Lab/        # ORIGINAL - Keep for demos
└── CDS_Lab_Integration/      # NEW - Integration workspace
    ├── cds/                  # Cloned from Reynlab_CDS
    │   ├── backend/
    │   ├── frontend/
    │   ├── .env.integration  # New environment config
    │   └── docker-compose.integration.yml
    ├── labs/                 # Labs directory
    │   ├── ev-lab/           # Cloned from Integrated_EV_Lab
    │   │   ├── docker/
    │   │   ├── frontend/
    │   │   ├── sdk/
    │   │   └── .env.integration
    │   └── future-labs/      # Placeholder for future labs
    │       └── README.md
    ├── shared/               # Shared integration components
    │   ├── types/            # Shared TypeScript types
    │   ├── constants/        # Integration constants
    │   └── utils/            # Shared utilities
    ├── infrastructure/       # Docker Compose for entire stack
    │   ├── docker-compose.yml         # Full stack
    │   ├── docker-compose.dev.yml     # Development overrides
    │   └── docker-compose.prod.yml    # Production config
    ├── docs/                 # Integration documentation
    │   ├── ARCHITECTURE.md   # This document
    │   ├── SETUP.md          # Setup instructions
    │   ├── TESTING.md        # Testing guide
    │   └── DEPLOYMENT.md     # Deployment guide
    ├── scripts/              # Integration scripts
    │   ├── setup.sh          # Initial setup
    │   ├── sync-repos.sh     # Sync from originals
    │   ├── test-integration.sh
    │   └── deploy.sh
    ├── .env.example          # Environment template
    ├── .gitignore
    └── README.md             # Integration workspace overview
```

### Workspace Setup Process

#### Phase 1: Create Integration Workspace

```bash
# Create workspace directory
mkdir -p /Volumes/Dev/CDS_Lab_Integration
cd /Volumes/Dev/CDS_Lab_Integration

# Clone CDS (not copy - use git to maintain connection)
git clone /Volumes/Dev/Reynlab_CDS cds
cd cds
git remote rename origin demo-origin
git remote add integration git@github.com:your-org/cds-integrated.git
cd ..

# Clone EV Lab
git clone /Volumes/Dev/Integrated_EV_Lab labs/ev-lab
cd labs/ev-lab
git remote rename origin demo-origin
git remote add integration git@github.com:your-org/ev-lab-integrated.git
cd ../..

# Create shared directory structure
mkdir -p shared/{types,constants,utils}
mkdir -p infrastructure
mkdir -p scripts
mkdir -p docs
```

#### Phase 2: Configure Integration Environment

Create integration-specific configurations that don't interfere with demo environments.

**File:** `infrastructure/docker-compose.yml`

```yaml
version: '3.8'

networks:
  cds-lab-network:
    driver: bridge

services:
  # ============================================
  # CDS Services
  # ============================================
  cds-db:
    image: postgres:15
    container_name: cds-postgres
    environment:
      POSTGRES_DB: cds_integration
      POSTGRES_USER: cds_user
      POSTGRES_PASSWORD: ${CDS_DB_PASSWORD}
    ports:
      - "5433:5432"  # Different from demo (5432)
    networks:
      - cds-lab-network
    volumes:
      - cds-db-data:/var/lib/postgresql/data

  cds-redis:
    image: redis:7-alpine
    container_name: cds-redis
    ports:
      - "6380:6379"  # Different from demo (6379)
    networks:
      - cds-lab-network
    volumes:
      - cds-redis-data:/data

  cds-backend:
    build: ./cds/backend
    container_name: cds-backend
    environment:
      NODE_ENV: integration
      DATABASE_URL: postgresql://cds_user:${CDS_DB_PASSWORD}@cds-db:5432/cds_integration
      REDIS_URL: redis://cds-redis:6379
      JWT_SECRET: ${JWT_SECRET}
      EV_LAB_BASE_URL: http://ev-lab-frontend:3000
      EV_LAB_API_KEY: ${EV_LAB_API_KEY}
    ports:
      - "3011:3001"  # Different from demo (3001)
    networks:
      - cds-lab-network
    depends_on:
      - cds-db
      - cds-redis

  cds-frontend:
    build: ./cds/frontend
    container_name: cds-frontend
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:3011
      NEXT_PUBLIC_ENV: integration
    ports:
      - "3010:3000"  # Different from demo (3000)
    networks:
      - cds-lab-network
    depends_on:
      - cds-backend

  # ============================================
  # EV Lab Services
  # ============================================
  ev-lab-db:
    image: postgres:15
    container_name: ev-lab-postgres
    environment:
      POSTGRES_DB: ev_lab_integration
      POSTGRES_USER: ev_lab_user
      POSTGRES_PASSWORD: ${EV_LAB_DB_PASSWORD}
    ports:
      - "5434:5432"  # Different from demo (5432)
    networks:
      - cds-lab-network
    volumes:
      - ev-lab-db-data:/var/lib/postgresql/data

  ev-lab-redis:
    image: redis:7-alpine
    container_name: ev-lab-redis
    ports:
      - "6381:6379"  # Different from demo (6379)
    networks:
      - cds-lab-network
    volumes:
      - ev-lab-redis-data:/data

  ev-lab-api-gateway:
    build: ./labs/ev-lab/docker/api-gateway
    container_name: ev-lab-api
    environment:
      ENVIRONMENT: integration
      DATABASE_URL: postgresql://ev_lab_user:${EV_LAB_DB_PASSWORD}@ev-lab-db:5432/ev_lab_integration
      REDIS_HOST: ev-lab-redis
      JWT_SECRET_KEY: ${JWT_SECRET}
      CDS_BASE_URL: http://cds-backend:3001
      CDS_API_KEY: ${CDS_API_KEY}
      ENABLE_CDS_INTEGRATION: "true"
    ports:
      - "8010:8000"  # Different from demo (8000)
    networks:
      - cds-lab-network
    depends_on:
      - ev-lab-db
      - ev-lab-redis
      - pybamm
      - ev-sim
      - liionpack

  pybamm:
    build: ./labs/ev-lab/docker/pybamm
    container_name: pybamm
    ports:
      - "8011:8001"
    networks:
      - cds-lab-network

  ev-sim:
    build: ./labs/ev-lab/docker/ev_sim
    container_name: ev-sim
    ports:
      - "8012:8002"
    networks:
      - cds-lab-network

  liionpack:
    build: ./labs/ev-lab/docker/liionpack
    container_name: liionpack
    ports:
      - "8013:8003"
    networks:
      - cds-lab-network

  ev-lab-frontend:
    build: ./labs/ev-lab/frontend
    container_name: ev-lab-frontend
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:8010
      NEXT_PUBLIC_ENV: integration
    ports:
      - "3020:3000"  # Different from demo (3000)
    networks:
      - cds-lab-network
    depends_on:
      - ev-lab-api-gateway

volumes:
  cds-db-data:
  cds-redis-data:
  ev-lab-db-data:
  ev-lab-redis-data:
```

**Key Integration Ports:**
- CDS Frontend: `3010` (demo: 3000)
- CDS Backend: `3011` (demo: 3001)
- EV Lab Frontend: `3020` (demo: 3000)
- EV Lab API: `8010` (demo: 8000)
- PostgreSQL (CDS): `5433` (demo: 5432)
- PostgreSQL (EV Lab): `5434` (demo: 5432)
- Redis (CDS): `6380` (demo: 6379)
- Redis (EV Lab): `6381` (demo: 6379)

---

## Multi-Tenant Integration Architecture

### Challenge: Different Tenancy Models

**CDS Model:**
```
Organization (e.g., "ABC Training Center")
  └── Instructor (e.g., "John Smith")
      └── Batch (e.g., "EV Technician Batch 2025-A")
          └── Student (e.g., "Jane Doe")
              └── Session (e.g., "Battery Fundamentals Lab")
```

**EV Lab Model:**
```
Institution (e.g., "ABC Training Center")
  └── User (Role: student, instructor, admin)
      └── Experiment Progress
```

### Solution: Tenant Mapping Layer

Create a **Tenant Mapping Service** that translates between both systems while preserving multi-tenancy isolation.

#### Mapping Strategy

**1. Organization → Institution Mapping**

```typescript
// CDS: Organization
interface CdsOrganization {
  id: string;
  name: string;
  domain: string;
  contactEmail: string;
}

// EV Lab: Institution
interface EvLabInstitution {
  id: string;
  name: string;
  domain: string;
  subdomain: string;
  availableLabs: string[] | null;
  cdsOrganizationId: string; // NEW: Link to CDS
}

// Mapping Logic
const mapOrganizationToInstitution = (
  cdsOrg: CdsOrganization
): Partial<EvLabInstitution> => {
  return {
    name: cdsOrg.name,
    domain: cdsOrg.domain,
    subdomain: generateSubdomain(cdsOrg.id), // e.g., "cds-abc123"
    availableLabs: null, // All labs accessible
    cdsOrganizationId: cdsOrg.id
  };
};
```

**2. User Role Mapping**

```typescript
type CdsRole = 'admin' | 'instructor' | 'student';
type EvLabRole = 'super_admin' | 'institution_admin' | 'instructor' | 'student';

const mapRole = (cdsRole: CdsRole, isOrgAdmin: boolean): EvLabRole => {
  if (cdsRole === 'admin') {
    return isOrgAdmin ? 'institution_admin' : 'instructor';
  }
  return cdsRole; // 'instructor' or 'student' map directly
};
```

**3. Session → Lab Exercise Mapping**

```typescript
// CDS: Session with Lab Exercise
interface CdsSessionWithLab {
  id: string;
  batchId: string;
  sessionName: string;
  labExercises: {
    labPlatformId: string; // "ev-lab"
    exerciseId: string;    // "basic_discharge"
    required: boolean;
  }[];
}

// EV Lab: Experiment Execution
interface EvLabExperimentRun {
  userId: string;
  experimentId: string;
  sessionMetadata: {
    cdsSessionId: string;
    cdsBatchId: string;
  };
}
```

### Multi-Tenant Data Isolation

**CDS Side:**
- All lab-related queries filter by `organizationId`
- Lab platforms can be shared or organization-specific
- Results are always scoped to the student's organization

**EV Lab Side:**
- All queries filter by `institutionId`
- Users can only access experiments within their institution's allowed labs
- Progress tracking isolated per institution

**Integration Layer:**
- SSO tokens include both `organizationId` (CDS) and mapped `institutionId` (EV Lab)
- Webhooks validate organization mapping before accepting results
- Audit logs track cross-system operations

---

## Technical Integration Design

### Component 1: SSO Authentication Flow

**Sequence Diagram:**

```mermaid
sequenceDiagram
    participant Student
    participant CDS_Frontend
    participant CDS_Backend
    participant EV_Lab_Frontend
    participant EV_Lab_API
    participant EV_Lab_DB

    Student->>CDS_Frontend: Click "Launch Battery Lab"
    CDS_Frontend->>CDS_Backend: GET /api/sso/lab-access?experimentId=basic_discharge

    Note over CDS_Backend: 1. Load user + organization<br/>2. Map to EV Lab institution<br/>3. Generate JWT token

    CDS_Backend->>CDS_Backend: Generate JWT Token<br/>(exp: 15 min)
    CDS_Backend-->>CDS_Frontend: { redirectURL, token }

    CDS_Frontend->>EV_Lab_Frontend: Redirect: /sso/login?token=<JWT>

    EV_Lab_Frontend->>EV_Lab_API: POST /api/sso/login { token }

    Note over EV_Lab_API: 1. Validate JWT signature<br/>2. Check expiry<br/>3. Extract payload

    EV_Lab_API->>EV_Lab_DB: Find/Create Institution<br/>(by cdsOrganizationId)
    EV_Lab_DB-->>EV_Lab_API: Institution

    EV_Lab_API->>EV_Lab_DB: Find/Create User<br/>(by email + institutionId)
    EV_Lab_DB-->>EV_Lab_API: User

    Note over EV_Lab_API: Generate EV Lab<br/>access token

    EV_Lab_API-->>EV_Lab_Frontend: { accessToken, user, experimentId }

    EV_Lab_Frontend->>Student: Redirect to Experiment Page<br/>(Auto-logged in)
```

**Implementation:**

```typescript
// CDS Backend: Generate SSO Token
// File: cds/backend/src/services/sso.service.ts

import jwt from 'jsonwebtoken';

interface SSOTokenPayload {
  // Standard JWT claims
  sub: string;              // User ID
  iss: 'reynlab-cds';      // Issuer
  aud: 'ev-lab';           // Audience
  exp: number;             // Expiration

  // CDS-specific claims
  email: string;
  role: 'student' | 'instructor' | 'admin';
  organizationId: string;
  organizationName: string;

  // Optional context
  sessionId?: string;
  batchId?: string;
  exerciseId?: string;
}

export class SSOService {
  static generateLabAccessToken(
    user: User,
    organization: Organization,
    exerciseId?: string,
    sessionId?: string
  ): string {
    const payload: SSOTokenPayload = {
      sub: user.id,
      iss: 'reynlab-cds',
      aud: 'ev-lab',
      exp: Math.floor(Date.now() / 1000) + (15 * 60), // 15 minutes

      email: user.email,
      role: user.role,
      organizationId: organization.id,
      organizationName: organization.name,

      exerciseId,
      sessionId
    };

    return jwt.sign(payload, process.env.JWT_SECRET!, {
      algorithm: 'HS256'
    });
  }
}
```

```python
# EV Lab Backend: Validate SSO Token
# File: labs/ev-lab/docker/api-gateway/sso_integration.py

from typing import Optional
from jose import jwt, JWTError
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from database.models import Institution, User

JWT_SECRET = os.getenv("JWT_SECRET_KEY")

class SSOTokenPayload:
    def __init__(self, payload: dict):
        self.user_id = payload.get("sub")
        self.email = payload.get("email")
        self.role = payload.get("role")
        self.organization_id = payload.get("organizationId")
        self.organization_name = payload.get("organizationName")
        self.session_id = payload.get("sessionId")
        self.exercise_id = payload.get("exerciseId")

        # Validate
        if not all([self.user_id, self.email, self.organization_id]):
            raise ValueError("Missing required fields in SSO token")

async def validate_and_process_sso(
    token: str,
    db: AsyncSession
) -> tuple[User, str]:
    """
    Validate SSO token and get/create user.
    Returns: (user, experiment_id)
    """
    try:
        # Decode JWT
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_signature": True, "verify_exp": True}
        )

        sso_data = SSOTokenPayload(payload)

        # Get or create institution
        institution = await get_or_create_institution(
            db,
            cds_org_id=sso_data.organization_id,
            cds_org_name=sso_data.organization_name
        )

        # Get or create user
        user = await get_or_create_user_from_sso(
            db,
            email=sso_data.email,
            role=sso_data.role,
            institution_id=institution.id,
            cds_user_id=sso_data.user_id
        )

        return user, sso_data.exercise_id

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid SSO token: {str(e)}"
        )

async def get_or_create_institution(
    db: AsyncSession,
    cds_org_id: str,
    cds_org_name: str
) -> Institution:
    """Find or create institution mapped to CDS organization."""

    # Try to find by CDS organization ID
    stmt = select(Institution).where(
        Institution.cds_organization_id == cds_org_id
    )
    result = await db.execute(stmt)
    institution = result.scalar_one_or_none()

    if institution:
        return institution

    # Create new institution
    subdomain = f"cds-{cds_org_id[:8]}"
    new_institution = Institution(
        name=cds_org_name,
        domain=f"{subdomain}.reynlab.edu",
        subdomain=subdomain,
        contact_email=f"admin@{subdomain}.reynlab.edu",
        status="active",
        subscription_status="active",
        student_seats=1000,
        available_labs=None,  # Access all labs
        cds_organization_id=cds_org_id
    )

    db.add(new_institution)
    await db.commit()
    await db.refresh(new_institution)

    return new_institution
```

### Component 2: Result Submission Flow

**Sequence Diagram:**

```mermaid
sequenceDiagram
    participant Student
    participant EV_Lab_Frontend
    participant EV_Lab_API
    participant CDS_Lab_SDK
    participant CDS_Backend
    participant CDS_DB

    Student->>EV_Lab_Frontend: Complete Experiment
    EV_Lab_Frontend->>EV_Lab_API: POST /api/experiment/complete

    Note over EV_Lab_API: 1. Save progress locally<br/>2. Calculate score<br/>3. Generate report

    EV_Lab_API->>EV_Lab_API: Store Experiment Run

    alt CDS Integration Enabled
        EV_Lab_API->>CDS_Lab_SDK: submit_result_with_retry()

        Note over CDS_Lab_SDK: Retry logic:<br/>Max 3 retries<br/>Exponential backoff

        CDS_Lab_SDK->>CDS_Backend: POST /api/integrations/lab-results

        Note over CDS_Backend: 1. Validate API key<br/>2. Verify organization<br/>3. Validate payload

        CDS_Backend->>CDS_DB: Store LabExerciseResult
        CDS_DB-->>CDS_Backend: Result saved

        CDS_Backend-->>CDS_Lab_SDK: { success: true }
        CDS_Lab_SDK-->>EV_Lab_API: Result submitted
    end

    EV_Lab_API-->>EV_Lab_Frontend: { success: true }
    EV_Lab_Frontend->>Student: Show completion + score
```

**Implementation:**

```python
# EV Lab: Submit Results to CDS
# File: labs/ev-lab/docker/api-gateway/experiment_completion.py

from sdk.python.cds_lab_sdk import CDSLabSDK, LabExerciseResult
from datetime import datetime

async def complete_experiment_and_sync(
    user_id: str,
    experiment_id: str,
    session_metadata: dict,
    score: float,
    max_score: float,
    time_spent_seconds: int,
    evidence_urls: list[str],
    db: AsyncSession
):
    """
    Complete experiment locally and sync results to CDS.
    """

    # 1. Save locally in EV Lab
    run = ExperimentRun(
        user_id=user_id,
        experiment_id=experiment_id,
        status="completed",
        score=score,
        max_score=max_score,
        time_spent_seconds=time_spent_seconds,
        evidence_urls=evidence_urls,
        completed_at=datetime.utcnow()
    )
    db.add(run)
    await db.commit()

    # 2. If CDS integration enabled, send results
    if os.getenv("ENABLE_CDS_INTEGRATION") == "true":
        try:
            sdk = CDSLabSDK(
                api_key=os.getenv("CDS_API_KEY"),
                webhook_url=os.getenv("CDS_WEBHOOK_URL"),
                jwt_secret=os.getenv("JWT_SECRET_KEY")
            )

            result = LabExerciseResult(
                lab_platform_id="ev-lab",
                exercise_id=experiment_id,
                session_id=session_metadata.get("cds_session_id"),
                student_id=session_metadata.get("cds_student_id"),
                status="completed",
                score=score,
                max_score=max_score,
                passed=score >= (max_score * 0.7),
                started_at=run.started_at.isoformat(),
                completed_at=run.completed_at.isoformat(),
                time_spent_seconds=time_spent_seconds,
                evidence_urls=evidence_urls,
                result_data={
                    "ev_lab_run_id": str(run.id),
                    "experiment_type": experiment_id,
                    "user_id": user_id
                }
            )

            # Submit with retry (max 3 attempts)
            await sdk.submit_result_with_retry(result, max_retries=3)

            logger.info(f"Successfully synced result to CDS for run {run.id}")

        except Exception as e:
            # Don't fail experiment completion if CDS sync fails
            logger.error(f"Failed to sync result to CDS: {str(e)}")
            # TODO: Add to retry queue for later

    return run
```

```typescript
// CDS Backend: Receive Lab Results
// File: cds/backend/src/routes/lab-integration.routes.ts

import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../db';

// Validation schema
const LabResultSchema = z.object({
  apiKey: z.string().min(32),
  labPlatformId: z.string(),
  exerciseId: z.string(),
  sessionId: z.string().uuid(),
  studentId: z.string().uuid(),
  status: z.enum(['completed', 'failed', 'in_progress']),
  score: z.number().min(0),
  maxScore: z.number().min(0),
  passed: z.boolean(),
  startedAt: z.string().datetime(),
  completedAt: z.string().datetime(),
  timeSpentSeconds: z.number().int().min(0),
  evidenceUrls: z.array(z.string().url()).optional(),
  resultData: z.record(z.any()).optional()
});

router.post('/lab-results', async (req, res, next) => {
  try {
    // 1. Validate payload
    const data = LabResultSchema.parse(req.body);

    // 2. Verify API key
    const labPlatform = await prisma.labPlatform.findUnique({
      where: { platformId: data.labPlatformId },
      include: { organization: true }
    });

    if (!labPlatform || labPlatform.apiKey !== data.apiKey) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    // 3. Verify student belongs to organization
    const student = await prisma.student.findUnique({
      where: { id: data.studentId },
      include: { batch: { include: { instructor: true } } }
    });

    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }

    if (student.batch.instructor.organizationId !== labPlatform.organizationId) {
      return res.status(403).json({ error: 'Organization mismatch' });
    }

    // 4. Find lab exercise link
    const link = await prisma.labExerciseLink.findFirst({
      where: {
        sessionId: data.sessionId,
        labPlatformId: labPlatform.id,
        exerciseId: data.exerciseId
      }
    });

    if (!link) {
      return res.status(404).json({ error: 'Lab exercise link not found' });
    }

    // 5. Upsert result (idempotent)
    const attemptNumber = await prisma.labExerciseResult.count({
      where: {
        linkId: link.id,
        studentId: student.id
      }
    }) + 1;

    const result = await prisma.labExerciseResult.upsert({
      where: {
        linkId_studentId_attemptNumber: {
          linkId: link.id,
          studentId: student.id,
          attemptNumber
        }
      },
      update: {
        status: data.status,
        score: data.score,
        maxScore: data.maxScore,
        passed: data.passed,
        startedAt: new Date(data.startedAt),
        completedAt: new Date(data.completedAt),
        timeSpentSeconds: data.timeSpentSeconds,
        evidenceUrls: data.evidenceUrls || [],
        resultData: data.resultData || {},
        updatedAt: new Date()
      },
      create: {
        linkId: link.id,
        studentId: student.id,
        attemptNumber,
        status: data.status,
        score: data.score,
        maxScore: data.maxScore,
        passed: data.passed,
        startedAt: new Date(data.startedAt),
        completedAt: new Date(data.completedAt),
        timeSpentSeconds: data.timeSpentSeconds,
        evidenceUrls: data.evidenceUrls || [],
        resultData: data.resultData || {}
      }
    });

    // 6. Audit log
    console.log(`Lab result received: ${data.labPlatformId}/${data.exerciseId} for student ${student.id}`);

    res.json({
      success: true,
      resultId: result.id,
      message: 'Result stored successfully'
    });

  } catch (error) {
    next(error);
  }
});

export default router;
```

---

## Future Lab Extensibility

### Lab Platform Registry

Every lab platform (current and future) is registered in CDS:

```typescript
// CDS Database: LabPlatform model
interface LabPlatform {
  id: string;
  platformId: string;         // Unique identifier (e.g., "ev-lab", "engine-lab")
  name: string;               // Display name
  description: string;
  category: string;           // "battery", "engine", "soldering", etc.

  // Integration endpoints
  baseUrl: string;            // https://evlab.reynlab.edu
  ssoEndpoint: string;        // /sso/login
  healthEndpoint: string;     // /health

  // Authentication
  apiKey: string;             // For webhook callbacks

  // Organization/tenant
  organizationId: string;     // Which org owns/uses this platform

  // Availability
  status: 'active' | 'inactive' | 'maintenance';

  // Metadata
  availableExercises: string[]; // List of exercise IDs
  metadata: Record<string, any>;

  createdAt: Date;
  updatedAt: Date;
}
```

### Adding a New Lab Platform

**Step-by-step process to add "Engine Maintenance Lab":**

1. **Deploy Lab Platform**
   - Can use any technology (Node.js, Python, Go, Unity, etc.)
   - Must expose two endpoints:
     - `POST /sso/login` - Accept JWT token from CDS
     - `GET /health` - Health check

2. **Integrate SDK**
   - Install TypeScript or Python SDK
   - Configure with CDS webhook URL and API key
   - Implement result submission after experiment completion

3. **Register in CDS**
   ```sql
   INSERT INTO lab_platforms (
     id, platform_id, name, description, category,
     base_url, sso_endpoint, health_endpoint,
     api_key, organization_id, status,
     available_exercises, created_at, updated_at
   ) VALUES (
     gen_random_uuid(),
     'engine-lab',
     'Engine Maintenance Lab',
     'Hands-on engine diagnostics and maintenance training',
     'automotive',
     'https://enginelab.reynlab.edu',
     '/sso/login',
     '/health',
     'generate-secure-32-char-api-key',
     'org-id-here',
     'active',
     '{"engine_diagnostics_basic", "engine_timing_belt_replacement"}',
     NOW(),
     NOW()
   );
   ```

4. **Link to Sessions**
   ```typescript
   // Instructor links engine lab exercises to training sessions
   await prisma.labExerciseLink.create({
     data: {
       sessionId: session.id,
       labPlatformId: engineLabPlatform.id,
       exerciseId: "engine_diagnostics_basic",
       launchUrl: "/experiments/engine_diagnostics_basic",
       required: true,
       passingScore: 70.0
     }
   });
   ```

5. **Students Launch Seamlessly**
   - Click "Launch Engine Lab" in CDS
   - SSO token generated with organization context
   - Redirect to Engine Lab (auto-login)
   - Complete exercise
   - Results sync back to CDS automatically

### Lab Platform Interface Contract

**Every lab platform must implement:**

```typescript
interface LabPlatformContract {
  // 1. SSO Login Endpoint
  POST /sso/login
  Query: { token: string }
  Response: {
    accessToken: string;
    user: User;
    redirectUrl: string;
  }

  // 2. Health Check
  GET /health
  Response: {
    status: "healthy" | "degraded" | "unhealthy";
    version: string;
    uptime: number;
  }

  // 3. Result Submission (using SDK)
  // No endpoint needed - lab calls CDS webhook
}
```

**Lab platform responsibilities:**
- ✅ Validate JWT tokens from CDS
- ✅ Create/map users to local tenant model
- ✅ Track experiment progress locally
- ✅ Submit results to CDS webhook after completion
- ✅ Handle errors gracefully (don't block on CDS unavailability)

**CDS responsibilities:**
- ✅ Generate valid SSO tokens
- ✅ Maintain lab platform registry
- ✅ Receive and store results
- ✅ Provide unified dashboard for instructors
- ✅ Track learning outcomes across all labs

---

## Implementation Roadmap

### Phase 1: Workspace Setup (Week 1)

**Goal:** Create integration workspace without modifying demo environments

**Tasks:**
1. ✅ Create `/Volumes/Dev/CDS_Lab_Integration/` directory structure
2. ✅ Clone CDS and EV Lab repos
3. ✅ Configure integration-specific ports and environment variables
4. ✅ Create `docker-compose.yml` for full stack
5. ✅ Write setup scripts (`scripts/setup.sh`, `scripts/sync-repos.sh`)
6. ✅ Test: Both systems run simultaneously on different ports
7. ✅ Document: Update `docs/SETUP.md`

**Acceptance Criteria:**
- Demo CDS runs on ports 3000/3001 (unchanged)
- Demo EV Lab runs on ports 3000/8000 (unchanged)
- Integration CDS runs on ports 3010/3011
- Integration EV Lab runs on ports 3020/8010
- All services healthy via `docker ps` and health checks

---

### Phase 2: Database Schema Updates (Week 1-2)

**Goal:** Add tenant mapping fields to both databases

**CDS Changes:**
```sql
-- Already implemented:
-- - LabPlatform table
-- - LabExerciseLink table
-- - LabExerciseResult table

-- Add if not exists:
ALTER TABLE students
ADD COLUMN IF NOT EXISTS external_lab_user_id VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_students_external_lab_user
ON students(external_lab_user_id);
```

**EV Lab Changes:**
```sql
-- Add CDS mapping fields
ALTER TABLE institutions
ADD COLUMN IF NOT EXISTS cds_organization_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS cds_metadata JSONB;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS cds_user_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS cds_metadata JSONB;

CREATE INDEX IF NOT EXISTS idx_institutions_cds_org
ON institutions(cds_organization_id);

CREATE INDEX IF NOT EXISTS idx_users_cds_user
ON users(cds_user_id);
```

**Tasks:**
1. ✅ Run migrations on integration databases
2. ✅ Test migrations with rollback
3. ✅ Update Prisma schema (CDS) and SQLAlchemy models (EV Lab)
4. ✅ Generate TypeScript types
5. ✅ Test: Query mapped records

---

### Phase 3: SSO Integration (Week 2-3)

**Goal:** Implement seamless SSO from CDS to EV Lab

**CDS Tasks:**
1. ✅ Implement `/api/sso/lab-access` endpoint
2. ✅ Create JWT token generation with organization context
3. ✅ Add "Launch Lab" button to session UI
4. ✅ Test token generation with various roles

**EV Lab Tasks:**
1. ✅ Implement `/api/sso/login` endpoint
2. ✅ Validate JWT tokens
3. ✅ Implement `get_or_create_institution` mapping
4. ✅ Implement `get_or_create_user` mapping
5. ✅ Generate EV Lab access tokens
6. ✅ Redirect to experiment page

**Integration Tests:**
```bash
# Test SSO flow
npm run test:integration -- sso-flow.spec.ts

# Test token validation
pytest tests/integration/test_sso_validation.py

# Test multi-tenant isolation
pytest tests/integration/test_tenant_isolation.py
```

**Acceptance Criteria:**
- Student clicks "Launch Battery Lab" in CDS → auto-logs into EV Lab
- Correct organization/institution mapping
- User roles preserved
- Token expiry handled gracefully (15 min)
- Multi-tenant data isolation verified

---

### Phase 4: Result Submission (Week 3-4)

**Goal:** Sync experiment results from EV Lab to CDS

**EV Lab Tasks:**
1. ✅ Integrate Python SDK into experiment completion flow
2. ✅ Configure CDS webhook URL and API key
3. ✅ Implement retry logic for failed submissions
4. ✅ Add background job queue (optional, for reliability)
5. ✅ Test result submission for all experiment types

**CDS Tasks:**
1. ✅ Implement `/api/integrations/lab-results` webhook receiver
2. ✅ Add API key authentication
3. ✅ Add payload validation (Zod)
4. ✅ Implement organization verification
5. ✅ Store results in `LabExerciseResult` table
6. ✅ Update session compliance calculations

**Integration Tests:**
```bash
# Test result submission
pytest tests/integration/test_result_submission.py

# Test retry logic
pytest tests/integration/test_result_retry.py

# Test multi-tenant result isolation
pytest tests/integration/test_result_tenant_isolation.py

# Test CDS webhook receiver
npm run test:integration -- lab-results-webhook.spec.ts
```

**Acceptance Criteria:**
- Experiment completion triggers result submission
- Results appear in CDS within 60 seconds
- Retry logic handles temporary failures (3 retries)
- API key validation prevents unauthorized submissions
- Multi-tenant isolation verified (org A can't submit for org B)

---

### Phase 5: Unified Dashboard (Week 4-5)

**Goal:** Create instructor dashboard showing both lecture and lab progress

**CDS Frontend Tasks:**
1. Create `LabProgressPanel` component
2. Add lab results to session compliance view
3. Show individual student lab scores
4. Export combined reports (lecture + lab)
5. Add lab exercise management UI for instructors

**UI Mockup:**
```
┌─────────────────────────────────────────────────────────┐
│ Session: Battery Fundamentals Lab                       │
│ Batch: EV Technician Batch 2025-A                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ Teaching Points Coverage: 85% (34/40)                   │
│ Lab Completion: 75% (15/20 students)                    │
│                                                          │
│ ┌─────────────────────────────────────────────────┐    │
│ │ Assigned Lab Exercises (2)                      │    │
│ ├─────────────────────────────────────────────────┤    │
│ │ ⚡ Basic Discharge (EV Lab)                     │    │
│ │    - Completed: 15/20 students                  │    │
│ │    - Avg Score: 82%                             │    │
│ │    - Avg Time: 28 min                           │    │
│ │                                                  │    │
│ │ ⚡ CC-CV Charging (EV Lab)                      │    │
│ │    - Completed: 10/20 students                  │    │
│ │    - Avg Score: 78%                             │    │
│ │    - Avg Time: 35 min                           │    │
│ └─────────────────────────────────────────────────┘    │
│                                                          │
│ ┌─────────────────────────────────────────────────┐    │
│ │ Student Progress                                │    │
│ ├──────────┬──────────┬────────┬──────────┬──────┤    │
│ │ Student  │ Lecture  │ Lab 1  │ Lab 2    │ Total│    │
│ ├──────────┼──────────┼────────┼──────────┼──────┤    │
│ │ Jane Doe │ 90%      │ 85%    │ 80%      │ 85%  │    │
│ │ John S.  │ 80%      │ 90%    │ -        │ 85%  │    │
│ │ ...      │          │        │          │      │    │
│ └──────────┴──────────┴────────┴──────────┴──────┘    │
│                                                          │
│ [Export Report] [View Details] [Add Lab Exercise]       │
└─────────────────────────────────────────────────────────┘
```

**Acceptance Criteria:**
- Instructor sees combined lecture + lab progress
- Lab scores update in real-time (< 60s latency)
- Export includes both lecture attendance and lab results
- Instructor can add/remove lab exercises from sessions
- Mobile-responsive design

---

### Phase 6: Multi-Lab Support (Week 5-6)

**Goal:** Verify architecture supports multiple lab platforms

**Tasks:**
1. Register "Mock Lab Platform" in CDS
2. Create minimal mock lab with SSO + webhook
3. Link mock lab exercise to test session
4. Test SSO flow to mock lab
5. Test result submission from mock lab
6. Verify tenant isolation across labs

**Mock Lab Requirements:**
- Simple Node.js Express app
- JWT validation using TypeScript SDK
- Single "Hello World" experiment
- Result submission after 30 seconds
- Minimal UI (just SSO login + completion button)

**Acceptance Criteria:**
- Students can launch both EV Lab and Mock Lab from same session
- Results from both labs appear in CDS
- Tenant isolation works across labs
- Documentation updated for adding new labs

---

### Phase 7: Production Readiness (Week 6-7)

**Goal:** Prepare for production deployment

**Tasks:**
1. **Security Audit**
   - JWT secret rotation strategy
   - API key management (vault integration)
   - HTTPS enforcement
   - Rate limiting on all integration endpoints
   - SQL injection prevention audit

2. **Performance Optimization**
   - Database query optimization (indexes)
   - Redis caching for lab platform registry
   - Connection pooling tuning
   - CDN for static assets

3. **Monitoring & Alerting**
   - Integration health dashboard
   - SSO success/failure rates
   - Webhook delivery success rates
   - Database performance metrics
   - Error tracking (Sentry)

4. **Documentation**
   - Deployment guide
   - Runbook for common issues
   - Architecture decision records (ADRs)
   - API documentation (Swagger/OpenAPI)

5. **Load Testing**
   - Simulate 100 concurrent SSO logins
   - Simulate 1000 result submissions/hour
   - Test database under load
   - Test Redis failover

**Acceptance Criteria:**
- All security vulnerabilities addressed
- Load tests pass at 2x expected traffic
- Monitoring dashboard operational
- Documentation complete
- Disaster recovery plan documented

---

## Risk Analysis & Mitigation

### Risk 1: JWT Secret Mismatch

**Impact:** High - SSO completely broken
**Probability:** Medium

**Mitigation:**
- Use environment variable validation on startup
- Automated test to verify token compatibility
- Document secret synchronization process
- Use secret management service (AWS Secrets Manager, Vault)

### Risk 2: Organization/Institution Mapping Conflicts

**Impact:** High - Data leakage across tenants
**Probability:** Medium

**Mitigation:**
- Comprehensive integration tests for tenant isolation
- Database constraints prevent cross-tenant queries
- Audit logging for all cross-system operations
- Regular security audits

### Risk 3: Webhook Delivery Failures

**Impact:** Medium - Results not syncing
**Probability:** High (network issues, CDS downtime)

**Mitigation:**
- Implement retry logic with exponential backoff (done in SDK)
- Add background job queue for failed submissions
- Monitor webhook delivery success rates
- Alert on sustained failures
- Keep results in lab platform as source of truth

### Risk 4: Database Migration Failures

**Impact:** High - System unusable
**Probability:** Low

**Mitigation:**
- Test migrations on staging environment first
- Backup databases before migration
- Implement rollback scripts
- Run migrations during low-traffic windows
- Have rollback plan ready

### Risk 5: Demo Environment Interference

**Impact:** High - Breaks existing demos
**Probability:** Low (with proper isolation)

**Mitigation:**
- Use completely separate ports for integration
- Separate databases for integration
- Never modify original repos
- Document port mapping clearly
- Automated tests verify demo environment unchanged

### Risk 6: Performance Degradation

**Impact:** Medium - Poor user experience
**Probability:** Medium (under high load)

**Mitigation:**
- Database indexes on all foreign keys
- Redis caching for lab platform registry
- Connection pooling configured
- Load testing before production
- Horizontal scaling plan ready

### Risk 7: Future Lab Integration Complexity

**Impact:** Low - Slower onboarding of new labs
**Probability:** Low

**Mitigation:**
- Clear documentation for lab integration
- SDK simplifies integration (2 endpoints to implement)
- Example mock lab as template
- Support team to assist new lab integrations

---

## Appendix A: Shared TypeScript Types

```typescript
// File: shared/types/integration.ts

export interface SSOTokenPayload {
  // Standard JWT claims
  sub: string;
  iss: string;
  aud: string;
  exp: number;

  // User info
  email: string;
  role: 'student' | 'instructor' | 'admin';

  // Organization mapping
  organizationId: string;
  organizationName: string;

  // Context
  sessionId?: string;
  batchId?: string;
  exerciseId?: string;
}

export interface LabExerciseResult {
  // IDs
  labPlatformId: string;
  exerciseId: string;
  sessionId: string;
  studentId: string;

  // Result data
  status: 'completed' | 'failed' | 'in_progress';
  score: number;
  maxScore: number;
  passed: boolean;

  // Timing
  startedAt: string; // ISO 8601
  completedAt: string;
  timeSpentSeconds: number;

  // Evidence
  evidenceUrls?: string[];

  // Opaque lab-specific data
  resultData?: Record<string, any>;
}

export interface LabPlatform {
  id: string;
  platformId: string;
  name: string;
  description: string;
  category: string;
  baseUrl: string;
  ssoEndpoint: string;
  healthEndpoint: string;
  status: 'active' | 'inactive' | 'maintenance';
  availableExercises: string[];
  organizationId: string;
}

export interface TenantMapping {
  cdsOrganizationId: string;
  evLabInstitutionId: string;
  cdsUserId?: string;
  evLabUserId?: string;
  createdAt: Date;
  lastSyncedAt: Date;
}
```

---

## Appendix B: Environment Variables

```bash
# File: .env.example

# ====================
# Shared Configuration
# ====================
JWT_SECRET=your-super-secret-jwt-key-min-32-chars-here

# ====================
# CDS Configuration
# ====================
CDS_DATABASE_URL=postgresql://cds_user:password@localhost:5433/cds_integration
CDS_REDIS_URL=redis://localhost:6380
CDS_FRONTEND_PORT=3010
CDS_BACKEND_PORT=3011

# EV Lab Integration
EV_LAB_BASE_URL=http://localhost:3020
EV_LAB_API_URL=http://localhost:8010
EV_LAB_API_KEY=generate-secure-32-char-api-key-here

# ====================
# EV Lab Configuration
# ====================
EV_LAB_DATABASE_URL=postgresql://ev_lab_user:password@localhost:5434/ev_lab_integration
EV_LAB_REDIS_URL=redis://localhost:6381
EV_LAB_FRONTEND_PORT=3020
EV_LAB_API_PORT=8010

# CDS Integration
CDS_BASE_URL=http://localhost:3010
CDS_BACKEND_URL=http://localhost:3011
CDS_API_KEY=generate-secure-32-char-api-key-here-different-from-above
CDS_WEBHOOK_URL=http://localhost:3011/api/integrations/lab-results
ENABLE_CDS_INTEGRATION=true

# ====================
# Development Settings
# ====================
NODE_ENV=integration
ENVIRONMENT=integration
LOG_LEVEL=debug
```

---

## Appendix C: Setup Script

```bash
#!/bin/bash
# File: scripts/setup.sh

set -e

echo "🏗️  Setting up CDS-Lab Integration Workspace..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker not found${NC}"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Docker Compose not found${NC}"; exit 1; }
command -v node >/dev/null 2>&1 || { echo -e "${RED}Node.js not found${NC}"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}Python3 not found${NC}"; exit 1; }
echo -e "${GREEN}✓ Prerequisites OK${NC}"

# Clone repos if not exists
echo -e "${BLUE}Setting up repositories...${NC}"
if [ ! -d "cds" ]; then
  echo "Cloning CDS..."
  git clone /Volumes/Dev/Reynlab_CDS cds
  cd cds
  git remote rename origin demo-origin
  cd ..
fi

if [ ! -d "labs/ev-lab" ]; then
  echo "Cloning EV Lab..."
  mkdir -p labs
  git clone /Volumes/Dev/Integrated_EV_Lab labs/ev-lab
  cd labs/ev-lab
  git remote rename origin demo-origin
  cd ../..
fi
echo -e "${GREEN}✓ Repositories ready${NC}"

# Create shared directories
echo -e "${BLUE}Creating shared directories...${NC}"
mkdir -p shared/{types,constants,utils}
mkdir -p infrastructure
mkdir -p scripts
mkdir -p docs
echo -e "${GREEN}✓ Directories created${NC}"

# Copy environment template
if [ ! -f ".env" ]; then
  echo -e "${BLUE}Creating environment file...${NC}"
  cp .env.example .env
  echo -e "${RED}⚠️  Please edit .env with your actual values${NC}"
fi

# Build Docker images
echo -e "${BLUE}Building Docker images (this may take a while)...${NC}"
cd infrastructure
docker-compose build
cd ..
echo -e "${GREEN}✓ Docker images built${NC}"

# Install CDS dependencies
echo -e "${BLUE}Installing CDS dependencies...${NC}"
cd cds/backend
npm install
cd ../../

cd cds/frontend
npm install
cd ../../
echo -e "${GREEN}✓ CDS dependencies installed${NC}"

# Install EV Lab dependencies
echo -e "${BLUE}Installing EV Lab dependencies...${NC}"
cd labs/ev-lab/frontend
npm install
cd ../../../
echo -e "${GREEN}✓ EV Lab dependencies installed${NC}"

echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Edit .env with your actual values"
echo "2. Run: docker-compose -f infrastructure/docker-compose.yml up"
echo "3. Access CDS at http://localhost:3010"
echo "4. Access EV Lab at http://localhost:3020"
```

---

## Next Steps

1. **Review this architecture** with stakeholders
2. **Approve workspace structure** and port assignments
3. **Begin Phase 1** (Workspace Setup)
4. **Weekly check-ins** to track progress
5. **Adjust timeline** based on feedback

**Questions to Answer:**
- ✅ Is the hub-and-spoke architecture acceptable?
- ✅ Is the tenant mapping strategy clear?
- ✅ Are the port assignments acceptable?
- ✅ Is the timeline realistic (7 weeks)?
- ✅ Are there additional labs planned beyond EV Lab?

---

**Document Owner:** Winston (Architect)
**Last Updated:** November 26, 2025
**Status:** Draft for Review
**Next Review:** After stakeholder feedback
