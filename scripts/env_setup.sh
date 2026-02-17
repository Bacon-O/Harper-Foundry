#!/bin/bash

# 1. Dynamically find the Repo Root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 2. Handle Arguments
PARAMS_FILE="${REPO_ROOT}/params/foundry.params"
OVERRIDE_PARAMS=""
TEST_RUN_MODE="false"
DOCKER_REBUILD="false"
BYPASS_QA_CLI="false"
INCREMENTAL_BUILD="false"
EXEC_OVERRIDE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "  -p, --params-file <path>  Specify a params file."
            echo "  -o, --overrides <path>    Apply override params on top of base."
            echo "  -t, --test-run            Enable test mode (tinyconfig, no QEMU)."
            echo "  -r, --rebuild             Force Docker image rebuild."
            echo "  -b, --bypass-qa           Skip Material Analysis."
            echo "  -i, --incremental         Skip 'make clean' for faster rebuilds."
            echo "  -e, --exec <script>       Override the container execution script."
            echo ""
            echo "Interactive Modes:"
            echo "  --shell                   Launch interactive container shell."
            echo "  --shell-menu              Show menu to select params file, then shell."
            exit 0
            ;;
        -p|--params-file)
            if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                echo "❌ Error: Argument for $1 is missing"
                exit 1
            fi
            if [[ -f "$2" ]]; then
                PARAMS_FILE="$(realpath "$2")"
            elif [[ -f "${REPO_ROOT}/$2" ]]; then
                PARAMS_FILE="${REPO_ROOT}/$2"
            else
                echo "❌ Error: Specified config file '$2' not found."
                exit 1
            fi
            shift 
            ;;
        -o|--overrides)
            if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                echo "❌ Error: Argument for $1 is missing"
                exit 1
            fi
            if [[ -f "$2" ]]; then
                OVERRIDE_PARAMS="$(realpath "$2")"
            elif [[ -f "${REPO_ROOT}/$2" ]]; then
                OVERRIDE_PARAMS="${REPO_ROOT}/$2"
            else
                echo "❌ Error: Specified override file '$2' not found."
                exit 1
            fi
            shift
            ;;
        -t|--test-run)
            TEST_RUN_MODE="true"
            ;;
        -r|--rebuild)
            DOCKER_REBUILD="true"
            ;;
        -b|--bypass-qa)
            BYPASS_QA_CLI="true"
            ;;
        -i|--incremental)
            INCREMENTAL_BUILD="true"
            ;;
        -e|--exec)
            if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                echo "❌ Error: Argument for $1 is missing"
                exit 1
            fi
            EXEC_OVERRIDE="$2"
            shift
            ;;
        *)
            echo "❌ Error: Unknown option '$1'"
            echo "Run with --help for a list of available options."
            exit 1
            ;;
    esac
    shift 
done

# Auto-select tinyconfig params if test-run mode is enabled and no custom config specified
if [ "$TEST_RUN_MODE" == "true" ] && [ "$PARAMS_FILE" == "${REPO_ROOT}/params/foundry.params" ]; then
    PARAMS_FILE="${REPO_ROOT}/params/tinyconfig.params"
fi

