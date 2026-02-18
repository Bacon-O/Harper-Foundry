#!/bin/bash
set -e

VERSION="v0.0-alpha-rc1"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Build Orchestrator ($VERSION)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clean runtime state from previous builds (ensure fresh start)
rm -rf var/runtime 2>/dev/null || true

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
        -p|--params-file)
            # Handle flags that take values - consume both flag and value
            BUILD_ARGS+=("$1")
            shift
            BUILD_ARGS+=("$1")
            ;;
        -o|--overrides)
            BUILD_ARGS+=("$1")
            shift
            BUILD_ARGS+=("$1")
            ;;
        -e|--exec)
            BUILD_ARGS+=("$1")
            shift
            BUILD_ARGS+=("$1")
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
    
    # Find the last positional argument (skip flag-value pairs)
    # Flags that take values: -p, --params-file, -o, --overrides, -e, --exec
    idx=$((${#BUILD_ARGS[@]} - 1))
    found=false
    
    while [ $idx -ge 0 ]; do
        arg="${BUILD_ARGS[$idx]}"
        
        if [[ "$arg" == -* ]]; then
            # Current is a flag, skip it
            ((idx--))
        else
            # Current is not a flag (could be positional or flag value)
            # Check if the previous item is a flag that takes a value
            is_flag_value=false
            if [ $((idx - 1)) -ge 0 ]; then
                prev_arg="${BUILD_ARGS[$((idx - 1))]}"
                if [[ "$prev_arg" == -p ]] || [[ "$prev_arg" == --params-file ]] || \
                   [[ "$prev_arg" == -o ]] || [[ "$prev_arg" == --overrides ]] || \
                   [[ "$prev_arg" == -e ]] || [[ "$prev_arg" == --exec ]]; then
                    is_flag_value=true
                fi
            fi
            
            if [ "$is_flag_value" = true ]; then
                # This is a value for a flag, not positional - skip it
                ((idx--))
            else
                # This is a real positional argument (our build directory)
                QA_BUILD_DIR="$arg"
                found=true
                break
            fi
        fi
    done
    
    if [ "$found" != "true" ]; then
        echo "❌ ERROR: --qa-only requires a build directory argument"
        echo ""
        echo "Usage: $0 --qa-only -p params/file ./output/build_directory"
        exit 1
    fi
    
    # Remove the build directory from BUILD_ARGS
    unset 'BUILD_ARGS[$idx]'
    BUILD_ARGS=("${BUILD_ARGS[@]}")  # Reindex array
    
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
# For QA_ONLY mode, we need to set a flag to tell env_setup to skip directory creation
if [ "$QA_ONLY" == "true" ]; then
    export QA_ONLY_MODE="true"
fi

source ./scripts/env_setup.sh "${BUILD_ARGS[@]}"

# If QA_ONLY mode, run QA tests on existing build and exit
if [ "$QA_ONLY" == "true" ]; then
    echo "🛡️  Running Quality Assurance on existing build..."
    echo "📂 Build directory: $QA_BUILD_DIR"
    echo ""
    
    # For QA-only mode, pass the specific build directory to QA tests
    # This tells the QA test scripts to use this directory directly
    # instead of searching for the latest build
    export QA_ONLY_BUILD_DIR="$QA_BUILD_DIR"
    
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
    
    # Launch shell mode in launch
    export SHELL_MODE="true"
    bash ./scripts/launch.sh "${BUILD_ARGS[@]}"
    exit 0
fi

# 2. Preheat (normal build mode)
echo "🌡️  Phase 1: Validating prerequisites..."
if ! bash ./scripts/validate.sh "${BUILD_ARGS[@]}"; then
    echo "❌ Preheat failed. Cannot proceed with build."
    exit 1
fi
echo ""

# 3. Ignition
echo "🔥 Phase 2: Igniting Build Process..."
if ! bash ./scripts/launch.sh "${BUILD_ARGS[@]}"; then
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
echo "  • Install kernel: <Follow your distro's kernel installation process>"
echo "  • Clean old builds: ./scripts/clean.sh"
echo ""