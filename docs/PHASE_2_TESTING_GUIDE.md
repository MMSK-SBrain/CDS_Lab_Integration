# Phase 2: Integration Testing Guide

**Date:** November 27, 2025
**Status:** Complete Implementation - Ready for Testing

---

## 📋 Overview

This guide walks you through end-to-end testing of the CDS-EV Lab SSO integration.

**Test Coverage:**
1. ✅ Database initialization and migrations
2. ✅ Tenant mapping verification
3. ✅ SSO token generation (CDS)
4. ✅ SSO validation and user provisioning (EV Lab)
5. ✅ Experiment execution
6. ✅ Webhook result submission
7. ✅ Data integrity verification

---

## 🚀 Prerequisites

### Services Running

**Backend Services (Docker):**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/infrastructure
docker-compose -f docker-compose-simplified.yml ps

# Should show all 8 services healthy:
# ✅ cds-postgres-integration (port 5433)
# ✅ cds-redis-integration (port 6380)
# ✅ ev-lab-postgres-integration (port 5434)
# ✅ ev-lab-redis-integration (port 6381)
# ✅ pybamm-integration (port 8011)
# ✅ ev-sim-integration (port 8012)
# ✅ liionpack-integration (port 8013)
# ✅ ev-lab-api-integration (port 8010)
```

**Frontend Services (Local npm):**

**Terminal 1 - CDS Backend:**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds/backend
npm install
npx prisma generate
npx prisma migrate dev  # Initialize database
npm run dev
# Listening on http://localhost:3011
```

**Terminal 2 - CDS Frontend:**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/cds/frontend
npm install
npm run dev
# Running on http://localhost:3010
```

**Terminal 3 - EV Lab Frontend:**
```bash
cd /Volumes/Dev/CDS_Lab_Integration/labs/ev-lab/frontend
npm install
npm run dev
# Running on http://localhost:3020
```

---

## 🧪 Test Suite

### Test 1: Database Initialization

#### 1.1 Verify CDS Database Schema

```bash
docker exec cds-postgres-integration psql -U cds_user -d cds_integration -c "\d organizations"

# Should show new columns:
#   evLabInstitutionId | text
#   evLabEnabled       | boolean | default false
#   evLabSsoEnabled    | boolean | default false
```

**Expected Output:**
```
Column              | Type      | Modifiers
--------------------+-----------+------------------
id                  | text      | not null
name                | text      | not null
evLabInstitutionId  | text      |
evLabEnabled        | boolean   | default false
evLabSsoEnabled     | boolean   | default false
```

#### 1.2 Verify EV Lab Database Schema

```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "\d institutions"

# Should show new columns:
#   cds_organization_id | uuid
#   cds_enabled         | boolean | default false
#   cds_sso_enabled     | boolean | default false
#   cds_webhook_enabled | boolean | default true
```

```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "\d user_sso_mappings"

# Should show new table with columns:
#   id, user_id, institution_id,
#   cds_student_id, cds_organization_id,
#   first_login_at, last_login_at, login_count
```

**✅ Pass Criteria:**
- Both tables exist with correct schema
- Indexes are created
- No errors in migrations

---

### Test 2: Seed Test Data

#### 2.1 Run Seed Script

```bash
cd /Volumes/Dev/CDS_Lab_Integration
./scripts/seed_test_data.sh
```

**Expected Output:**
```
🌱 Seeding Test Data for CDS-EV Lab Integration...

Step 1: Seeding CDS Database...
✅ CDS database seeded successfully

Step 2: Seeding EV Lab Database...
✅ EV Lab database seeded successfully

✨ Test Data Seeding Complete!

Test Accounts Created:
  CDS:
    Organization: Test University
    Student: John Doe (john.doe@testuniversity.edu)

  EV Lab:
    Institution: Test University
    SSO Enabled: Yes

Ready for integration testing!
```

#### 2.2 Verify Tenant Mapping

**CDS Side:**
```bash
docker exec cds-postgres-integration psql -U cds_user -d cds_integration -c "
SELECT
  id as org_id,
  name as org_name,
  \"evLabInstitutionId\" as ev_lab_inst_id,
  \"evLabEnabled\" as enabled,
  \"evLabSsoEnabled\" as sso_enabled
FROM organizations
WHERE \"evLabEnabled\" = true;
"
```

**EV Lab Side:**
```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "
SELECT
  id as inst_id,
  name as inst_name,
  cds_organization_id,
  cds_enabled,
  cds_sso_enabled
FROM institutions
WHERE cds_enabled = true;
"
```

**✅ Pass Criteria:**
- Bidirectional mapping exists (org_id ↔ inst_id)
- Both sides have integration enabled
- UUIDs match exactly

---

### Test 3: SSO Token Generation

#### 3.1 Generate SSO Token via API

```bash
curl -X POST http://localhost:3011/api/integrations/lab-platforms/ev-lab/sso-token \
  -H "Content-Type: application/json" \
  -d '{
    "studentId": "33333333-3333-3333-3333-333333333333",
    "sessionId": "88888888-8888-8888-8888-888888888888",
    "returnUrl": "/experiments/basic_discharge"
  }' | jq