# 3. Load and Hydrate
if [ -f "$PARAMS_FILE" ]; then
    echo "📖 Consulting the blueprint from $PARAMS_FILE..."
    set -a
    # shellcheck source=/dev/null
    source "$PARAMS_FILE"
    set +a
    
    # Apply overrides if specified
    if [ -n "$OVERRIDE_PARAMS" ] && [ -f "$OVERRIDE_PARAMS" ]; then
        echo "🔄 Applying overrides from $(basename "$OVERRIDE_PARAMS")..."
        set -a
        # shellcheck source=/dev/null
        source "$OVERRIDE_PARAMS"
        set +a
    fi

    # 3.5 Default host paths if not set in params
    USE_PARAM_SCOPED_DIRS="${USE_PARAM_SCOPED_DIRS:-true}"
    if [ -z "$BUILD_WORKSPACE_DIR" ]; then
        DEFAULT_WORKSPACE_BASE="${REPO_ROOT}/build-workspace"
        if [ "$USE_PARAM_SCOPED_DIRS" != "false" ]; then
            if [ -n "$PRODUCTION_CONFIG" ]; then
                WORKSPACE_TAG="$(basename "$PRODUCTION_CONFIG" .params)"
            else
                WORKSPACE_TAG="$(basename "$PARAMS_FILE" .params)"
            fi
            BUILD_WORKSPACE_DIR="${DEFAULT_WORKSPACE_BASE}/${WORKSPACE_TAG}"
        else
            BUILD_WORKSPACE_DIR="${DEFAULT_WORKSPACE_BASE}"
        fi
    fi
    if [ -z "$HOST_OUTPUT_DIR" ]; then
        DEFAULT_OUTPUT_BASE="${REPO_ROOT}/output"
        if [ "$USE_PARAM_SCOPED_DIRS" != "false" ]; then
            if [ -z "$WORKSPACE_TAG" ]; then
                if [ -n "$PRODUCTION_CONFIG" ]; then
                    WORKSPACE_TAG="$(basename "$PRODUCTION_CONFIG" .params)"
                else
                    WORKSPACE_TAG="$(basename "$PARAMS_FILE" .params)"
                fi
            fi
            HOST_OUTPUT_DIR="${DEFAULT_OUTPUT_BASE}/${WORKSPACE_TAG}"
        else
            HOST_OUTPUT_DIR="${DEFAULT_OUTPUT_BASE}"
        fi
    fi
    export BUILD_WORKSPACE_DIR HOST_OUTPUT_DIR

    # Create default host directories if running on host
    if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ]; then
        mkdir -p "$BUILD_WORKSPACE_DIR" "$HOST_OUTPUT_DIR"
    fi
    
    # 4. Burner Control (Parallelism)
    # Uses PARALLEL_JOBS from params or defaults to all available cores
    if [ -z "$PARALLEL_JOBS" ]; then
        FINAL_JOBS=$(nproc)
        if [ "$FINAL_JOBS" -gt 1 ]; then
            FINAL_JOBS=$((FINAL_JOBS - 1))
        fi
        export FINAL_JOBS
        echo "🔥 Using default: $FINAL_JOBS core(s)."
    elif [ "$PARALLEL_JOBS" == "ALL" ] || [ "$PARALLEL_JOBS" == "all" ]; then
        FINAL_JOBS=$(nproc)
        export FINAL_JOBS
        echo "🔥 Using all available cores: $FINAL_JOBS."
    else
        export FINAL_JOBS="$PARALLEL_JOBS"
        echo "🔥 Using restricted furnace power: $FINAL_JOBS cores."
    fi

    # 4.5. Container Path Adjustments
    # If running inside a container, translate host paths to container paths
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
        # Inside container: plugins are mounted at /opt/factory/scripts/plugins
        export PLUGIN_DIR="/opt/factory/scripts/plugins/"
        export TEST_FUNCTIONS_DIR="/opt/factory/scripts/plugins/qatests/tests/"
        export TEST_PACKAGE_DIR="/opt/factory/scripts/plugins/qatests/packages/"
    fi

    # 5. Apply Overrides (CLI Arguments > Params File)
    if [ "$TEST_RUN_MODE" == "true" ]; then
        export BASE_CONFIG="tinyconfig"
        export ENABLE_QEMU_TESTS="false"
        echo "🧪 Test Run Mode: Overriding to tinyconfig and disabling QEMU."
    fi

    if [ "$BYPASS_QA_CLI" == "true" ]; then
        export BYPASS_QA="true"
    else
        export BYPASS_QA="${BYPASS_QA:-false}"
    fi

    if [ -n "$EXEC_OVERRIDE" ]; then
        export FOUNDRY_EXEC="$EXEC_OVERRIDE"
        echo "🕹️  Execution Override: Using $FOUNDRY_EXEC"
    fi

    export DOCKER_REBUILD="$DOCKER_REBUILD"
    export INCREMENTAL_BUILD="$INCREMENTAL_BUILD"

    # 6. Host Architecture Detection
    # Detect the actual host architecture for cross-compilation checks
    HOST_ARCH=$(uname -m)
    export HOST_ARCH
    
    # 7. Identity Logic
    # Only calculate if not already provided by the host environment
    export HOST_UID=${HOST_UID:-$(id -u)}
    export HOST_GID=${HOST_GID:-$(id -g)}

    # (Optional) If you want to use params-file overrides as a fallback:
    [ -n "$FOUNDRY_UID" ] && export HOST_UID="$FOUNDRY_UID"
    [ -n "$FOUNDRY_GID" ] && export HOST_GID="$FOUNDRY_GID"

echo "👤 Identity: $HOST_UID:$HOST_GID"
echo "🏗️  Host Architecture: $HOST_ARCH"
    
    # 7. Image Source Detection
    if [[ -f "${REPO_ROOT}/${DOCKERFILE_PATH}" ]]; then
        export FOUNDRY_IMAGE_TYPE="build"
        export DOCKERFILE_PATH="${REPO_ROOT}/${DOCKERFILE_PATH}"
    elif [[ -f "$DOCKERFILE_PATH" ]]; then
        export FOUNDRY_IMAGE_TYPE="build"
        export DOCKERFILE_PATH="$DOCKERFILE_PATH"
    else
        export FOUNDRY_IMAGE_TYPE="pull"
        export REMOTE_IMAGE_REF="$DOCKERFILE_PATH"
    fi

    # 8. Metadata (Anchor the BUILD_ID to the GitHub Run)
    # Only calculate BUILD_ID if not already set (e.g., from start_build.sh)
    if [ -z "$BUILD_ID" ]; then
        if [ -n "$GITHUB_RUN_ID" ]; then
            BUILD_ID="gh_${GITHUB_RUN_ID}"
        else
            BUILD_ID=$(date +%Y%m%d_%H%M%S)
        fi
        export BUILD_ID
    fi

    export BUILD_OUTPUT_DIR="${HOST_OUTPUT_DIR}/build_${BUILD_ID}"
    
    # Only create output directory on host, not inside container (it's already mounted)
    if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ]; then
        mkdir -p "$BUILD_OUTPUT_DIR"
        echo "📂 Artifact Target: $BUILD_OUTPUT_DIR"
    else
        echo "📂 Running in container - output mounted at /opt/factory/output"
    fi    
    echo "✅ Environment fueled for $TARGET_ARCH build."
else
    echo "❌ Error: $PARAMS_FILE not found!"
    exit 1
fi