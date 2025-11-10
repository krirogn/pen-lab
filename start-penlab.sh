#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Function to get local IP address
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # MacOS
        ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || -n "$WSLENV" ]]; then
        # Windows (Git Bash/Cygwin) or WSL
        if command -v ipconfig.exe &> /dev/null; then
            # Windows or WSL
            ipconfig.exe 2>/dev/null | grep -i "IPv4" | grep -oP '\d+\.\d+\.\d+\.\d+' | grep -v '127.0.0.1' | head -n1 || echo "127.0.0.1"
        elif command -v hostname &> /dev/null; then
            # Fallback to hostname
            hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
        else
            echo "127.0.0.1"
        fi
    else
        # Linux
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1 || echo "127.0.0.1"
    fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Start Docker before running the script.${NC}"
    exit 1
fi

# Start Docker Compose
echo -e "${GREEN}Starting PEN Lab...${NC}"
docker compose up -d

# Wait a moment for services to start
sleep 5

# Check service status
JUICE_STATUS=$(docker compose ps juice-shop --format json 2>/dev/null | grep -q '"State":"running"' && echo "running" || echo "stopped")
DVWA_STATUS=$(docker compose ps dvwa --format json 2>/dev/null | grep -q '"State":"running"' && echo "running" || echo "stopped")
BWA_STATUS=$(docker compose ps bwa --format json 2>/dev/null | grep -q '"State":"running"' && echo "running" || echo "stopped")

# Get IP addresses
LOCAL_IP=$(get_local_ip)

# Clear screen and display banner
clear

echo "####################################################"
echo "Welcome to Penetration Testing Lab 2025/26"
echo "Running on $(uname -s) $(uname -m)"
echo ""
echo "IP1: 127.0.0.1 (localhost)"
echo "IP2: $LOCAL_IP (network)"
echo ""
echo "To access:"
echo "  - OWASP Juice Shop:"
echo "    http://$LOCAL_IP:3000"
echo "    http://localhost:3000"
echo ""
echo "  - Damn Vulnerable Web Application:"
echo "    http://$LOCAL_IP/DVWA"
echo "    http://localhost/DVWA"
echo ""
echo "  - Buggy Web Application (bWAPP):"
echo "    http://$LOCAL_IP/bWAPP"
echo "    http://localhost/bWAPP"
echo "    (Login: bee / bug)"
echo ""
echo "Service Status:"
echo "  - Juice Shop: ${JUICE_STATUS}"
echo "  - DVWA: ${DVWA_STATUS}"
echo "  - bWAPP: ${BWA_STATUS}"
echo ""
echo "####################################################"
echo ""
echo "Commands:"
echo "  View logs:    docker compose logs -f"
# echo "  Stop lab:     docker compose stop"
echo "  Restart lab:  docker compose restart"
echo "  Shutdown:     docker compose down"
echo ""

# Optional: Follow logs
read -p "Would you like to view live logs? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker compose logs -f
fi