```

**Expected Response:**
```json
{
  "success": true,
  "message": "SSO token generated successfully",
  "data": {
    "ssoUrl": "http://localhost:3020/sso/login?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...&returnUrl=/experiments/basic_discharge",
    "expiresIn": 1800,
    "labPlatform": {
      "id": "...",
      "platformId": "ev-lab",
      "name": "Battery Lab V3 - EV Integration"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### 3.2 Decode JWT Token (Verify Payload)

```bash
# Install jq if not available: brew install jq

# Extract and decode token
TOKEN=$(curl -s -X POST http://localhost:3011/api/integrations/lab-platforms/ev-lab/sso-token \
  -H "Content-Type: application/json" \
  -d '{"studentId": "33333333-3333-3333-3333-333333333333", "sessionId": "88888888-8888-8888-8888-888888888888"}' | jq -r '.data.token')

# Decode (base64 decode middle part)
echo $TOKEN | cut -d '.' -f 2 | base64 -d | jq
```

**Expected Payload:**
```json
{
  "cds_student_id": "33333333-3333-3333-3333-333333333333",
  "cds_organization_id": "11111111-1111-1111-1111-111111111111",
  "cds_session_id": "88888888-8888-8888-8888-888888888888",
  "email": "john.doe@testuniversity.edu",
  "name": "John Doe",
  "role": "student",
  "iat": 1732684800,
  "exp": 1732686600
}
```

**✅ Pass Criteria:**
- Token generated successfully
- Payload contains all required fields
- Expiry is 30 minutes from now
- SSO URL is properly formatted

---

### Test 4: SSO Validation and User Auto-Provisioning

#### 4.1 Follow SSO URL

**Option A: Browser**
1. Copy `ssoUrl` from Test 3.1 response
2. Paste into browser
3. Should redirect to EV Lab with cookie set
4. Should redirect to `/experiments/basic_discharge`

**Option B: curl**
```bash
SSO_URL="<paste_sso_url_here>"

curl -i -L "$SSO_URL"

# Should see:
# HTTP/1.1 303 See Other
# Location: /experiments/basic_discharge
# Set-Cookie: access_token=...; HttpOnly; Secure; SameSite=Lax
```

#### 4.2 Verify User Auto-Provisioned

```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "
SELECT
  id,
  email,
  first_name,
  last_name,
  role,
  is_active,
  approval_status,
  institution_id
FROM users
WHERE email = 'john.doe@testuniversity.edu';
"
```

**Expected:**
- User record exists
- `is_active = true`
- `approval_status = approved`
- `institution_id` matches Test University

#### 4.3 Verify SSO Mapping Created

```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "
SELECT
  cds_student_id,
  cds_organization_id,
  user_id,
  institution_id,
  login_count,
  first_login_at,
  last_login_at
FROM user_sso_mappings
WHERE cds_student_id = '33333333-3333-3333-3333-333333333333';
"
```

**Expected:**
- Mapping record exists
- `login_count = 1` (first login)
- Timestamps are recent

**✅ Pass Criteria:**
- SSO redirect works
- User auto-created in EV Lab
- SSO mapping table updated
- Access token cookie set

---

### Test 5: Subsequent SSO Logins

#### 5.1 Generate New Token

```bash
curl -X POST http://localhost:3011/api/integrations/lab-platforms/ev-lab/sso-token \
  -H "Content-Type: application/json" \
  -d '{
    "studentId": "33333333-3333-3333-3333-333333333333",
    "sessionId": "99999999-9999-9999-9999-999999999999",
    "returnUrl": "/"
  }' | jq -r '.data.ssoUrl'
```

#### 5.2 Follow SSO URL Again

```bash
# Paste new SSO URL
curl -i -L "<new_sso_url>"
```

#### 5.3 Verify Login Count Incremented

```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "
SELECT login_count, last_login_at
FROM user_sso_mappings
WHERE cds_student_id = '33333333-3333-3333-3333-333333333333';
"
```

**Expected:**
- `login_count = 2`
- `last_login_at` is recent

**✅ Pass Criteria:**
- Subsequent logins work
- Login count increments
- No duplicate user created

---

### Test 6: Webhook Result Submission

#### 6.1 Simulate Experiment Completion

```bash
curl -X POST http://localhost:8010/api/webhook/lab-results \
  -H "Content-Type: application/json" \
  -d '{
    "apiKey": "5XZ0FQkSghCqBUSQrWqo8/k3REjoXzxJ+S4/223FI/8=",
    "labPlatformId": "ev-lab",
    "exerciseId": "basic_discharge",
    "sessionId": "88888888-8888-8888-8888-888888888888",
    "studentId": "33333333-3333-3333-3333-333333333333",
    "status": "completed",
    "startedAt": "2025-11-27T10:00:00Z",
    "completedAt": "2025-11-27T10:15:00Z",
    "score": 85,
    "maxScore": 100,
    "passed": true,
    "timeSpentSeconds": 900,
    "attemptNumber": 1,
    "evidenceUrls": [
      "http://localhost:3020/results/screenshot1.png"
    ],
    "resultData": {
      "experiment_type": "basic_discharge",
      "parameters": {"c_rate": 1.0, "initial_soc": 1.0}
    }
  }' | jq
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Lab result received and stored successfully",
  "resultId": "..."
}
```

#### 6.2 Verify Result Stored in CDS

```bash
docker exec cds-postgres-integration psql -U cds_user -d cds_integration -c "
SELECT
  id,
  \"studentId\",
  status,
  score,
  \"maxScore\",
  percentage,
  passed,
  \"timeSpentSeconds\"
FROM lab_exercise_results
WHERE \"studentId\" = '33333333-3333-3333-3333-333333333333';
"
```

**Expected:**
- Result record exists
- Score: 85/100
- Percentage: 85%
- Passed: true
- Time spent: 900 seconds

**✅ Pass Criteria:**
- Webhook accepted
- Result stored in CDS
- Idempotent (re-sending doesn't duplicate)

---

### Test 7: Error Scenarios

#### 7.1 Expired Token

**Generate token and wait 31 minutes, or manually create expired token:**
```bash
curl -i -L "http://localhost:3020/sso/login?token=<expired_token>"
```

**Expected:**
- HTTP 401 Unauthorized
- Error: "SSO token has expired"

#### 7.2 Invalid Token

```bash
curl -i -L "http://localhost:3020/sso/login?token=invalid.jwt.token"
```

**Expected:**
- HTTP 401 Unauthorized
- Error: "Invalid SSO token"

#### 7.3 SSO Not Enabled

**Disable SSO for institution:**
```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "
UPDATE institutions SET cds_sso_enabled = false WHERE id = '22222222-2222-2222-2222-222222222222';
"
```

**Try SSO login:**
```bash
# Generate new token and follow SSO URL
```

**Expected:**
- HTTP 404 Not Found
- Error: "Institution not registered or SSO not enabled"

**Re-enable SSO:**
```bash
docker exec ev-lab-postgres-integration psql -U ev_lab_user -d ev_lab_integration -c "
UPDATE institutions SET cds_sso_enabled = true WHERE id = '22222222-2222-2222-2222-222222222222';
"
```

**✅ Pass Criteria:**
- Expired tokens rejected
- Invalid tokens rejected
- Disabled SSO prevented

---

## 📊 Test Results Checklist

| Test | Description | Status |
|------|-------------|--------|
| 1.1 | CDS schema changes | ⬜ |
| 1.2 | EV Lab schema changes | ⬜ |
| 2.1 | Seed test data | ⬜ |
| 2.2 | Tenant mapping | ⬜ |
| 3.1 | SSO token generation | ⬜ |
| 3.2 | JWT payload verification | ⬜ |
| 4.1 | SSO redirect | ⬜ |
| 4.2 | User auto-provisioning | ⬜ |
| 4.3 | SSO mapping creation | ⬜ |
| 5.1-5.3 | Subsequent logins | ⬜ |
| 6.1-6.2 | Webhook result submission | ⬜ |
| 7.1-7.3 | Error scenarios | ⬜ |

---

## 🛠️ Troubleshooting

### Problem: "relation does not exist"

**Cause:** Database not initialized

**Solution:**
```bash
# CDS: Run Prisma migrations
cd cds/backend
npx prisma migrate dev

# EV Lab: Restart API Gateway to create tables
docker-compose -f docker-compose-simplified.yml restart ev-lab-api-gateway
```

### Problem: "JWT_SECRET not configured"

**Cause:** Environment variable missing

**Solution:**
Check `.env` file has `JWT_SECRET=...` and restart services.

### Problem: "Lab platform not found"

**Cause:** EV Lab not registered in CDS

**Solution:**
```bash
./scripts/seed_test_data.sh
```

### Problem: "Token expired immediately"

**Cause:** Server time mismatch

**Solution:**
```bash
# Check system time
date

# Sync time if needed (macOS)
sudo sntp -sS time.apple.com
```

---

## 📈 Performance Benchmarks

| Operation | Target | Actual | Status |
|-----------|--------|--------|--------|
| Token generation | < 100ms | ___ ms | ⬜ |
| SSO validation | < 200ms | ___ ms | ⬜ |
| User provisioning | < 500ms | ___ ms | ⬜ |
| Webhook submission | < 300ms | ___ ms | ⬜ |

---

## ✅ Success Criteria

**Phase 2 is complete when:**
- ✅ All 12 test cases pass
- ✅ No errors in logs
- ✅ Performance within targets
- ✅ Error scenarios handled gracefully
- ✅ Data integrity maintained

---

**Testing Guide Created By:** Winston (Architect)
**Date:** November 27, 2025
**Status:** 📋 Ready for Execution

