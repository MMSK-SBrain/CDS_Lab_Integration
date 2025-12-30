#!/bin/bash

# Seed Test Data for Phase 2 Integration Testing
# Creates organizations, institutions, students, and lab platform registrations

set -e

echo "🌱 Seeding Test Data for CDS-EV Lab Integration..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database connection details
CDS_DB_HOST="localhost"
CDS_DB_PORT="5433"
CDS_DB_USER="cds_user"
CDS_DB_NAME="cds_integration"
CDS_DB_PASSWORD="YfeqwaNkyFh8UARWKBg+uKWTpeKX+Yek"

EV_LAB_DB_HOST="localhost"
EV_LAB_DB_PORT="5434"
EV_LAB_DB_USER="ev_lab_user"
EV_LAB_DB_NAME="ev_lab_integration"
EV_LAB_DB_PASSWORD="K/mtjKsJ/+mHNRXQLxt1x7pistZGChTn"

# Test data UUIDs (for consistent linking)
ORG_ID="11111111-1111-1111-1111-111111111111"
INST_ID="22222222-2222-2222-2222-222222222222"
STUDENT_ID="33333333-3333-3333-3333-333333333333"
BATCH_ID="44444444-4444-4444-4444-444444444444"
INSTRUCTOR_ID="55555555-5555-5555-5555-555555555555"
LOCATION_ID="66666666-6666-6666-6666-666666666666"
COURSE_ID="77777777-7777-7777-7777-777777777777"

echo -e "${BLUE}Step 1: Seeding CDS Database...${NC}"
echo ""

# Seed CDS database via Docker
docker exec cds-postgres-integration psql -U $CDS_DB_USER -d $CDS_DB_NAME <<EOF
-- 1. Create test organization
INSERT INTO organizations (id, name, "createdAt", "updatedAt", "evLabInstitutionId", "evLabEnabled", "evLabSsoEnabled")
VALUES (
  '$ORG_ID',
  'Test University',
  NOW(),
  NOW(),
  '$INST_ID',
  true,
  true
)
ON CONFLICT (id) DO UPDATE SET
  "evLabInstitutionId" = EXCLUDED."evLabInstitutionId",
  "evLabEnabled" = EXCLUDED."evLabEnabled",
  "evLabSsoEnabled" = EXCLUDED."evLabSsoEnabled";

-- 2. Create test location
INSERT INTO locations (id, name, type, "stateCode", "organizationId", "createdAt", "updatedAt")
VALUES (
  '$LOCATION_ID',
  'Main Campus',
  'owned',
  'CA',
  '$ORG_ID',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 3. Create test course
INSERT INTO courses (id, name, duration, description, modules, "organizationId", "createdAt", "updatedAt")
VALUES (
  '$COURSE_ID',
  'Battery Technology Fundamentals',
  40,
  'Comprehensive course on battery testing and vehicle integration',
  '[{"id": "module-1", "name": "Battery Fundamentals"}]'::jsonb,
  '$ORG_ID',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 4. Create test instructor
INSERT INTO instructors (id, name, email, "passwordHash", "organizationId", "createdAt", "updatedAt")
VALUES (
  '$INSTRUCTOR_ID',
  'Dr. Jane Smith',
  'jane.smith@testuniversity.edu',
  '\$2b\$10\$abcdefghijklmnopqrstuvwxyz123456',  -- bcrypt hash placeholder
  '$ORG_ID',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 5. Create test batch
INSERT INTO batches (id, name, "courseId", "locationId", "instructorId", "startDate", "createdAt", "updatedAt")
VALUES (
  '$BATCH_ID',
  'Spring 2025 Batch',
  '$COURSE_ID',
  '$LOCATION_ID',
  '$INSTRUCTOR_ID',
  '2025-01-01',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 6. Create test student
INSERT INTO students (id, name, "rollNumber", email, "batchId", "createdAt", "updatedAt")
VALUES (
  '$STUDENT_ID',
  'John Doe',
  'TU-2025-001',
  'john.doe@testuniversity.edu',
  '$BATCH_ID',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 7. Register EV Lab as a lab platform
INSERT INTO lab_platforms (
  id,
  "platformId",
  name,
  description,
  "baseUrl",
  "ssoEndpoint",
  "healthEndpoint",
  "apiKey",
  status,
  "organizationId",
  "createdAt",
  "updatedAt"
)
VALUES (
  gen_random_uuid(),
  'ev-lab',
  'Battery Lab V3 - EV Integration',
  'Comprehensive battery testing and vehicle integration laboratory',
  'http://localhost:3020',
  '/sso/login',
  '/health',
  '5XZ0FQkSghCqBUSQrWqo8/k3REjoXzxJ+S4/223FI/8=',  -- From .env CDS_API_KEY
  'active',
  '$ORG_ID',
  NOW(),
  NOW()
)
ON CONFLICT ("platformId", "organizationId") DO NOTHING;

EOF

echo -e "${GREEN}✅ CDS database seeded successfully${NC}"
echo ""

echo -e "${BLUE}Step 2: Seeding EV Lab Database...${NC}"
echo ""

# Seed EV Lab database via Docker
docker exec ev-lab-postgres-integration psql -U $EV_LAB_DB_USER -d $EV_LAB_DB_NAME <<EOF
-- 1. Create test institution
INSERT INTO institutions (
  id,
  name,
  domain,
  subdomain,
  contact_email,
  cds_organization_id,
  cds_enabled,
  cds_sso_enabled,
  cds_webhook_enabled,
  status,
  created_at,
  updated_at
)
VALUES (
  '$INST_ID',
  'Test University',
  'testuniversity.edu',
  'testuni',
  'admin@testuniversity.edu',
  '$ORG_ID',
  true,
  true,
  true,
  'active',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  cds_organization_id = EXCLUDED.cds_organization_id,
  cds_enabled = EXCLUDED.cds_enabled,
  cds_sso_enabled = EXCLUDED.cds_sso_enabled,
  cds_webhook_enabled = EXCLUDED.cds_webhook_enabled;

-- 2. Verify the mapping
SELECT
  'Institution: ' || name || ' (ID: ' || id || ')' as info,
  'Linked to CDS Org: ' || cds_organization_id as cds_link,
  'SSO Enabled: ' || cds_sso_enabled as sso_status
FROM institutions
WHERE id = '$INST_ID';

EOF

echo -e "${GREEN}✅ EV Lab database seeded successfully${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Test Data Seeding Complete!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Test Accounts Created:${NC}"
echo ""
echo -e "  ${GREEN}CDS:${NC}"
echo -e "    Organization: Test University"
echo -e "    Organization ID: ${ORG_ID}"
echo -e "    Student: John Doe (john.doe@testuniversity.edu)"
echo -e "    Student ID: ${STUDENT_ID}"
echo ""
echo -e "  ${GREEN}EV Lab:${NC}"
echo -e "    Institution: Test University"
echo -e "    Institution ID: ${INST_ID}"
echo -e "    SSO Enabled: Yes"
echo ""
echo -e "  ${GREEN}Integration:${NC}"
echo -e "    Tenant Mapping: Organization ($ORG_ID) ↔ Institution ($INST_ID)"
echo -e "    Lab Platform: ev-lab (registered in CDS)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Generate SSO token: POST /api/integrations/lab-platforms/ev-lab/sso-token"
echo "  2. Use SSO URL to log into EV Lab"
echo "  3. Run an experiment"
echo "  4. Verify webhook result submission to CDS"
echo ""
echo -e "${GREEN}Ready for integration testing!${NC}"
