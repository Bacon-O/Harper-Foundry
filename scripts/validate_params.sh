#!/bin/bash
# ==============================================================================
# HARPER FOUNDRY: PARAMS VALIDATION SCRIPT
# ==============================================================================
# This script validates foundry.params files to catch common configuration
# errors before running a build.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARAMS_FILE="${1:-${REPO_ROOT}/params/foundry.params}"

echo "🔍 Validating Foundry Parameters..."
echo "📄 File: $PARAMS_FILE"
echo ""

if [ ! -f "$PARAMS_FILE" ]; then
    echo "❌ ERROR: Params file not found: $PARAMS_FILE"
    exit 1
fi

# Load the params file
set -a
# shellcheck source=/dev/null
source "$PARAMS_FILE"
set +a

ERRORS=0
WARNINGS=0

# --- Required Variables Check ---
echo "🔎 Checking Required Variables..."

REQUIRED_VARS=(
    "BUILD_WORKSPACE_DIR"
    "HOST_OUTPUT_DIR"
    "FOUNDRY_EXEC"
    "DOCKERFILE_PATH"
    "CONTAINER_IMAGE_NAME"
    "TARGET_ARCH"
    "KERNEL_SOURCE"
    "BASE_CONFIG"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        if [ "$var" == "BUILD_WORKSPACE_DIR" ]; then
            BUILD_WORKSPACE_DIR="${REPO_ROOT}/build-workspace"
            echo "  ⚠️  $var not set, defaulting to $BUILD_WORKSPACE_DIR"
            ((WARNINGS++))
            continue
        fi
        if [ "$var" == "HOST_OUTPUT_DIR" ]; then
            HOST_OUTPUT_DIR="${REPO_ROOT}/output"
            echo "  ⚠️  $var not set, defaulting to $HOST_OUTPUT_DIR"
            ((WARNINGS++))
            continue
        fi
        echo "  ❌ MISSING: $var is not set"
        ((ERRORS++))
    else
        echo "  ✅ $var = ${!var}"
    fi
done

echo ""
echo "🗂️  Checking Path Existence..."

# --- Path Checks ---
# Check if Docker image exists (if it's a file path)
if [[ -f "${REPO_ROOT}/${DOCKERFILE_PATH}" ]] || [[ -f "$DOCKERFILE_PATH" ]]; then
    echo "  ✅ Dockerfile found: $DOCKERFILE_PATH"
elif [[ "$DOCKERFILE_PATH" =~ / ]]; then
    echo "  ℹ️  Registry image (will be pulled): $DOCKERFILE_PATH"
else
    echo "  ⚠️  WARNING: Cannot verify image path: $DOCKERFILE_PATH"
    ((WARNINGS++))
fi

# Check if configs exist
if [[ "$BASE_CONFIG" != "defconfig" ]] && [[ "$BASE_CONFIG" != "tinyconfig" ]]; then
    if [ -f "${REPO_ROOT}/configs/$BASE_CONFIG" ]; then
        echo "  ✅ Base config found: configs/$BASE_CONFIG"
    else
        echo "  ❌ ERROR: Base config not found: configs/$BASE_CONFIG"
        ((ERRORS++))
    fi
fi

if [ -n "$TUNING_CONFIG" ]; then
    if [ -f "${REPO_ROOT}/configs/$TUNING_CONFIG" ]; then
        echo "  ✅ Tuning config found: configs/$TUNING_CONFIG"
    else
        echo "  ❌ ERROR: Tuning config not found: configs/$TUNING_CONFIG"
        ((ERRORS++))
    fi
fi

# Check if foundry script exists
if [ -f "${REPO_ROOT}/scripts/$FOUNDRY_EXEC" ]; then
    echo "  ✅ Foundry exec script found: scripts/$FOUNDRY_EXEC"
elif [ -L "${REPO_ROOT}/scripts/$FOUNDRY_EXEC" ]; then
    echo "  ✅ Foundry exec script found (symlink): scripts/$FOUNDRY_EXEC"
else
    echo "  ❌ ERROR: Foundry exec script not found: scripts/$FOUNDRY_EXEC"
    ((ERRORS++))
fi

echo ""
echo "🧪 Checking Architecture Configuration..."

# --- Architecture Consistency ---
VALID_ARCHES=("x86_64" "aarch64" "arm64" "armv7l")
if [[ ! " ${VALID_ARCHES[*]} " =~ ${TARGET_ARCH} ]]; then
    echo "  ⚠️  WARNING: Unusual TARGET_ARCH: $TARGET_ARCH"
    ((WARNINGS++))
else
    echo "  ✅ Valid TARGET_ARCH: $TARGET_ARCH"
fi

# Check cross-compilation consistency
if [ -n "$CROSS_COMPILE_PREFIX" ]; then
    echo "  ✅ Cross-compilation enabled: $CROSS_COMPILE_PREFIX"
    if [ -z "$BUILD_CC" ]; then
        echo "  ⚠️  WARNING: CROSS_COMPILE_PREFIX set but BUILD_CC is empty"
        ((WARNINGS++))
    fi
fi

echo ""
echo "🛡️  Checking QA Configuration..."

# --- QA Configuration ---
if [ "$BYPASS_QA" == "true" ]; then
    echo "  ⚠️  WARNING: QA is bypassed (BYPASS_QA=true)"
    ((WARNINGS++))
else
    echo "  ✅ QA enabled"
fi

if [ "$QA_MODE" != "RELAXED" ] && [ "$QA_MODE" != "ENFORCED" ]; then
    echo "  ⚠️  WARNING: Invalid QA_MODE: $QA_MODE (should be RELAXED or ENFORCED)"
    ((WARNINGS++))
else
    echo "  ✅ QA_MODE: $QA_MODE"
fi

# Check if QA test scripts exist
if [ ${#QA_TESTS[@]} -gt 0 ]; then
    for test in "${QA_TESTS[@]}"; do
        test_path="${REPO_ROOT}/scripts/plugins/qatests/tests/${test}"
        if [ -x "$test_path" ]; then
            echo "  ✅ QA test exists: $test"
        else
            echo "  ❌ ERROR: QA test missing or not executable: $test"
            ((ERRORS++))
        fi
    done
fi

# Check QA test packages (.lst files)
if [ ${#QA_TEST_PACKAGE[@]} -gt 0 ]; then
    for package in "${QA_TEST_PACKAGE[@]}"; do
        # Check custom packages first (plugins.d/qatests/)
        custom_pkg="${REPO_ROOT}/scripts/plugins/plugins.d/qatests/${package}.lst"
        # Then check project packages
        pkg_path="${REPO_ROOT}/scripts/plugins/qatests/packages/${package}.lst"
        
        if [ -f "$custom_pkg" ]; then
            echo "  ✅ QA test package exists (custom): $package"
        elif [ -f "$pkg_path" ]; then
            echo "  ✅ QA test package exists: $package"
        else
            echo "  ❌ ERROR: QA test package missing: $package"
            ((ERRORS++))
        fi
    done
fi

echo ""
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! Configuration is valid."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Configuration is valid with $WARNINGS warning(s)."
    exit 0
else
    echo "❌ Configuration has $ERRORS error(s) and $WARNINGS warning(s)."
    echo "Please fix the errors before running the build."
    exit 1
fi
