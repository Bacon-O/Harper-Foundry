#!/bin/bash
set -e

genereate_foundry_params() {
    cat <<EOF > "$1/params/foundry_template.params"
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


VERSION="v0.0-alpha-rc1"

# Determine the repository root, assuming install.sh is in the root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PARAMS_FILE="${REPO_ROOT}/params/foundry_template.params"
PARAMS_FILE="${REPO_ROOT}/params/foundry_template.params"
TEMP_PARAMS_FILE="${PARAMS_FILE}.tmp"
SOURCE_PARAMS_FILE="$PARAMS_FILE"

# Handle version and help flags early
if [[ "$1" == "-v" ]] || [[ "$1" == "--version" ]]; then
    echo "Harper Foundry $VERSION"
    exit 0
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version information"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Description:"
    echo "  Interactive setup wizard for Harper Foundry configuration."
    echo ""
    exit 0
fi

echo "==================================================="
echo " Harper Foundry: Interactive Setup ($VERSION)"
echo "==================================================="
echo ""

# Check prerequisites first
if [[ -f "${REPO_ROOT}/scripts/check_prerequisites.sh" ]]; then
    echo "🔍 Checking system prerequisites..."
    if "${REPO_ROOT}/scripts/check_prerequisites.sh"; then
        echo ""
        echo "✅ Prerequisites check passed!"
        echo ""
    else
        echo ""
        echo "⚠️  Some prerequisites are missing or suboptimal."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
        echo ""
    fi
fi

if [[ ! -f "$TEMPLATE_PARAMS_FILE" ]]; then
    echo "❌ Error: Template params file not found: $TEMPLATE_PARAMS_FILE"
    read -p "Would you like to generate it now? (y/n): " -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        genereate_foundry_params "$REPO_ROOT"
        echo "✅ Template params file generated at $TEMPLATE_PARAMS_FILE. Please customize it before running the build."
    else
        echo "Aborting installation. Please ensure the repository is complete."
        exit 1
    fi  
fi
if [[ -f "$PARAMS_FILE" ]]; then
    SOURCE_PARAMS_FILE="$PARAMS_FILE"
else
    SOURCE_PARAMS_FILE="$TEMPLATE_PARAMS_FILE"
    echo "ℹ️  No existing params file found at $PARAMS_FILE."
    echo "   Using template $TEMPLATE_PARAMS_FILE to generate a new config."
fi

# --- Dynamic Parameter Loading and Prompting ---

declare -A current_values # Stores current values of all simple variables
declare -A new_values     # Stores user-provided or default new values for prompted variables
declare -A prompt_descriptions # Stores descriptions for variables to be prompted

param_lines=() # Array to hold all lines of the params file, preserving order
current_description="" # Stores the description from the last # @PROMPT comment

echo "📖 Analyzing $SOURCE_PARAMS_FILE for configurable parameters..."

while IFS= read -r line || [[ -n "$line" ]]; do
    param_lines+=("$line")

    # Check for prompt description
    if [[ "$line" =~ ^#\ @PROMPT\ \"(.*)\"$ ]]; then
        current_description="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^#\ @NO_PROMPT ]]; then
        current_description="" # Reset description if explicitly marked as no-prompt
    elif [[ "$line" =~ ^([A-Z_]+)=\"(.*)\"$ ]]; then # Match VAR="VALUE"
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        current_values["$var_name"]="$var_value"
        if [[ -n "$current_description" ]]; then
            prompt_descriptions["$var_name"]="$current_description"
            current_description="" # Reset after associating with a variable
        fi
    elif [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then # Match VAR=VALUE (without quotes, handles arrays like VAR=(val1 val2))
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        # Only store simple key-value pairs in current_values for prompting.
        # Array-like values will be preserved by printing the original line.
        if [[ ! "$var_value" =~ ^\(.*\) ]]; then # If it's not an array-like value
            current_values["$var_name"]="$var_value"
        fi
        if [[ -n "$current_description" ]]; then
            prompt_descriptions["$var_name"]="$current_description"
            current_description="" # Reset after associating with a variable
        fi
    fi
done < "$SOURCE_PARAMS_FILE"
# At this point, current_values contains all simple variables and their current values,
# --- Prompting Function ---
prompt_for_variable() {
    local var_name="$1"
    local current_value="$2"
    local description="$3"
    local input_value

    if [[ -n "$description" ]]; then
        echo "" >&2
        echo "$description" >&2
    fi
    read -rp "($var_name) [$current_value]: " input_value
    if [[ -z "$input_value" ]]; then
        echo "$current_value" # Return current_value
    else
        echo "$input_value" # Return input_value
    fi
}

# --- Interactive Prompts ---
echo ""
echo "Please provide the following paths. These are critical for the build system"
echo "to correctly locate your repository and store build artifacts. Defaults are"
echo "based on $SOURCE_PARAMS_FILE."

for var_name in "${!prompt_descriptions[@]}"; do
    current_val="${current_values[$var_name]}"
    description="${prompt_descriptions[$var_name]}"
    new_val=$(prompt_for_variable "$var_name" "$current_val" "$description")
    new_values["$var_name"]="$new_val"
done

echo ""
echo "---------------------------------------------------"
echo "QA Parameters: Not prompting for most QA parameters as per default recommendations."
echo "BYPASS_QA will be explicitly set to 'false' to ensure QA is active by default."
echo "---------------------------------------------------"
new_values["BYPASS_QA"]="false" # Explicitly set as per requirement

# --- Generate New params/foundry_template.params ---
echo ""
echo "✍️  Updating $PARAMS_FILE with new configuration..."

# Read the original file, make replacements, and write to a temporary file
for line in "${param_lines[@]}"; do
    # Preserve comments and blank lines
    if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
        echo "$line"
        continue
    fi

    if [[ "$line" =~ ^([A-Z_]+)= ]]; then
        var_name="${BASH_REMATCH[1]}"
        if [[ -n "${new_values[$var_name]}" ]]; then
            printf "%s=\"%s\"\n" "$var_name" "${new_values[$var_name]}"
        else
            echo "$line" # Keep original line for non-prompted variables (including arrays)
        fi
    else
        echo "$line" # Keep comments, blank lines, etc.
    fi
done > "$TEMP_PARAMS_FILE"

# Replace original file with the new one
mv "$TEMP_PARAMS_FILE" "$PARAMS_FILE"
echo "✅ Configuration updated successfully in $PARAMS_FILE."

# Validate the updated configuration
echo ""
echo "🔍 Validating configuration..."
if [[ -f "${REPO_ROOT}/scripts/validate_params.sh" ]]; then
    if "${REPO_ROOT}/scripts/validate_params.sh" "$PARAMS_FILE"; then
        echo ""
        echo "✅ Configuration is valid!"
    else
        echo ""
        echo "⚠️  Configuration validation found issues."
        echo "You may want to review and fix them before running a build."
    fi
fi

echo ""
echo "🔧 Configuring git hooks..."
if git config --local core.hooksPath .githooks 2>/dev/null; then
    echo "✅ Git hooks configured to use .githooks directory"
    echo "   Pre-commit hook will run shellcheck on *.sh files (if shellcheck is installed)"
    echo "   Note: shellcheck is optional for regular users, required for contributors"
else
    echo "ℹ️  Skipping git hooks setup (not in a git repository or git not available)"
fi

echo ""
echo "==================================================="
echo "🎉 Setup Complete!"
echo "==================================================="
echo ""
echo "Template tip: $TEMPLATE_PARAMS_FILE is a good starting point for new configs."
echo ""
echo "Next steps:"
echo "  1. Review the configuration: cat $PARAMS_FILE"
echo "  2. Start a test build: ./start_build.sh --test-run"
echo "  3. Start a full build: ./start_build.sh"
echo ""
echo "For more information, see README.md"
echo "==================================================="