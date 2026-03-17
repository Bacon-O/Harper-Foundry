#!/bin/bash
set -e

VERSION="v0.4-Beta"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Harper Foundry - Build Orchestrator ($VERSION)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


# Pre-parse arguments for shell mode and menu (before env_setup)
SHELL_MODE="false"
SHELL_MENU="false"
SHOW_CONFIGS="false"
TEST_RUN="false"
QA_ONLY="false"
QA_ONLY_BUILD_DIR=""
BUILD_ARGS=()
_params_file=""

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
            # echo "  -i, --incremental         Skip 'make clean' for faster rebuilds" # more testing needed
            echo "  -e, --exec <script>       Override the container execution script"
            echo ""
            echo "Examples:"
            echo "  ./start_build.sh --show-configs"
            echo "  ./start_build.sh --shell-menu"
            echo "  ./start_build.sh -p params/tinyconfig.params -t"
            echo "  ./start_build.sh -p params/foundry_template.params -o params/_test_overrides.params"
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
            export QA_ONLY
            BUILD_ARGS+=("--qa-only")
            shift
            if [[ -z "$1" ]] || [[ "$1" == -* ]]; then
                echo "❌ ERROR: --qa-only requires a build directory path"
                echo "Usage: $0 --qa-only <BUILD_DIR>"
                echo "Example: $0 --qa-only ./output/build_20260217_160524"
                exit 1
            fi
            QA_ONLY_BUILD_DIR="$1"
            BUILD_ARGS+=("$1")
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
            if [[ -z "$1" ]] || [[ "$1" == -* ]]; then
                echo "❌ ERROR: -p/--params-file requires a file path"
                echo "Example: $0 -p params/tinyconfig.params"
                exit 1
            fi
            _params_file="$1"
            BUILD_ARGS+=("$1")
            ;;
        -o|--overrides)
            BUILD_ARGS+=("$1")
            shift
            if [[ -z "$1" ]] || [[ "$1" == -* ]]; then
                echo "❌ ERROR: -o/--overrides requires a file path"
                echo "Example: $0 -o params/_test_overrides.params"
                exit 1
            fi
            BUILD_ARGS+=("$1")
            ;;
        -e|--exec)
            BUILD_ARGS+=("$1")
            shift
            if [[ -z "$1" ]] || [[ "$1" == -* ]]; then
                echo "❌ ERROR: -e/--exec requires a script path"
                echo "Example: $0 -e scripts/compile_scripts/custom.sh"
                exit 1
            fi
            BUILD_ARGS+=("$1")
            ;;
        *)
            # Pass all other arguments to BUILD_ARGS
            BUILD_ARGS+=("$1")
            ;;
    esac
    shift
done

# Generate BUILD_ID once at the start (persists across all env_setup.sh calls)
if [[ -n "$GITHUB_RUN_ID" ]]; then
    BUILD_ID="gh_${GITHUB_RUN_ID}"
elif [[ "$QA_ONLY" == "true" ]] && [[ -n "$QA_ONLY_BUILD_DIR" ]]; then
    BUILD_ID=$(date +%Y%m%d_%H%M%S)
fi
export BUILD_ID

# Handle --show-configs: display available configs
if [[ "$SHOW_CONFIGS" == "true" ]]; then
    _command=("./scripts/show_params.sh")
    "${_command[@]}"
    exit 0
fi

