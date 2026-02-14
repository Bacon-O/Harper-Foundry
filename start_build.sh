#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Kernel Foundry - Build Orchestrator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Fueling
source ./scripts/env_setup.sh "$@"

# 2. Preheat
echo "🌡️  Phase 1: Preheating Furnace..."
if ! bash ./scripts/furnace_preheat.sh "$@"; then
    echo "❌ Preheat failed. Cannot proceed with build."
    exit 1
fi
echo ""

# 3. Ignition
echo "🔥 Phase 2: Igniting Build Process..."
if ! bash ./scripts/furnace_ignite.sh "$@"; then
    echo "❌ Build process failed."
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "   • Check Docker logs: docker logs <container_id>"
    echo "   • Review build output above for error messages"
    echo "   • See TROUBLESHOOTING.md for common issues"
    echo "   • Validate config: ./scripts/validate_params.sh"
    exit 1
fi
echo ""

# 4. Material Analysis (Conditional)
if [ "$BYPASS_QA" == "true" ]; then
    echo "⏩ Phase 3: Skipping Quality Assurance (Bypass Active)."
else
    echo "🛡️  Phase 3: Running Quality Assurance..."
    if ! bash ./scripts/material_analysis.sh "$@"; then
        echo "❌ Quality assurance checks failed."
        echo ""
        echo "Build artifacts may be incomplete or invalid."
        echo "Review the QA output above for details."
        
        if [ "$QA_MODE" == "HARD" ]; then
            echo ""
            echo "QA_MODE=HARD: Build is considered failed."
            exit 1
        else
            echo ""
            echo "QA_MODE=SOFT: Continuing despite warnings."
        fi
    fi
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Foundry Cycle Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Build artifacts are in: $CURRENT_DIST_DIR"
echo ""
echo "Next steps:"
echo "  • View builds: ./scripts/show_builds.sh"
echo "  • Install kernel: sudo dpkg -i $CURRENT_DIST_DIR/*.deb"
echo "  • Clean old builds: ./scripts/furnace_clean.sh"
echo ""