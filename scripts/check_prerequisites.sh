#!/bin/bash
# ==============================================================================
# HARPER KERNEL FOUNDRY: SYSTEM PREREQUISITES CHECK
# ==============================================================================
# This script checks if your system meets the requirements to run the Foundry.

set -e

echo "🔍 Harper Kernel Foundry - System Prerequisites Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ERRORS=0
WARNINGS=0

# --- Bash Version Check ---
echo "🐚 Checking Bash version..."
BASH_VERSION_MAJOR="${BASH_VERSINFO[0]}"
if [ "$BASH_VERSION_MAJOR" -ge 4 ]; then
    echo "  ✅ Bash $BASH_VERSION (>= 4.0 required)"
else
    echo "  ❌ Bash $BASH_VERSION is too old (4.0+ required)"
    ((ERRORS++))
fi

# --- Docker Check ---
echo ""
echo "🐳 Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    echo "  ✅ Docker installed: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo "  ✅ Docker daemon is running"
        
        # Check Docker permissions
        if docker ps &> /dev/null; then
            echo "  ✅ Docker permissions OK (no sudo required)"
        else
            echo "  ⚠️  WARNING: Docker requires sudo (consider adding user to docker group)"
            ((WARNINGS++))
        fi
    else
        echo "  ❌ Docker daemon is not running"
        ((ERRORS++))
    fi
else
    echo "  ❌ Docker is not installed"
    ((ERRORS++))
fi

# --- Disk Space Check ---
echo ""
echo "💾 Checking disk space..."
AVAILABLE_GB=$(df -BG . | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "$AVAILABLE_GB" -ge 20 ]; then
    echo "  ✅ Available space: ${AVAILABLE_GB}GB (20GB+ recommended)"
else
    echo "  ⚠️  WARNING: Only ${AVAILABLE_GB}GB available (20GB+ recommended)"
    ((WARNINGS++))
fi

# --- Memory Check ---
echo ""
echo "🧠 Checking system memory..."
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_MB / 1024))
if [ "$TOTAL_MEM_GB" -ge 4 ]; then
    echo "  ✅ System RAM: ${TOTAL_MEM_GB}GB (4GB+ recommended)"
else
    echo "  ⚠️  WARNING: Only ${TOTAL_MEM_GB}GB RAM (4GB+ recommended)"
    echo "     Consider reducing FOUNDRY_NPROC to avoid OOM issues"
    ((WARNINGS++))
fi

# --- CPU Cores Check ---
echo ""
echo "⚙️  Checking CPU..."
CPU_CORES=$(nproc)
echo "  ℹ️  CPU cores: $CPU_CORES"
if [ "$CPU_CORES" -ge 4 ]; then
    echo "  ✅ Sufficient cores for parallel builds"
else
    echo "  ⚠️  WARNING: Limited cores ($CPU_CORES). Builds may be slow."
    ((WARNINGS++))
fi

# --- Git Check ---
echo ""
echo "📦 Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    echo "  ✅ Git installed: $GIT_VERSION"
else
    echo "  ⚠️  WARNING: Git not found (needed for version control)"
    ((WARNINGS++))
fi

# --- Curl Check ---
echo ""
echo "🌐 Checking Curl..."
if command -v curl &> /dev/null; then
    CURL_VERSION=$(curl --version | head -1 | awk '{print $2}')
    echo "  ✅ Curl installed: $CURL_VERSION"
else
    echo "  ❌ Curl not found (required for downloading patches)"
    ((ERRORS++))
fi

# --- Network Check ---
echo ""
echo "🌍 Checking network connectivity..."
if ping -c 1 -W 2 deb.debian.org &> /dev/null; then
    echo "  ✅ Can reach Debian repositories"
elif ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo "  ⚠️  WARNING: Internet works but cannot reach deb.debian.org"
    echo "     DNS or firewall may be blocking Debian repos"
    ((WARNINGS++))
else
    echo "  ⚠️  WARNING: No network connectivity detected"
    echo "     Docker builds may fail when downloading packages"
    ((WARNINGS++))
fi

# --- Optional Tools Check ---
echo ""
echo "🔧 Checking optional tools..."

OPTIONAL_TOOLS=(
    "qemu-system-x86_64"
    "make"
    "patch"
)

for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "  ✅ $tool available"
    else
        echo "  ℹ️  $tool not found (optional, provided by Docker)"
    fi
done

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All prerequisites met! You're ready to build."
    echo ""
    echo "Next steps:"
    echo "  1. Run ./install.sh to configure the Foundry"
    echo "  2. Run ./scripts/validate_params.sh to verify config"
    echo "  3. Run ./start_build.sh to build your kernel"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  System is usable with $WARNINGS warning(s)"
    echo "You can proceed, but may encounter issues."
    echo ""
    echo "Next steps:"
    echo "  1. Address warnings if possible"
    echo "  2. Run ./install.sh to configure the Foundry"
    exit 0
else
    echo "❌ System has $ERRORS error(s) and $WARNINGS warning(s)"
    echo "Please resolve the errors before proceeding."
    echo ""
    
    if [ $ERRORS -gt 0 ]; then
        echo "Required fixes:"
        if ! command -v docker &> /dev/null; then
            echo "  • Install Docker: https://docs.docker.com/get-docker/"
        fi
        if ! command -v curl &> /dev/null; then
            echo "  • Install curl: sudo apt install curl"
        fi
        if [ "$BASH_VERSION_MAJOR" -lt 4 ]; then
            echo "  • Update Bash to version 4.0+"
        fi
    fi
    
    exit 1
fi
