#!/bin/bash

# 1. Dynamically find the Repo Root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 2. Handle Arguments
PARAMS_FILE="${REPO_ROOT}/params/foundry.params"
TEST_RUN_MODE="false"
DOCKER_REBUILD="false"
BYPASS_QA_CLI="false"
EXEC_OVERRIDE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --config-file)
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
        --test-run)
            TEST_RUN_MODE="true"
            ;;
        --rebuild)
            DOCKER_REBUILD="true"
            ;;
        --bypass-qa)
            BYPASS_QA_CLI="true"
            ;;
        --exec)
            EXEC_OVERRIDE="$2"
            shift
            ;;
    esac
    shift 
done

# 3. Load and Hydrate
if [ -f "$PARAMS_FILE" ]; then
    echo "📖 Moving fuel truck into place from $PARAMS_FILE..."
    set -a
    source "$PARAMS_FILE"
    set +a
    
    # 4. Burner Control (Parallelism)
    # Uses FOUNDRY_NPROC from params or defaults to all available cores
    if [ -z "$FOUNDRY_NPROC" ]; then
        export FINAL_JOBS=$(nproc)
        echo "🔥 Using full furnace power: $FINAL_JOBS cores."
    else
        export FINAL_JOBS="$FOUNDRY_NPROC"
        echo "🔥 Using restricted furnace power: $FINAL_JOBS cores."
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

    # 6. Identity Logic
    # Only calculate if not already provided by the host environment
    export HOST_UID=${HOST_UID:-$(id -u)}
    export HOST_GID=${HOST_GID:-$(id -g)}

    # (Optional) If you want to use params-file overrides as a fallback:
    [ -n "$FOUNDRY_UID" ] && export HOST_UID="$FOUNDRY_UID"
    [ -n "$FOUNDRY_GID" ] && export HOST_GID="$FOUNDRY_GID"

echo "👤 Identity: $HOST_UID:$HOST_GID"
    
    # 7. Image Source Detection
    if [[ -f "${REPO_ROOT}/${FOUNDRY_IMAGE}" ]]; then
        export FOUNDRY_IMAGE_TYPE="build"
        export DOCKERFILE_PATH="${REPO_ROOT}/${FOUNDRY_IMAGE}"
    elif [[ -f "$FOUNDRY_IMAGE" ]]; then
        export FOUNDRY_IMAGE_TYPE="build"
        export DOCKERFILE_PATH="$FOUNDRY_IMAGE"
    else
        export FOUNDRY_IMAGE_TYPE="pull"
        export REMOTE_IMAGE_REF="$FOUNDRY_IMAGE"
    fi

    # 8. Metadata (Anchor the BUILD_ID to the GitHub Run)
    if [ -n "$GITHUB_RUN_ID" ]; then
        export BUILD_ID="gh_${GITHUB_RUN_ID}"
    else
        export BUILD_ID=$(date +%Y%m%d_%H%M)
    fi

    export CURRENT_DIST_DIR="${HOST_DIST_BASE}/build_${BUILD_ID}"
    mkdir -p "$CURRENT_DIST_DIR"
    
    echo "📂 Artifact Target: $CURRENT_DIST_DIR"    
    echo "✅ Environment fueled for $TARGET_ARCH build."
else
    echo "❌ Error: $PARAMS_FILE not found!"
    exit 1
fi