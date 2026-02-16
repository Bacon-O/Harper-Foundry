#!/bin/bash
# ==============================================================================
# HARPER FOUNDRY: BUILD STATUS AND ARTIFACT VIEWER
# ==============================================================================
# This script displays information about build artifacts and their status.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARAMS_FILE="${1:-${REPO_ROOT}/params/foundry.params}"

# Load configuration
if [ -f "$PARAMS_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PARAMS_FILE"
    set +a
else
    echo "❌ ERROR: Params file not found: $PARAMS_FILE"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Build Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if output directory exists
if [ ! -d "$HOST_OUTPUT_DIR" ]; then
    echo "📂 Output directory not found: $HOST_OUTPUT_DIR"
    echo "   No builds have been completed yet."
    exit 0
fi

# Find all build directories
mapfile -t BUILD_DIRS < <(find "$HOST_OUTPUT_DIR" -maxdepth 1 -type d -name "build_*" | sort -r)

if [ ${#BUILD_DIRS[@]} -eq 0 ]; then
    echo "📂 Output directory: $HOST_OUTPUT_DIR"
    echo "   No builds found."
    exit 0
fi

echo "📂 Output directory: $HOST_OUTPUT_DIR"
echo "   Total builds: ${#BUILD_DIRS[@]}"
echo ""

# Display summary of each build
for build_dir in "${BUILD_DIRS[@]}"; do
    build_name=$(basename "$build_dir")
    build_date=$(stat -c %y "$build_dir" | cut -d' ' -f1,2 | cut -d'.' -f1)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Build: $build_name"
    echo "   Created: $build_date"
    echo ""
    
    # Count artifacts
    deb_count=$(find "$build_dir" -maxdepth 1 -name "*.deb" 2>/dev/null | wc -l)
    
    if [ "$deb_count" -eq 0 ]; then
        echo "   ⚠️  No .deb packages found (build may have failed)"
    else
        echo "   ✅ Debian packages: $deb_count"
        
        # List packages with sizes
        while IFS= read -r deb_file; do
            deb_name=$(basename "$deb_file")
            deb_size=$(du -h "$deb_file" | cut -f1)
            echo "      • $deb_name ($deb_size)"
        done < <(find "$build_dir" -maxdepth 1 -name "*.deb" | sort)
    fi
    
    # Check for kernel artifacts
    if [ -f "$build_dir/bzImage" ]; then
        bzimage_size=$(du -h "$build_dir/bzImage" | cut -f1)
        echo "   ✅ Kernel image: bzImage ($bzimage_size)"
    fi
    
    if [ -f "$build_dir/kernel.config" ]; then
        config_size=$(du -h "$build_dir/kernel.config" | cut -f1)
        echo "   ✅ Kernel config: kernel.config ($config_size)"
    fi
    
    # Calculate total size
    total_size=$(du -sh "$build_dir" 2>/dev/null | cut -f1)
    echo "   📊 Total size: $total_size"
    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Disk Usage Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total_output_size=$(du -sh "$HOST_OUTPUT_DIR" 2>/dev/null | cut -f1)
echo "   Total output directory size: $total_output_size"

available_space=$(df -h "$HOST_OUTPUT_DIR" | tail -1 | awk '{print $4}')
echo "   Available disk space: $available_space"

echo ""
echo "💡 Tips:"
echo "   • Clean old builds: ./scripts/furnace_clean.sh"
echo "   • Deep clean: ./scripts/furnace_clean.sh --deep"
echo "   • View specific build: ls -lh $HOST_OUTPUT_DIR/build_<ID>/"
echo ""
