#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables
source "$(dirname "$0")/../../../env_setup.sh" "$@"

# 2. Use the Build Directory
# In QA-only mode, BUILD_OUTPUT_DIR is set directly by env_setup.sh to the test directory
# In normal mode, it's the latest build with timestamp
LATEST_BUILD_DIR="$BUILD_OUTPUT_DIR"

if [[ -z "$LATEST_BUILD_DIR" ]]; then
    echo "❌ ERROR: No build artifacts found in $HOST_OUTPUT_DIR"
    exit 1
fi

echo "🧪 Starting Test: Lintian .deb Package Analysis"
echo "📂 Analyzing Artifact: $LATEST_BUILD_DIR"

# Check lintian is available
if ! command -v lintian &>/dev/null; then
    echo "❌ ERROR: lintian is not installed. Install with: apt-get install lintian"
    exit 1
fi
echo "  🔍 lintian: $(lintian --version 2>&1 | head -1)"

# Find all .deb packages in the build output directory
mapfile -t DEB_FILES < <(find "$LATEST_BUILD_DIR" -maxdepth 1 -name "*.deb" | sort)

if [[ ${#DEB_FILES[@]} -eq 0 ]]; then
    echo "❌ ERROR: No .deb packages found in $LATEST_BUILD_DIR"
    exit 1
fi

echo "  📦 Found ${#DEB_FILES[@]} .deb package(s) to analyse."

OVERALL_ERRORS=0
OVERALL_WARNINGS=0

for deb in "${DEB_FILES[@]}"; do
    pkg_name=$(basename "$deb")
    echo ""
    echo "  📦 Checking: $pkg_name"

    # Run lintian; capture output and exit code without triggering set -e
    lintian_rc=0
    lintian_output=$(lintian --no-tag-display-limit "$deb" 2>&1) || lintian_rc=$?

    # Parse errors (E:) and warnings (W:) from lintian output
    pkg_errors=$(echo "$lintian_output" | grep -c "^E:" || true)
    pkg_warnings=$(echo "$lintian_output" | grep -c "^W:" || true)

    if [[ $lintian_rc -eq 0 && $pkg_errors -eq 0 && $pkg_warnings -eq 0 ]]; then
        echo "  ✅ lintian: PASS — no issues found"
    else
        if [[ $pkg_errors -gt 0 ]]; then
            echo "  ❌ lintian: FAILED — $pkg_errors error(s), $pkg_warnings warning(s)"
            while IFS= read -r line; do
                echo "     🔴 $line"
            done < <(echo "$lintian_output" | grep "^E:")
            OVERALL_ERRORS=$(( OVERALL_ERRORS + pkg_errors ))
        else
            echo "  ⚠️  lintian: WARNING — $pkg_warnings warning(s)"
        fi

        if [[ $pkg_warnings -gt 0 ]]; then
            while IFS= read -r line; do
                echo "     🟡 $line"
            done < <(echo "$lintian_output" | grep "^W:")
            OVERALL_WARNINGS=$(( OVERALL_WARNINGS + pkg_warnings ))
        fi
    fi
done

echo ""
if [[ $OVERALL_ERRORS -gt 0 ]]; then
    if [[ "${QA_MODE:-RELAXED}" == "ENFORCED" ]]; then
        echo "❌ Test Failed: Lintian .deb Package Analysis"
        echo "   $OVERALL_ERRORS error(s), $OVERALL_WARNINGS warning(s) across ${#DEB_FILES[@]} package(s)."
        exit 1
    else
        echo "⚠️  Test Passed with Errors (QA_MODE=RELAXED): Lintian .deb Package Analysis"
        echo "   $OVERALL_ERRORS error(s), $OVERALL_WARNINGS warning(s) across ${#DEB_FILES[@]} package(s)."
        exit 0
    fi
fi

if [[ $OVERALL_WARNINGS -gt 0 ]]; then
    echo "⚠️  Test Passed with Warnings: Lintian .deb Package Analysis"
    echo "   0 errors, $OVERALL_WARNINGS warning(s) across ${#DEB_FILES[@]} package(s)."
else
    echo "✅ Test Passed: Lintian .deb Package Analysis"
fi
exit 0
