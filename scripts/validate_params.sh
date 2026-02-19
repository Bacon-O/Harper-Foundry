#!/bin/bash
# ==============================================================================
# HARPER FOUNDRY: PARAMS VALIDATION SCRIPT
# ==============================================================================
# This script validates foundry_template.params files to catch common configuration
# errors before running a build.

set -e

genereate_foundry_params() {
    cat <<EOF > "../params/foundry_template_02.params"
# ==============================================================================
# HARPER FOUNDRY: BLUEPRINT CONFIGURATION - TEMPLATE
# ==============================================================================
# ⚠️  THIS IS A TEMPLATE! DO NOT USE DIRECTLY!
#
# This file intentionally has INCOMPLETE/INVALID configuration to prevent
# accidental use. Copy and customize this file to create your own build config.
#
# Example:
#   cp params/foundry_template.params params/my_custom_build.params
#   # Edit params/my_custom_build.params with your settings
#   ./start_build.sh -p params/my_custom_build.params
#
# ==============================================================================

# ==============================================================================
# CORE FOUNDRY SETUP (Hard Requirements)
# These parameters are essential for the build system to function.
# Incorrect values will likely prevent the build from starting or completing.
# ==============================================================================

# --- Pathing & Identity ---
# BUILD_WORKSPACE_DIR: Where kernel compilation occurs (can be on fast storage)
#                      Mounted as /build inside the container
# HOST_OUTPUT_DIR:     Where build artifacts are stored (each build creates build_<timestamp>)
# USE_PARAM_SCOPED_DIRS: When true, repo-relative defaults are scoped per params name
# 
# Note: REPO_ROOT is auto-detected - no configuration needed
#
# ⚠️  REQUIRED: Set these to your actual paths!
BUILD_WORKSPACE_DIR=""
HOST_OUTPUT_DIR=""

# When true, repo-relative defaults based on params file name
#       eg: BUILD_WORKSPACE_DIR=BUILD_WORKSPACE_DIR/<params_file>/
# When false aboslute outpaths are respected 
#       eg: BUILD_WORKSPACE_DIR=BUILD_WORKSPACE_DIR/
USE_PARAM_SCOPED_DIRS="true"

# Leave empty ("") to auto-detect the current host user's UID/GID for file ownership.
FOUNDRY_UID=""
FOUNDRY_GID=""

# --- Foundry Execution ---
# The script within the container that Docker will execute.
FOUNDRY_EXEC=""
INCREMENTAL_BUILD="false"

# --- Foundry artifact export configuration ---
# If ARTIFCAT_DELIVERY is true, the built artifacts will be securely copied to a remote server.
# Right now SFTP and RSYNC are supported as delivery methods.
# Both require previous configuration
ARTIFCAT_DELIVERY="false"
ARTIFCAT_COMMPRESSION=""
ARTIFCAT_DELIVERY_METHOD=""
REMOTE_DELIVERY_HOST=""
REMOTE_DELIVERY_USER=""
REMOTE_DELIVERY_PATH=""
ARTIFCAT_SSH_KEY=""  # Optional: Path to SSH key for authentication (if needed)
LOCAL_DELIVERY_PATH=""

# --- Foundry Image Configuration ---
# ⚠️  REQUIRED: Path to a local Dockerfile or a Registry image
DOCKERFILE_PATH=""
CONTAINER_IMAGE_NAME=""

# ==============================================================================
# TARGET KERNEL DEFINITION
# These parameters define the specific kernel to be built.
# ==============================================================================

# --- Versioning & Tagging ---
BUILD_ARCH_TAG=""
RELEASE_TAG=""

# --- Target Specifications ---
# ⚠️  REQUIRED: Set the target architecture (x86_64, aarch64, etc.)
TARGET_ARCH=""

KERNEL_CFLAGS=""
CROSS_COMPILE_PREFIX=""
DEBIAN_PACKAGE_NAME=""

# --- Kernel Source Strategy (Plugin-based) ---
# The kernel source plugin system maps KERNEL_SOURCE to specific fetching methods.
# Supported values:
#   - "kernel.org"  : Official vanilla upstream sources (fast, no Debian patches)
#   - "debian"      : Debian apt-get source (includes Debian customizations)
#   - "debian/trixie-backports" : Debian Trixie Backports (newer kernels with Debian patches)
#   - "custom"      : Skip auto-fetch; implement your own logic in ci-build
#   - "none"        : Skip auto-fetch; implement your own logic in ci-build
# See: scripts/plugins/kernelsources/README.md
KERNEL_SOURCE=""
# KERNEL_VERSION supports semantic aliases (source-aware interpretation):
#   - "" (empty) or omitted: Uses source defaults (kernel.org → 6.11.8, debian → latest, etc.)
#   - "latest": Latest stable/available from source
#   - "stable": Latest stable (same as latest for most sources)
#   - "lts": Latest LTS kernel if available from source
#   - "rc": Release candidates if available
#   - Specific version: "6.11.8", "6.10.5", etc. (pins to exact version when available)
# Examples:
#   KERNEL_VERSION=""                  # Uses source defaults
#   KERNEL_VERSION="latest"            # Always get newest available
#   KERNEL_VERSION="lts"               # Get LTS variant
#   KERNEL_VERSION="6.11.8"            # Pin to specific version
KERNEL_VERSION=""

DEB_HOST_ARCH=""
HOST_QEMU_STATIC=""

BUILD_DEB_BUILD_ARCH=""
BUILD_DEB_TARGET_ARCH=""
BUILD_CC=""
BUILD_HOSTLD=""
BUILD_HOSTCFLAGS=""
BUILD_HOSTLDFLAGS=""
BUILD_LLVM="1"

# ==============================================================================
# BUILD STRATEGY & FEATURES
# These parameters control the build process and specific kernel features.
# ==============================================================================

# --- Performance & Parallelism ---
# Number of CPU cores for the build. Leave empty ("") to use nproc-1 (min 1).
PARALLEL_JOBS=""

# --- Build Strategy ---
# BASE_CONFIG points to a file in /configs or a kbuild target (defconfig/tinyconfig)
BASE_CONFIG=""
TUNING_CONFIG=""

# Note: KERNEL_VERSION is used by kernel source plugins to determine which kernel
# version to fetch. It's optional - see KERNEL_VERSION documentation above.

# --- Scheduler Patch ---

# ==============================================================================
# QUALITY ASSURANCE (QA) & TESTING
# These parameters control post-build validation and testing.
# ==============================================================================

# --- QA Flags ---
BYPASS_QA="false"
ENABLE_QEMU_TESTS="false"
QA_MODE="RELAXED"

QA_TESTS=(
)

QA_TEST_PACKAGE=(
)

# --- Chemical Audit: Critical (Must Pass) ---
QA_CRITICAL_CHECKS=( 
)

# --- Chemical Audit: Optional (Warn Only) ---
QA_OPTIONAL_CHECKS=(
)

# --- VM Proving Ground Specs (for QEMU testing) ---
QA_VM_MEMORY="1G"
QA_VM_CORES="4"
QA_VM_TIMEOUT="30s"

# ==============================================================================
# ENVIRONMENT CUSTOMIZATION
# ==============================================================================

# --- Environment Extensions ---
# Optionally specify which environment extensions to load (in order).
# Leave empty to load none: ENV_EXTENSIONS=()
ENV_EXTENSIONS=()
# ==============================================================================
EOF
}

