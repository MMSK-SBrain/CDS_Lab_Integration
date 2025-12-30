#!/bin/bash
# ==================================================================
# Sync changes from demo repos to integration workspace
# ==================================================================
# Use this to pull latest changes from original demo repositories
# ==================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Syncing from Demo Repositories                         ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${YELLOW}⚠️  Warning: This will overwrite local changes!${NC}"
echo -e "${YELLOW}⚠️  Make sure you've committed any integration-specific changes first.${NC}"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${CYAN}Syncing CDS...${NC}"
rsync -av --delete \
  --exclude='node_modules' \
  --exclude='.next' \
  --exclude='dist' \
  --exclude='.env' \
  --exclude='.env.local' \
  /Volumes/Dev/Reynlab_CDS/ cds/

print_success "CDS synced"

echo ""
echo -e "${CYAN}Syncing EV Lab...${NC}"
rsync -av --delete \
  --exclude='node_modules' \
  --exclude='.next' \
  --exclude='dist' \
  --exclude='.env' \
  --exclude='.env.local' \
  --exclude='__pycache__' \
  /Volumes/Dev/Integrated_EV_Lab/ labs/ev-lab/

echo -e "${GREEN}✓ EV Lab synced${NC}"

echo ""
echo -e "${GREEN}✓ Sync complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Review changes: git status"
echo "2. Test integration: ./scripts/start.sh"
echo "3. Run tests: ./scripts/test.sh"
echo ""
