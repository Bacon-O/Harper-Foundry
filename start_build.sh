#!/bin/bash
set -e

VERSION="v0.0-alpha-rc1"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Build Orchestrator ($VERSION)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate BUILD_ID once at the start (persists across all env_setup.sh calls)
if [ -n "$GITHUB_RUN_ID" ]; then
    BUILD_ID="gh_${GITHUB_RUN_ID}"
else
    BUILD_ID=$(date +%Y%m%d_%H%M%S)
fi
export BUILD_ID

# Pre-parse arguments for shell mode and menu (before env_setup)
SHELL_MODE="false"
SHELL_MENU="false"
SHOW_CONFIGS="false"
TEST_RUN="false"
QA_ONLY="false"
QA_BUILD_DIR=""
BUILD_ARGS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version)
            echo "Harper Foundry $VERSION"
            exit 0
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Build Modes:"
            echo "  (default)             Run full build pipeline (preheat → build → QA)"
            echo "  --qa-only [BUILD_DIR] Run QA tests only against a build directory"
            echo ""
            echo "Interactive Modes:"
            echo "  --shell               Launch interactive container shell"
            echo "  --shell-menu          Show menu to select params file, then shell"
            echo ""
            echo "Information:"
            echo "  -v, --version         Show version information"
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
            echo "  ./start_build.sh --qa-only -p params/harper_deb13.params ./output/build_20260217_160524"
            echo "  ./start_build.sh -v"
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
        --qa-only)
            QA_ONLY="true"
            ;;
        --show-configs)
            SHOW_CONFIGS="true"
            ;;
        -t|--test-run)
            TEST_RUN="true"
            export TEST_RUN
            BUILD_ARGS+=("--test-run")
            ;;
        *)
            # Pass all other arguments to BUILD_ARGS
            BUILD_ARGS+=("$1")
            ;;
    esac
    shift
done