genereate_foundry_params
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARAMS_FILE="${1:-${REPO_ROOT}/params/foundry_template.params}"

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

# Check if foundry script exists (smart lookup: scripts.d/ first, then scripts/)
foundry_found=false
if [ -f "${REPO_ROOT}/scripts/scripts.d/$FOUNDRY_EXEC" ]; then
    echo "  ✅ Foundry exec script found (custom): scripts/scripts.d/$FOUNDRY_EXEC"
    foundry_found=true
elif [ -f "${REPO_ROOT}/scripts/$FOUNDRY_EXEC" ]; then
    echo "  ✅ Foundry exec script found (official): scripts/$FOUNDRY_EXEC"
    foundry_found=true
elif [ -L "${REPO_ROOT}/scripts/$FOUNDRY_EXEC" ]; then
    echo "  ✅ Foundry exec script found (symlink): scripts/$FOUNDRY_EXEC"
    foundry_found=true
fi

if [ "$foundry_found" = false ]; then
    echo "  ❌ ERROR: Foundry exec script not found: $FOUNDRY_EXEC"
    echo "     Checked: scripts/scripts.d/$FOUNDRY_EXEC, scripts/$FOUNDRY_EXEC"
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
        # Check custom packages first (scripts.d/plugins/qatests/packages/) - takes precedence
        custom_pkg="${REPO_ROOT}/scripts/scripts.d/plugins/qatests/packages/${package}.lst"
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
