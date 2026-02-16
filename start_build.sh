#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Build Orchestrator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate BUILD_ID once at the start (persists across all env_setup.sh calls)
if [ -n "$GITHUB_RUN_ID" ]; then
    export BUILD_ID="gh_${GITHUB_RUN_ID}"
else
    export BUILD_ID=$(date +%Y%m%d_%H%M%S)
fi

# Pre-parse arguments for shell mode and menu (before env_setup)
SHELL_MODE="false"
SHELL_MENU="false"
SHOW_CONFIGS="false"
TEST_RUN="false"
BUILD_ARGS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Build Modes:"
            echo "  (default)             Run full build pipeline (preheat → build → QA)"
            echo ""
            echo "Interactive Modes:"
            echo "  --shell               Launch interactive container shell"
            echo "  --shell-menu          Show menu to select params file, then shell"
            echo ""
            echo "Information:"
            echo "  --show-configs        Display all available param configs with details"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Build Options (work with any mode):"
            echo "  -p, --params-file <path>  Specify a params file"
            echo "  -o, --overrides <path>    Apply override params file on top of base params"
            echo "  -t, --test-run            Enable test mode (tinyconfig, no QEMU)"
            echo "  -r, --rebuild             Force Docker image rebuild"
            echo "  -b, --bypass-qa           Skip Quality Assurance"
            echo "  -i, --incremental         Skip 'make clean' for faster rebuilds"
            echo "  -e, --exec <script>       Override the container execution script"
            echo ""
            echo "Examples:"
            echo "  ./start_build.sh --show-configs"
            echo "  ./start_build.sh --shell-menu"
            echo "  ./start_build.sh -p params/tinyconfig.params -t"
            echo "  ./start_build.sh -p params/foundry.params -o params/_test_overrides.params"
            echo ""
            exit 0
            ;;
        --shell)
            SHELL_MODE="true"
            ;;
        --shell-menu)
            SHELL_MENU="true"
            SHELL_MODE="true"
            ;;
        --show-configs)
            SHOW_CONFIGS="true"
            ;;
        -t|--test-run)
            TEST_RUN="true"
            BUILD_ARGS+=("--test-run")
            ;;
        *)
            BUILD_ARGS+=("$1")
            ;;
    esac
    shift
done

# Handle --show-configs: display available configs
if [ "$SHOW_CONFIGS" == "true" ]; then
    bash ./scripts/show_params.sh
    exit 0
fi

# Handle --shell-menu: show interactive menu
if [ "$SHELL_MENU" == "true" ]; then
    echo "📂 Available param configs:"
    echo ""
    params_list=($(ls params/*.params 2>/dev/null | grep -v "^params/_" | xargs -n1 basename))
    
    if [ ${#params_list[@]} -eq 0 ]; then
        echo "❌ No param files found in params/ directory"
        exit 1
    fi
    
    PS3="Select a config (enter number): "
    select selected_param in "${params_list[@]}"; do
        if [[ -n "$selected_param" ]]; then
            BUILD_ARGS+=("-p" "params/$selected_param")
            echo "✅ Selected: $selected_param"
            break
        else
            echo "❌ Invalid selection"
        fi
    done
    echo ""
fi

# 1. Fueling
source ./scripts/env_setup.sh "${BUILD_ARGS[@]}"

# If shell mode, skip build phases and launch interactive shell
if [ "$SHELL_MODE" == "true" ]; then
    echo "🐚 Launching interactive container shell..."
    echo "📂 Working directory: /build"
    echo "📦 Params: $PARAMS_FILE"
    echo "🔌 Mounted volumes:"
    echo "   • /build → $PROJECT_ROOT"
    echo "   • /opt/factory/plugins → $REPO_ROOT/scripts/plugins"
    echo "   • /opt/factory/configs → $REPO_ROOT/configs"
    echo "   • /opt/factory/output → $CURRENT_DIST_DIR"
    echo ""
    echo "Type 'exit' to leave the container."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Launch shell mode in furnace_ignite
    export SHELL_MODE="true"
    bash ./scripts/furnace_ignite.sh "${BUILD_ARGS[@]}"
    exit 0
fi

# 2. Preheat (normal build mode)
echo "🌡️  Phase 1: Preheating Furnace..."
if ! bash ./scripts/furnace_preheat.sh "${BUILD_ARGS[@]}"; then
    echo "❌ Preheat failed. Cannot proceed with build."
    exit 1
fi
echo ""

# 3. Ignition
echo "🔥 Phase 2: Igniting Build Process..."
if ! bash ./scripts/furnace_ignite.sh "${BUILD_ARGS[@]}"; then
    echo "❌ Build process failed."
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "   • Check Docker logs: docker logs <container_id>"
    echo "   • Review build output above for error messages"
    echo "   • See TROUBLESHOOTING.md for common issues"
    echo "   • Validate config: ./scripts/validate_params.sh"
    echo "   • Launch interactive shell: ./start_build.sh --shell"
    exit 1
fi
echo ""

# 4. Material Analysis (Conditional)
if [ "$BYPASS_QA" == "true" ]; then
    echo "⏩ Phase 3: Skipping Quality Assurance (Bypass Active)."
else
    echo "🛡️  Phase 3: Running Quality Assurance..."
    if ! bash ./scripts/material_analysis.sh "${BUILD_ARGS[@]}"; then
        echo "❌ Quality assurance checks failed."
        echo ""
        echo "Build artifacts may be incomplete or invalid."
        echo "Review the QA output above for details."
        
        if [ "$QA_MODE" == "ENFORCED" ]; then
            echo ""
            echo "QA_MODE=ENFORCED: Build is considered failed."
            exit 1
        else
            echo ""
            echo "QA_MODE=RELAXED: Continuing despite warnings."
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