# For QA_ONLY mode, extract build directory from last argument
if [ "$QA_ONLY" == "true" ]; then
    if [ ${#BUILD_ARGS[@]} -eq 0 ]; then
        echo "❌ ERROR: --qa-only requires a build directory argument"
        echo ""
        echo "Usage: $0 --qa-only -p params/file ./output/build_directory"
        exit 1
    fi
    
    # Check if last BUILD_ARGS entry looks like a path (not a flag)
    last_arg="${BUILD_ARGS[-1]}"
    if [[ "$last_arg" == -* ]]; then
        echo "❌ ERROR: --qa-only requires a build directory argument"
        echo ""
        echo "Usage: $0 --qa-only -p params/file ./output/build_directory"
        exit 1
    fi
    
    # Pop the last argument as the build directory
    QA_BUILD_DIR="$last_arg"
    unset 'BUILD_ARGS[-1]'
    
    if [ ! -d "$QA_BUILD_DIR" ]; then
        echo "❌ ERROR: Build directory not found: $QA_BUILD_DIR"
        exit 1
    fi
fi

# Handle --show-configs: display available configs
if [ "$SHOW_CONFIGS" == "true" ]; then
    bash ./scripts/show_params.sh
    exit 0
fi

# Handle --shell-menu: show interactive menu
if [ "$SHELL_MENU" == "true" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📂 Available Configurations"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Collect project params (from params/ directory, excluding templates starting with _)
    mapfile -t project_params < <(for f in params/*.params; do [[ -f "$f" ]] && [[ "$(basename "$f")" != _* ]] && echo "params/$(basename "$f")"; done | sort)
    
    # Collect user custom params (from params/params.d/ directory)
    mapfile -t user_params < <(for f in params/params.d/*.params; do [[ -f "$f" ]] && echo "$f"; done | sort)
    
    # Combine all params
    all_params=()
    if [ ${#project_params[@]} -gt 0 ]; then
        all_params+=("${project_params[@]}")
    fi
    if [ ${#user_params[@]} -gt 0 ]; then
        all_params+=("${user_params[@]}")
    fi
    
    if [ ${#all_params[@]} -eq 0 ]; then
        echo "❌ No param files found in params/ or params/params.d/ directories"
        exit 1
    fi
    
    # Display built-in configurations
    if [ ${#project_params[@]} -gt 0 ]; then
        echo "🔧 BUILT-IN CONFIGURATIONS (Suggestions):"
        echo ""
        index=1
        for param in "${project_params[@]}"; do
            basename=$(basename "$param" .params)
            case "$basename" in
                foundry)
                    suggestion="← Default, recommended for standard builds"
                    ;;
                tinyconfig)
                    suggestion="← Quick test builds (2-5 mins)"
                    ;;
                harper_deb13)
                    suggestion="← Debian 13 optimized"
                    ;;
                *)
                    suggestion=""
                    ;;
            esac
            printf "   %d) %-25s %s\n" "$index" "$param" "$suggestion"
            ((index++))
        done
        echo ""
    fi
    
    # Display custom user configurations
    if [ ${#user_params[@]} -gt 0 ]; then
        echo "👤 CUSTOM USER CONFIGURATIONS:"
        echo ""
        for param in "${user_params[@]}"; do
            printf "   %d) %s\n" "$index" "$param"
            ((index++))
        done
        echo ""
    fi
    
    # Display quit option
    echo "q) quit"
    echo ""
    
    # Get user input
    while true; do
        read -p "Select a config (enter number or q to quit): " user_choice
        
        # Check for quit commands
        if [[ "$user_choice" =~ ^[qQ]$ ]] || [[ "$user_choice" =~ ^[qQ][uU][iI][tT]$ ]] || [[ "$user_choice" =~ ^[eE][xX][iI][tT]$ ]]; then
            echo "❌ Cancelled"
            exit 1
        fi
        
        # Check if it's a valid number
        if [[ "$user_choice" =~ ^[0-9]+$ ]]; then
            index=$((user_choice - 1))
            if [ "$index" -ge 0 ] && [ "$index" -lt ${#all_params[@]} ]; then
                selected_param="${all_params[$index]}"
                BUILD_ARGS+=("-p" "$selected_param")
                echo "✅ Selected: $selected_param"
                break
            else
                echo "❌ Invalid selection. Please enter a number between 1 and ${#all_params[@]}, or q to quit."
            fi
        else
            echo "❌ Invalid input. Please enter a number or q to quit."
        fi
    done
    echo ""
fi

# 1. Fueling
source ./scripts/env_setup.sh "${BUILD_ARGS[@]}"

# If QA_ONLY mode, run QA tests on existing build and exit
if [ "$QA_ONLY" == "true" ]; then
    echo "🛡️  Running Quality Assurance on existing build..."
    echo "📂 Build directory: $QA_BUILD_DIR"
    echo ""
    
    # Override output directory to the user-provided build
    HOST_OUTPUT_DIR="$QA_BUILD_DIR"
    export HOST_OUTPUT_DIR
    
    # Run material analysis (QA tests)
    if ! bash ./scripts/material_analysis.sh "${BUILD_ARGS[@]}"; then
        echo "❌ Quality assurance checks failed."
        echo ""
        echo "Review the QA output above for details."
        
        if [ "$QA_MODE" == "ENFORCED" ]; then
            echo ""
            echo "QA_MODE=ENFORCED: QA is considered failed."
            exit 1
        else
            echo ""
            echo "QA_MODE=RELAXED: QA completed with warnings."
        fi
    fi
    
    echo ""
    echo "✅ QA tests completed. Exiting."
    exit 0
fi

# If shell mode, skip build phases and launch interactive shell
if [ "$SHELL_MODE" == "true" ]; then
    echo "🐚 Launching interactive container shell..."
    echo "📂 Working directory: /build"
    echo "📦 Params: $PARAMS_FILE"
    echo "🔌 Mounted volumes:"
    echo "   • /build → $BUILD_WORKSPACE_DIR"
    echo "   • /opt/factory/plugins → $REPO_ROOT/scripts/plugins"
    echo "   • /opt/factory/configs → $REPO_ROOT/configs"
    echo "   • /opt/factory/output → $BUILD_OUTPUT_DIR"
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
echo "📦 Build artifacts are in: $BUILD_OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  • View builds: ./scripts/show_builds.sh"
echo "  • Install kernel: sudo dpkg -i $BUILD_OUTPUT_DIR/*.deb"
echo "  • Clean old builds: ./scripts/furnace_clean.sh"
echo ""