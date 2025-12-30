#!/bin/bash
# ==================================================================
# View logs for CDS-EV Lab Integration Stack
# ==================================================================

CYAN='\033[0;36m'
NC='\033[0m'

cd infrastructure

if [ -z "$1" ]; then
    echo -e "${CYAN}Showing logs for all services...${NC}"
    echo "Press Ctrl+C to exit"
    echo ""
    docker-compose logs -f
else
    echo -e "${CYAN}Showing logs for $1...${NC}"
    echo "Press Ctrl+C to exit"
    echo ""
    docker-compose logs -f "$1"
fi
