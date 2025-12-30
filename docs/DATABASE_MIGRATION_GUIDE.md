# Database Migration Guide - Phase 2 Integration

**Date:** November 27, 2025
**Status:** Schema Changes Ready, Migrations Prepared

---

## 📊 Current Database State

**Both databases are fresh (no tables yet)**:
- CDS PostgreSQL (port 5433): Empty database, awaiting Prisma migrations
- EV Lab PostgreSQL (port 5434): Empty database, awaiting SQLAlchemy initialization

**Tables will be created automatically when:**
1. CDS backend starts and runs Prisma migrations
2. EV Lab API Gateway starts and creates SQLAlchemy tables

---

## ✅ Schema Changes Completed

### CDS (Prisma Schema)

**File:** `cds/backend/prisma/schema.prisma`

**Changes:**
```prisma
model Organization {
  // ... existing fields ...

  // NEW: EV Lab Integration Fields (Phase 2)
  evLabInstitutionId String?  @unique
  evLabEnabled       Boolean  @default(false)
  evLabSsoEnabled    Boolean  @default(false)
}
```

### EV Lab (SQLAlchemy Models)

**File:** `labs/ev-lab/docker/api-gateway/database/models.py`

**Changes to Institution:**
```python
class Institution(Base):
    # ... existing fields ...

    # NEW: CDS Integration Fields (Phase 2)
    cds_organization_id: UUID | None  # Maps to CDS Organization.id
    cds_enabled: bool = False
    cds_sso_enabled: bool = False
    cds_webhook_enabled: bool = True
```

**New Model - UserSSOMapping:**
```python
class UserSSOMapping(Base):
    """Maps CDS students to EV Lab users for SSO."""

    id: UUID
    user_id: UUID  # EV Lab User.id
    institution_id: UUID  # EV Lab Institution.id
    cds_student_id: UUID  # CDS Student.id
    cds_organization_id: UUID  # CDS Organization.id
    first_login_at: datetime
    last_login_at: datetime
    login_count: int
```

---

## 🔧 Migration Files Created

### CDS Prisma Migration

**File:** `cds/backend/prisma/migrations/20251127_add_evlab_integration/migration.sql`

This migration will run automatically when you execute:
```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds/backend
npx prisma migrate dev
```

### EV Lab SQLAlchemy Migration

**File:** `labs/ev-lab/docker/api-gateway/database/migrations/add_cds_integration.sql`

This migration adds:
- CDS integration fields to `institutions` table
- New `user_sso_mappings` table
- Indexes for performance
- Automatic timestamp updates

---

## 🚀 How to Initialize Databases

### Option 1: Automatic Initialization (Recommended)

When you start the frontend/backend services for the first time, the databases will be initialized automatically:

**CDS Backend:**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds/backend
npm install
npx prisma generate
npx prisma migrate dev  # Creates all tables including integration fields
npm run dev
```

**EV Lab API Gateway:**
The API Gateway will create tables on startup using SQLAlchemy's `Base.metadata.create_all()`.

### Option 2: Manual Migration

If you need to run migrations manually:

**CDS:**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds/backend
npx prisma migrate deploy  # Run all pending migrations
npx prisma db seed  # Optional: seed test data
```

**EV Lab:**
```bash
# Copy migration SQL into container and execute
docker exec -i ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration < labs/ev-lab/docker/api-gateway/database/migrations/add_cds_integration.sql
```

---

## 🔍 Verification Steps

### After CDS Backend Starts:

```bash
# Check CDS database schema
docker exec cds-postgres-integration psql -U cds_user -d cds_integration -c "\d organizations"

# Should show:
#   evLabInstitutionId | text
#   evLabEnabled       | boolean | default false
#   evLabSsoEnabled    | boolean | default false
```

### After EV Lab API Gateway Starts:

```bash
# Check EV Lab database schema
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "\d institutions"

# Should show:
#   cds_organization_id | uuid
#   cds_enabled         | boolean | default false
#   cds_sso_enabled     | boolean | default false
#   cds_webhook_enabled | boolean | default true

# Check new table
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "\d user_sso_mappings"
```

---

## 📋 Next Steps After Database Init

Once both databases are initialized and tables exist:

1. **Register EV Lab in CDS:**
   ```sql
   INSERT INTO lab_platforms (id, "platformId", name, "baseUrl", "ssoEndpoint", "apiKey", "organizationId")
   VALUES (
     gen_random_uuid(),
     'ev-lab',
     'Battery Lab V3 - EV Integration',
     'http://localhost:3020',
     '/sso/login',
     '5XZ0FQkSghCqBUSQrWqo8/k3REjoXzxJ+S4/223FI/8=',
     '<organization_id>'  -- Replace with actual organization ID
   );
   ```

2. **Create Test Tenant Mapping:**
   ```sql
   -- CDS
   UPDATE organizations
   SET "evLabInstitutionId" = '<institution_uuid>',
       "evLabEnabled" = true,
       "evLabSsoEnabled" = true
   WHERE id = '<organization_uuid>';

   -- EV Lab
   UPDATE institutions
   SET cds_organization_id = '<organization_uuid>',
       cds_enabled = true,
       cds_sso_enabled = true
   WHERE id = '<institution_uuid>';
   ```

3. **Test SSO Flow:**
   - Generate SSO token from CDS
   - Validate token in EV Lab
   - Verify user auto-provisioning
   - Check SSO mapping table

---

## 🐛 Troubleshooting

### Problem: "relation does not exist" error

**Cause:** Database tables haven't been created yet.

**Solution:**
- For CDS: Run `npx prisma migrate dev`
- For EV Lab: Start API Gateway to trigger SQLAlchemy table creation

### Problem: Migration conflicts

**Cause:** Prisma/Alembic detects schema drift.

**Solution:**
```bash
# CDS: Reset migrations (CAUTION: Deletes all data)
cd cds/backend
npx prisma migrate reset

# EV Lab: Drop and recreate (CAUTION: Deletes all data)
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

### Problem: Unique constraint violation

**Cause:** Trying to map same organization/institution twice.

**Solution:**
```sql
-- Check existing mappings
SELECT * FROM organizations WHERE "evLabInstitutionId" IS NOT NULL;
SELECT * FROM institutions WHERE cds_organization_id IS NOT NULL;

-- Clear mappings
UPDATE organizations SET "evLabInstitutionId" = NULL WHERE id = '<org_id>';
UPDATE institutions SET cds_organization_id = NULL WHERE id = '<inst_id>';
```

---

## 🎯 Migration Status

| Task | Status | Notes |
|------|--------|-------|
| CDS Schema Changes | ✅ Complete | 3 new fields added to Organization |
| EV Lab Schema Changes | ✅ Complete | 4 new fields added to Institution |
| UserSSOMapping Model | ✅ Complete | New table for SSO tracking |
| CDS Migration SQL | ✅ Created | Ready to run with Prisma |
| EV Lab Migration SQL | ✅ Created | Ready to run manually or via Alembic |
| Database Initialization | ⏳ Pending | Awaits frontend/backend startup |
| Test Data Seeding | ⏳ Pending | After initialization |

---

## 📚 Related Documentation

- **Phase 2 Plan:** `/docs/PHASE_2_DATABASE_INTEGRATION.md`
- **Architecture:** `/docs/CDS_INTEGRATION_ARCHITECTURE.md`
- **Quick Start:** `/QUICKSTART.md`

---

**Migration Guide Created By:** Winston (Architect)
**Date:** November 27, 2025
**Status:** 📋 Schema Ready, Awaiting Database Init

