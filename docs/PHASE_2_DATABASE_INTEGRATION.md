# Phase 2: Database Integration Plan

**Start Date:** November 27, 2025
**Estimated Duration:** 3-5 days
**Dependencies:** Phase 1 Complete ✅

---

## 📋 Overview

Phase 2 integrates the CDS and EV Lab databases to enable:
1. **Federated Multi-Tenancy** - Bidirectional tenant mapping
2. **SSO Authentication** - Single sign-on with JWT tokens
3. **Webhook Results** - Automatic sync of lab results to CDS
4. **User Provisioning** - Auto-create users across platforms

---

## 🗄️ Current Database State

### CDS Database (Prisma - TypeScript)

**Existing Models:**
- ✅ `Organization` - Root tenant entity
- ✅ `Student` - Learners in batches
- ✅ `Session` - Teaching sessions
- ✅ `LabPlatform` - External lab registry **(Already exists!)**
- ✅ `LabExerciseLink` - Session-to-exercise mapping **(Already exists!)**
- ✅ `LabExerciseResult` - Lab results **(Already exists!)**

**CDS has lab integration models already!** We just need to:
1. Add tenant mapping field
2. Register EV Lab as a platform
3. Enable webhook endpoint

### EV Lab Database (SQLAlchemy - Python)

**Existing Models:**
- ✅ `Institution` - Tenant entity (multi-tenancy)
- ✅ `User` - Users with roles (student, instructor, admin)
- ✅ `ExperimentRun` - Experiment execution records
- ✅ `Progress` - Learning progress tracking
- ✅ `RefreshToken` - JWT refresh tokens

**EV Lab needs:**
1. Tenant mapping field
2. SSO validation logic
3. Webhook submission logic (already in architecture doc)

---

## 🔗 Tenant Mapping Strategy

### Option: Bidirectional Foreign Keys (Recommended)

**CDS Side:**
```prisma
model Organization {
  id             String  @id @default(uuid())
  name           String

  // NEW: EV Lab integration
  evLabInstitutionId String? @unique // Maps to EV Lab Institution.id

  // Existing fields...
  locations      Location[]
  labPlatforms   LabPlatform[]
}
```

**EV Lab Side:**
```python
class Institution(Base):
    __tablename__ = "institutions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    # NEW: CDS integration
    cds_organization_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        unique=True,
        nullable=True,
        index=True
    )

    # Existing fields...
    users: Mapped[List["User"]] = relationship("User", back_populates="institution")
```

**Advantages:**
- ✅ Simple bidirectional lookup
- ✅ No additional junction table
- ✅ Nullable for gradual migration
- ✅ Unique constraint ensures 1:1 mapping

---

## 📝 Database Schema Changes

### Task 1: CDS Schema Changes

**File:** `cds/backend/prisma/schema.prisma`

**Changes:**
```prisma
model Organization {
  id                   String   @id @default(uuid())
  name                 String
  createdAt            DateTime @default(now())
  updatedAt            DateTime @updatedAt

  // NEW: Lab Platform Integration
  evLabInstitutionId   String?  @unique // Maps to EV Lab Institution.id (UUID)
  evLabEnabled         Boolean  @default(false) // Feature flag for EV Lab integration
  evLabSsoEnabled      Boolean  @default(false) // Enable SSO for this organization

  locations      Location[]
  courses        Course[]
  instructors    Instructor[]
  labPlatforms   LabPlatform[]

  @@map("organizations")
}
```

**Migration Command:**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds/backend
npx prisma migrate dev --name add_evlab_integration
```

### Task 2: EV Lab Schema Changes

**File:** `labs/ev-lab/docker/api-gateway/database/models.py`

**Changes:**
```python
class Institution(Base):
    """Institution model with CDS integration."""

    __tablename__ = "institutions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    domain: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    subdomain: Mapped[str] = mapped_column(String(63), unique=True, nullable=False, index=True)

    # NEW: CDS Integration Fields
    cds_organization_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        unique=True,
        nullable=True,
        index=True,
        comment="Maps to CDS Organization.id for SSO and result sync"
    )
    cds_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="Feature flag: Enable CDS integration for this institution"
    )
    cds_sso_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="Feature flag: Enable SSO login from CDS"
    )
    cds_webhook_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        comment="Feature flag: Send experiment results to CDS webhook"
    )

    # Existing fields...
    contact_email: Mapped[str] = mapped_column(String(255), nullable=False)
    available_labs: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    users: Mapped[List["User"]] = relationship("User", back_populates="institution")
