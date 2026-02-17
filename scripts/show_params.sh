#!/bin/bash
set -e

# Dynamically find the Repo Root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Available Build Configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find all params files from project (excluding templates starting with _)
mapfile -t project_params < <(find "${REPO_ROOT}/params" -maxdepth 1 -name "*.params" -type f | grep -v "/_" | sort)

# Find all user custom params (from params/params.d/)
mapfile -t user_params < <(find "${REPO_ROOT}/params/params.d" -maxdepth 1 -name "*.params" -type f 2>/dev/null | sort)

if [ ${#project_params[@]} -eq 0 ] && [ ${#user_params[@]} -eq 0 ]; then
    echo "❌ No parameter files found"
    exit 1
fi

# Function to extract param value
get_param() {
    local file=$1
    local param=$2
    local default=$3
    
    grep "^${param}=" "$file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -1 || echo "$default"
}

# Display each config
if [ ${#project_params[@]} -gt 0 ]; then
    echo "📂 PROJECT CONFIGURATIONS (${#project_params[@]}):"
    echo ""
    
    for param_file in "${project_params[@]}"; do
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
fi

if [ ${#user_params[@]} -gt 0 ]; then
    echo "📂 USER CUSTOM CONFIGURATIONS (${#user_params[@]}):"
    echo ""
    
    for param_file in "${user_params[@]}"; do
        filename=$(basename "$param_file")
        param_path="params/params.d/$filename"
        
        # Extract key parameters
        target_arch=$(get_param "$param_file" "TARGET_ARCH" "unknown")
        foundry_image=$(get_param "$param_file" "DOCKERFILE_PATH" "unknown")
        base_config=$(get_param "$param_file" "BASE_CONFIG" "unknown")
        tuning_config=$(get_param "$param_file" "TUNING_CONFIG" "unknown")
        project_tag=$(get_param "$param_file" "RELEASE_TAG" "unknown")
        
        echo "📋 $param_path"
        echo "   ├─ Target Arch:     $target_arch"
        echo "   ├─ Docker Image:    $foundry_image"
        echo "   ├─ Base Config:     $base_config"
        echo "   ├─ Tuning Config:   $tuning_config"
        echo "   └─ Project Tag:     $project_tag"
        echo ""
    done
fi

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