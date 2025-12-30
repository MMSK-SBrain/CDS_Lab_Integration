#!/bin/bash
# ==================================================================
# CDS-EV Lab Integration - Initial Setup Script
# ==================================================================
# This script sets up the integration workspace
# Run this once after cloning the repositories
# ==================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Header
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   CDS-EV Lab Integration Setup                           ║
║   Reynlab Training Platform                              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Helper functions
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if running from correct directory
if [ ! -f "infrastructure/docker-compose.yml" ]; then
    print_error "Please run this script from the CDS_Lab_Integration root directory"
    exit 1
fi

print_step "Step 1: Checking prerequisites..."
echo ""

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker found: $DOCKER_VERSION"
else
    print_error "Docker not found. Please install Docker Desktop."
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_success "Docker Compose found: $COMPOSE_VERSION"
else
    print_error "Docker Compose not found. Please install Docker Compose."
    exit 1
fi

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js found: $NODE_VERSION"
else
    print_warning "Node.js not found. Required for local development."
fi

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    print_success "Python found: $PYTHON_VERSION"
else
    print_warning "Python not found. Required for local development."
fi

echo ""
print_step "Step 2: Verifying repository structure..."
echo ""

# Check CDS
if [ -d "cds" ]; then
    print_success "CDS repository found"
else
    print_error "CDS repository not found. Please run from correct directory."
    exit 1
fi

# Check EV Lab
if [ -d "labs/ev-lab" ]; then
    print_success "EV Lab repository found"
else
    print_error "EV Lab repository not found. Please run from correct directory."
    exit 1
fi

echo ""
print_step "Step 3: Setting up environment configuration..."
echo ""

# Create .env from template if it doesn't exist
if [ ! -f ".env" ]; then
    cp .env.example .env
    print_success "Created .env from template"
    print_warning "IMPORTANT: Edit .env and replace all 'change-this' values with actual secrets!"
    print_warning "Generate secure secrets with: openssl rand -base64 32"

    # Pause for user to acknowledge
    echo ""
    read -p "Press Enter after you've updated .env with secure values..."
else
    print_success ".env already exists"
fi

echo ""
print_step "Step 4: Installing CDS dependencies..."
echo ""

# CDS Backend
if [ -d "cds/backend" ]; then
    cd cds/backend
    if [ -f "package.json" ]; then
        print_step "Installing CDS backend dependencies..."
        npm install
        print_success "CDS backend dependencies installed"
    fi
    cd ../..
fi

# CDS Frontend
if [ -d "cds/frontend" ]; then
    cd cds/frontend
    if [ -f "package.json" ]; then
        print_step "Installing CDS frontend dependencies..."
        npm install
        print_success "CDS frontend dependencies installed"
    fi
    cd ../..
fi

echo ""
print_step "Step 5: Installing EV Lab dependencies..."
echo ""

# EV Lab Frontend
if [ -d "labs/ev-lab/frontend" ]; then
    cd labs/ev-lab/frontend
    if [ -f "package.json" ]; then
        print_step "Installing EV Lab frontend dependencies..."
        npm install
        print_success "EV Lab frontend dependencies installed"
    fi
    cd ../../..
fi

echo ""
print_step "Step 6: Building Docker images..."
echo ""

print_warning "This may take 10-20 minutes on first run..."
cd infrastructure

# Build images
docker-compose build --parallel

print_success "Docker images built successfully"
cd ..

echo ""
print_step "Step 7: Initializing databases..."
echo ""

# Start databases only
cd infrastructure
docker-compose up -d cds-db ev-lab-db cds-redis ev-lab-redis

# Wait for databases to be ready
print_step "Waiting for databases to be ready..."
sleep 10

print_success "Databases started"

# Run CDS migrations
print_step "Running CDS database migrations..."
docker-compose exec -T cds-backend npm run prisma:migrate || print_warning "CDS migrations may need to be run manually"

# Run EV Lab migrations
print_step "Running EV Lab database migrations..."
# Add migration command if available
print_warning "EV Lab migrations may need to be run manually"

cd ..

echo ""
print_step "Step 8: Creating shared types..."
echo ""

# Create basic shared type files
mkdir -p shared/types
cat > shared/types/integration.ts << 'EOFTS'
// Shared TypeScript types for CDS-EV Lab integration
// This file is auto-generated by setup.sh

export interface SSOTokenPayload {
  sub: string;
  iss: string;
  aud: string;
  exp: number;
  email: string;
  role: 'student' | 'instructor' | 'admin';
  organizationId: string;
  organizationName: string;
  sessionId?: string;
  batchId?: string;
  exerciseId?: string;
}

export interface LabExerciseResult {
  labPlatformId: string;
  exerciseId: string;
  sessionId: string;
  studentId: string;
  status: 'completed' | 'failed' | 'in_progress';
  score: number;
  maxScore: number;
  passed: boolean;
  startedAt: string;
  completedAt: string;
  timeSpentSeconds: number;
  evidenceUrls?: string[];
  resultData?: Record<string, any>;
}
EOFTS

print_success "Shared types created"

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ✓ Setup Complete!                                      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo "1. Verify your .env file has secure values (no 'change-this' placeholders)"
echo "2. Start the full stack:"
echo -e "   ${YELLOW}cd infrastructure && docker-compose up${NC}"
echo ""
echo "3. Access the applications:"
echo -e "   ${YELLOW}CDS Frontend:     http://localhost:3010${NC}"
echo -e "   ${YELLOW}CDS Backend:      http://localhost:3011${NC}"
echo -e "   ${YELLOW}EV Lab Frontend:  http://localhost:3020${NC}"
echo -e "   ${YELLOW}EV Lab API:       http://localhost:8010${NC}"
echo ""
echo "4. Run tests:"
echo -e "   ${YELLOW}./scripts/test.sh${NC}"
echo ""
echo "5. View logs:"
echo -e "   ${YELLOW}cd infrastructure && docker-compose logs -f${NC}"
echo ""
echo -e "${MAGENTA}Demo environments remain untouched:${NC}"
echo -e "   Original CDS:     ${YELLOW}http://localhost:3000${NC}"
echo -e "   Original EV Lab:  ${YELLOW}http://localhost:3000${NC}"
echo ""
echo -e "${GREEN}Happy integrating! 🚀${NC}"
echo ""
