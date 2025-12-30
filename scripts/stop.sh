#!/bin/bash
# ==================================================================
# Stop CDS-EV Lab Integration Stack
# ==================================================================

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Stopping CDS-EV Lab Integration Stack                  ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

cd infrastructure

echo -e "${YELLOW}▶ Stopping all services...${NC}"
echo ""

docker-compose down

echo ""
echo -e "${RED}✓ All services stopped${NC}"
echo ""
echo "To remove volumes (⚠️  deletes all data):"
echo -e "  ${CYAN}docker-compose down -v${NC}"
echo ""