```

**Migration Command:**
```bash
# Create Alembic migration
cd /Volumes/Dev/CDS_Lab_Integration/labs/ev-lab/docker/api-gateway
alembic revision --autogenerate -m "Add CDS integration fields to institutions"
alembic upgrade head
```

### Task 3: User Mapping Table (EV Lab)

**New Model:** `UserSSOMapping`

```python
class UserSSOMapping(Base):
    """
    Maps CDS students to EV Lab users for SSO.

    Supports multiple CDS organizations per EV Lab user (e.g., instructor teaches at multiple orgs).
    """

    __tablename__ = "user_sso_mappings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # EV Lab side
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    institution_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("institutions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    # CDS side
    cds_student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="CDS Student.id"
    )
    cds_organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
        comment="CDS Organization.id"
    )

    # SSO metadata
    first_login_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_login_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    login_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="sso_mappings")
    institution: Mapped["Institution"] = relationship("Institution")

    # Constraints
    __table_args__ = (
        Index('idx_cds_student_org', 'cds_student_id', 'cds_organization_id', unique=True),
        Index('idx_user_institution', 'user_id', 'institution_id'),
    )
```

---

## 🔐 SSO Authentication Flow

### Step 1: CDS Generates SSO Token

**File:** `cds/backend/src/routes/lab-integration.routes.ts`

```typescript
// Generate SSO token for lab launch
router.post('/lab-platforms/:platformId/sso-token', async (req, res) => {
  const { platformId } = req.params;
  const { studentId, sessionId } = req.body;

  // 1. Verify student belongs to organization
  const student = await prisma.student.findUnique({
    where: { id: studentId },
    include: {
      batch: {
        include: {
          instructor: {
            include: { organization: true }
          }
        }
      }
    }
  });

  if (!student) {
    return res.status(404).json({ error: 'Student not found' });
  }

  const organization = student.batch.instructor.organization;

  // 2. Verify lab platform is registered
  const labPlatform = await prisma.labPlatform.findFirst({
    where: {
      platformId,
      organizationId: organization.id,
      status: 'active'
    }
  });

  if (!labPlatform) {
    return res.status(404).json({ error: 'Lab platform not found' });
  }

  // 3. Generate JWT token (30-minute expiry)
  const payload = {
    cds_student_id: student.id,
    cds_organization_id: organization.id,
    cds_session_id: sessionId,
    email: student.email,
    name: student.name,
    role: 'student',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 1800 // 30 minutes
  };

  const token = jwt.sign(payload, process.env.JWT_SECRET);

  // 4. Build SSO launch URL
  const ssoUrl = new URL(labPlatform.ssoEndpoint, labPlatform.baseUrl);
  ssoUrl.searchParams.set('token', token);
  ssoUrl.searchParams.set('returnUrl', req.body.returnUrl || '/');

  res.json({
    ssoUrl: ssoUrl.toString(),
    expiresIn: 1800,
    token // For debugging (remove in production)
  });
});
```

### Step 2: EV Lab Validates SSO Token

**File:** `labs/ev-lab/docker/api-gateway/routes/sso_routes.py`

```python
from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import jwt
import logging

router = APIRouter(prefix="/sso", tags=["SSO"])
logger = logging.getLogger(__name__)

@router.get("/login")
async def sso_login(
    token: str = Query(..., description="JWT token from CDS"),
    returnUrl: str = Query("/", description="Redirect URL after login"),
    db: AsyncSession = Depends(get_db)
):
    """
    SSO login endpoint for CDS integration.

    Flow:
    1. Validate JWT token
    2. Find or create user
    3. Create user session
    4. Redirect to returnUrl
    """

    try:
        # 1. Decode and validate JWT
        payload = jwt.decode(
            token,
            os.getenv("JWT_SECRET"),
            algorithms=["HS256"]
        )

        required_fields = ["cds_student_id", "cds_organization_id", "email", "name"]
        for field in required_fields:
            if field not in payload:
                raise HTTPException(status_code=400, detail=f"Missing field: {field}")

        # 2. Find institution by CDS organization ID
        result = await db.execute(
            select(Institution).where(
                Institution.cds_organization_id == payload["cds_organization_id"],
                Institution.cds_enabled == True,
                Institution.cds_sso_enabled == True
            )
        )
        institution = result.scalar_one_or_none()

        if not institution:
            raise HTTPException(
                status_code=404,
                detail="Institution not registered or SSO not enabled"
            )

        # 3. Find or create user
        result = await db.execute(
            select(User).where(User.email == payload["email"])
        )
        user = result.scalar_one_or_none()

        if not user:
            # Auto-provision user
            user = User(
                email=payload["email"],
                first_name=payload["name"].split()[0],
                last_name=" ".join(payload["name"].split()[1:]) if len(payload["name"].split()) > 1 else "",
                role=payload.get("role", "student"),
                institution_id=institution.id,
                password_hash="",  # No password for SSO users
                is_active=True,
                approval_status="approved",
                email_verified=True
            )
            db.add(user)
            await db.flush()

        # 4. Find or create SSO mapping
        result = await db.execute(
            select(UserSSOMapping).where(
                UserSSOMapping.cds_student_id == payload["cds_student_id"],
                UserSSOMapping.cds_organization_id == payload["cds_organization_id"]
            )
        )
        mapping = result.scalar_one_or_none()

        if not mapping:
            mapping = UserSSOMapping(
                user_id=user.id,
                institution_id=institution.id,
                cds_student_id=payload["cds_student_id"],
                cds_organization_id=payload["cds_organization_id"],
                login_count=1
            )
            db.add(mapping)
        else:
            mapping.login_count += 1
            mapping.last_login_at = datetime.now(timezone.utc)

        await db.commit()

        # 5. Generate EV Lab access token
        access_token = create_access_token(
            data={
                "user_id": str(user.id),
                "email": user.email,
                "role": user.role,
                "institution_id": str(institution.id),
                "cds_session_id": payload.get("cds_session_id")  # Pass through
            }
        )

        # 6. Set cookie and redirect
        response = RedirectResponse(url=returnUrl, status_code=303)
        response.set_cookie(
            key="access_token",
            value=access_token,
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=86400  # 24 hours
        )

        logger.info(f"SSO login successful: user={user.email}, org={institution.name}")

        return response

    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="SSO token expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid SSO token: {str(e)}")
    except Exception as e:
        logger.error(f"SSO login failed: {str(e)}")
        raise HTTPException(status_code=500, detail="SSO login failed")
