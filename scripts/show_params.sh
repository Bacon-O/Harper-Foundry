#!/bin/bash
set -e

# Dynamically find the Repo Root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Available Build Configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find all params files, excluding templates (starting with _)
mapfile -t params_files < <(find "${REPO_ROOT}/params" -maxdepth 1 -name "*.params" -type f | grep -v "/_" | sort)

if [ ${#params_files[@]} -eq 0 ]; then
    echo "❌ No param files found in ${REPO_ROOT}/params/"
    exit 1
fi

echo "📂 Found ${#params_files[@]} configuration(s):"
echo ""

# Function to extract param value
get_param() {
    local file=$1
    local param=$2
    local default=$3
    
    grep "^${param}=" "$file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -1 || echo "$default"
}

# Display each config
for param_file in "${params_files[@]}"; do
    filename=$(basename "$param_file")
    
    # Extract key parameters
    target_arch=$(get_param "$param_file" "TARGET_ARCH" "unknown")
    foundry_image=$(get_param "$param_file" "DOCKERFILE_PATH" "unknown")
    base_config=$(get_param "$param_file" "BASE_CONFIG" "unknown")
    tuning_config=$(get_param "$param_file" "TUNING_CONFIG" "unknown")
    project_tag=$(get_param "$param_file" "RELEASE_TAG" "unknown")
    
    echo "📋 $filename"
    echo "   ├─ Target Arch:     $target_arch"
    echo "   ├─ Docker Image:    $foundry_image"
    echo "   ├─ Base Config:     $base_config"
    echo "   ├─ Tuning Config:   $tuning_config"
    echo "   └─ Project Tag:     $project_tag"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 Parameter Descriptions:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "TARGET_ARCH        Kernel architecture (x86_64, arm64, etc.)"
echo "DOCKERFILE_PATH    Docker image/Dockerfile to use for builds"
echo "BASE_CONFIG        Base kernel config (defconfig, tinyconfig, or file path)"
echo "TUNING_CONFIG      Custom config to merge on top of BASE_CONFIG"
echo "RELEASE_TAG        Identifier tag for this kernel build variant"
echo ""
echo "🚀 Usage Examples:"
echo "   ./start_build.sh --shell -p params/foundry.params"
echo "   ./start_build.sh --shell-menu"
echo "   ./start_build.sh -p params/tinyconfig.params -t"
echo ""