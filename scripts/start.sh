#!/bin/bash
# ==================================================================
# Start CDS-EV Lab Integration Stack
# ==================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   Starting CDS-EV Lab Integration Stack                  ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

cd infrastructure

echo -e "${BLUE}▶ Starting all services...${NC}"
echo ""

docker-compose up -d

echo ""
echo -e "${GREEN}✓ All services started!${NC}"
echo ""
echo "Access points:"
echo -e "  CDS Frontend:     ${CYAN}http://localhost:3010${NC}"
echo -e "  CDS Backend:      ${CYAN}http://localhost:3011${NC}"
echo -e "  EV Lab Frontend:  ${CYAN}http://localhost:3020${NC}"
echo -e "  EV Lab API:       ${CYAN}http://localhost:8010${NC}"
echo ""
echo "View logs:"
echo -e "  ${CYAN}docker-compose logs -f${NC}"
echo ""
echo "Stop services:"
echo -e "  ${CYAN}./scripts/stop.sh${NC}"
echo ""
