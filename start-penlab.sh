#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
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

# Function to calculate file hash (cross-platform)
calculate_hash() {
    if command -v md5sum &> /dev/null; then
        # Linux
        cat "$@" 2>/dev/null | md5sum | awk '{print $1}'
    elif command -v md5 &> /dev/null; then
        # macOS
        cat "$@" 2>/dev/null | md5
    elif command -v sha256sum &> /dev/null; then
        # Fallback to sha256 (available on most systems including Git Bash)
        cat "$@" 2>/dev/null | sha256sum | awk '{print $1}'
    else
        # If no hash command available, use file modification times
        stat -c %Y "$@" 2>/dev/null || stat -f %m "$@" 2>/dev/null || echo "unknown"
    fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Start Docker before running the script.${NC}"
    exit 1
fi

# Check if Dockerfile has changed and rebuild if needed
DOCKERFILE="Dockerfile.bwapp"
ENTRYPOINT="bwapp-entrypoint.sh"
BUILD_MARKER=".last_build_hash"
NEEDS_BUILD=false

if [ -f "$DOCKERFILE" ] && [ -f "$ENTRYPOINT" ]; then
    # Calculate hash of Dockerfile and entrypoint script
    CURRENT_HASH=$(calculate_hash "$DOCKERFILE" "$ENTRYPOINT")
    
    # Check if hash has changed
    if [ -f "$BUILD_MARKER" ]; then
        LAST_HASH=$(cat "$BUILD_MARKER")
        if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
            NEEDS_BUILD=true
        fi
    else
        NEEDS_BUILD=true
    fi
    
    # Build if needed
    if [ "$NEEDS_BUILD" = true ]; then
        echo -e "${YELLOW}Dockerfile or entrypoint has changed. Rebuilding bWAPP image...${NC}"
        docker compose build --no-cache bwa
        # Save the new hash
        echo "$CURRENT_HASH" > "$BUILD_MARKER"
        echo -e "${GREEN}Build complete!${NC}"
    else
        echo -e "${GREEN}bWAPP image is up to date.${NC}"
    fi
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
echo ""
echo "Service Status:"
echo -e "  - Juice Shop: ${CYAN}${JUICE_STATUS}${NC}"
echo -e "  - DVWA:       ${CYAN}${DVWA_STATUS}${NC}"
echo -e "  - bWAPP:      ${CYAN}${BWA_STATUS}${NC}"
echo ""
echo "####################################################"
echo ""
echo "Commands:"
echo "  View logs:                    docker compose logs -f"
echo "  Restart lab:                  docker compose restart"
echo "  Shutdown:                     docker compose down"
echo "  Shutdown and reset database:  docker compose down -v"
echo ""

# Optional: Follow logs
read -p "Would you like to view live logs? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker compose logs -f
fi