```

---

## 🔄 Webhook Result Submission

### Implementation Status

✅ **Already designed in architecture document** (lines 800-870)

**Key Components:**
1. `LabExerciseResult` Pydantic model in SDK
2. `submit_result_with_retry()` method with exponential backoff
3. CDS webhook endpoint validates and stores results
4. Idempotent upsert (prevents duplicates)

**No changes needed!** Just need to:
1. Register EV Lab in CDS `LabPlatform` table
2. Configure webhook URL in `.env`

---

## 🧪 Testing Plan

### Test 1: Tenant Mapping
```sql
-- CDS
INSERT INTO organizations (id, name, evLabInstitutionId)
VALUES ('org-123', 'Test University', 'inst-456');

-- EV Lab
INSERT INTO institutions (id, name, cds_organization_id)
VALUES ('inst-456', 'Test University', 'org-123');

-- Verify bidirectional lookup
SELECT * FROM organizations WHERE evLabInstitutionId = 'inst-456';
SELECT * FROM institutions WHERE cds_organization_id = 'org-123';
```

### Test 2: SSO Flow
```bash
# 1. Generate SSO token from CDS
curl -X POST http://localhost:3011/api/lab-platforms/battery-lab/sso-token \
  -H "Content-Type: application/json" \
  -d '{
    "studentId": "student-123",
    "sessionId": "session-456",
    "returnUrl": "/experiments/basic_discharge"
  }'

# 2. Follow SSO URL to EV Lab
# Should auto-create user and redirect to returnUrl

# 3. Verify user created
curl http://localhost:8010/api/users/me \
  -H "Cookie: access_token=..."
```

### Test 3: Webhook Result Submission
```python
# Run experiment in EV Lab
# Check CDS database for result

from prisma import Prisma

prisma = Prisma()
await prisma.connect()

result = await prisma.labexerciseresult.find_first(
    where={
        "link": {
            "exerciseId": "basic_discharge"
        }
    }
)

print(result)  # Should show submitted result
```

---

## 📅 Implementation Timeline

### Day 1: Database Schema Changes
- ✅ Add CDS organization mapping field
- ✅ Add EV Lab institution mapping field
- ✅ Create UserSSOMapping table
- ✅ Run migrations on both databases

### Day 2: SSO Implementation
- ✅ Implement CDS SSO token generation endpoint
- ✅ Implement EV Lab SSO validation endpoint
- ✅ Add user auto-provisioning logic
- ✅ Test SSO flow end-to-end

### Day 3: Webhook Integration
- ✅ Register EV Lab in CDS LabPlatform table
- ✅ Configure webhook URLs in .env
- ✅ Test result submission flow
- ✅ Verify idempotent upserts

### Day 4: Integration Testing
- ✅ Full SSO flow (CDS → EV Lab → Return)
- ✅ Experiment execution and result sync
- ✅ Multi-tenant isolation testing
- ✅ Error handling and edge cases

### Day 5: Documentation & Cleanup
- ✅ Update integration guides
- ✅ Create runbook for common issues
- ✅ Performance testing
- ✅ Security audit

---

## 🚀 Next Actions

1. **Review this plan** and approve schema changes
2. **Create database migrations** for both platforms
3. **Implement SSO endpoints** in both CDS and EV Lab
4. **Test end-to-end flow** with integration environment
5. **Deploy to production** with feature flags

---

**Plan Created By:** Winston (Architect)
**Date:** November 27, 2025
**Status:** 📋 Ready for Implementation