# Handle --shell-menu: show interactive menu
if [[ "$SHELL_MENU" == "true" ]]; then
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
    if [[ ${#project_params[@]} -gt 0 ]]; then
        all_params+=("${project_params[@]}")
    fi
    if [[ ${#user_params[@]} -gt 0 ]]; then
        all_params+=("${user_params[@]}")
    fi
    
    if [[ ${#all_params[@]} -eq 0 ]]; then
        echo "❌ No param files found in params/ or params/params.d/ directories"
        exit 1
    fi
    
    # Display built-in configurations
    if [[ ${#project_params[@]} -gt 0 ]]; then
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
    if [[ ${#user_params[@]} -gt 0 ]]; then
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
            if [[ "$index" -ge 0 ]] && [[ "$index" -lt ${#all_params[@]} ]]; then
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
# Shell mode end



# Auto-select tinyconfig for --test-run if no params specified
if [[ "$TEST_RUN" == "true" ]] && [[ -z "$_params_file" ]]; then
    _params_file="params/tinyconfig.params"
    BUILD_ARGS+=("-p" "$_params_file")
    echo "ℹ️  Test mode: Auto-selecting tinyconfig.params"
    echo ""
fi

# Validate params file is provided (skip for --show-configs and --shell-menu)
if [[ "$SHOW_CONFIGS" != "true" ]] && [[ "$SHELL_MENU" != "true" ]]; then
    if [[ -z "$_params_file" ]] || [[ ! -r "$_params_file" ]]; then
        echo "❌ ERROR: No params file specified. Use -p or --params-file to specify a config."
        echo "Example: $0 -p params/tinyconfig.params"
        echo ""
        echo "Available options:"
        echo "  • View configs: $0 --show-configs"
        echo "  • Interactive menu: $0 --shell-menu"
        exit 1
    fi
fi

# Validate that --qa-only has a valid build directory
if [[ "$QA_ONLY" == "true" ]]; then
    if [[ ! -d "$QA_ONLY_BUILD_DIR" ]]; then
        echo "❌ ERROR: --qa-only requires a valid build directory"
        echo "Provided: '$QA_ONLY_BUILD_DIR'"
        echo "Example: $0 --qa-only ./output/build_20260217_160524 -p params/tinyconfig.params"
        exit 1
    fi
fi

# 1. Fueling
# For QA_ONLY mode, we need to set a flag to tell env_setup to skip directory creation
if [[ "$QA_ONLY" == "true" ]]; then
    export QA_ONLY_MODE="true"
fi

source ./scripts/env_setup.sh "${BUILD_ARGS[@]}"

# If QA_ONLY mode, run QA tests on existing build and exit
if [[ "$QA_ONLY" == "true" ]]; then
    echo "🛡️  Running Quality Assurance on existing build..."
    echo "📂 Build directory: $QA_ONLY_BUILD_DIR"
    echo ""
    
    # For QA-only mode, pass the specific build directory to QA tests
    # This tells the QA test scripts to use this directory directly
    # instead of searching for the latest build
    export QA_ONLY_BUILD_DIR="$QA_ONLY_BUILD_DIR"
    
    # Run material analysis (QA tests)
    
    _command=("./scripts/material_analysis.sh" "${BUILD_ARGS[@]}")
    if ! "${_command[@]}"; then
        echo "❌ Quality assurance checks failed."
        echo ""
        echo "Review the QA output above for details."
        
        if [[ "$QA_MODE" == "ENFORCED" ]]; then
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

### 

if [[ ${#PRE_BUILD_HOOKS[@]} -gt 0 ]]; then
    echo "⚠️  WARNING: Pre-build hooks configuration detected. Running pre-build hooks..."
    _command=("./scripts/pre_build_hooks.sh" "${BUILD_ARGS[@]}")
    "${_command[@]}"
else
    echo "🔧 No pre-build hooks configured. Skipping pre-build phase."
fi
###

# If shell mode, skip build phases and launch interactive shell
if [[ "$SHELL_MODE" == "true" ]]; then
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
    _command=("./scripts/launch.sh" "${BUILD_ARGS[@]}")
    "${_command[@]}"

    if [[ ${#POST_BUILD_HOOKS[@]} -gt 0 ]]; then
        echo "⚠️  WARNING: Post-build hooks configuration detected. Running post-build hooks..."
        _command=("./scripts/post_build_hooks.sh" "${BUILD_ARGS[@]}")
        "${_command[@]}"
    else
        echo "🔧 No post-build hooks configured. Skipping post-build phase."
    fi

    exit 0
fi

# 2. Preheat (normal build mode)
echo "🌡️  Phase 1: Validating prerequisites..."
echo "${BUILD_ARGS[@]}"
_command=("./scripts/validate_params.sh" "${BUILD_ARGS[@]}")
if ! "${_command[@]}"; then
    echo "❌ Validation failed. Cannot proceed with build."
    exit 1
fi
echo ""

# 3. Ignition
echo "🔥 Phase 2: Igniting Build Process..."
_command=("./scripts/launch.sh" "${BUILD_ARGS[@]}")
if ! "${_command[@]}"; then
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
if [[ "$BYPASS_QA" == "true" ]]; then
    echo "⏩ Phase 3: Skipping Quality Assurance (Bypass Active)."
else
    echo "🛡️  Phase 3: Running Quality Assurance..."
    _command=("./scripts/material_analysis.sh" "${BUILD_ARGS[@]}")
    if ! "${_command[@]}"; then
        echo "❌ Quality assurance checks failed."
        echo ""
        echo "Build artifacts may be incomplete or invalid."
        echo "Review the QA output above for details."
        
        if [[ "$QA_MODE" == "ENFORCED" ]]; then
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

# 5. Export
if [[ "$ARTIFACT_DELIVERY" == "true" ]] || [[ "$ARTIFACT_DELIVERY" == "TRUE" ]]; then
    echo "📦 Phase 4: Exporting Artifacts to Remote Server (Not Implemented)..."
    _command=("./scripts/artifact_export.sh" "${BUILD_ARGS[@]}")
    "${_command[@]}"
else
    echo "📦 Phase 4: Exporting Artifacts skipped"
fi

if [[ ${#POST_BUILD_HOOKS[@]} -gt 0 ]]; then
    echo "⚠️  WARNING: Post-build hooks configuration detected. Running post-build hooks..."
    _command=("./scripts/post_build_hooks.sh" "${BUILD_ARGS[@]}")
    "${_command[@]}"
else
    echo "🔧 No post-build hooks configured. Skipping post-build phase."
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