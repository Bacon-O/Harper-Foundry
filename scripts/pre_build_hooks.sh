#!/bin/bash
set -e

# 1. Load Fuel Mix
source "$(dirname "$0")/env_setup.sh" "$@"

echo "Checking for any pre-build hooks configuration steps..."

if [[ ${#PRE_BUILD_HOOKS[@]} -eq 0 ]]; then
    echo "No pre-build hooks configuration specified. Proceeding with default startup sequence."
else
    echo "Executing pre-build hooks configuration(s): ${PRE_BUILD_HOOKS[*]}"
    for entry in "${PRE_BUILD_HOOKS[@]}"; do
        script_path=""
        if [[ -f "$entry" ]]; then
            script_path="$entry"
        elif [[ -f "${REPO_ROOT}/scripts/scripts.d/plugins/tools/$entry" ]]; then
            script_path="${REPO_ROOT}/scripts/scripts.d/plugins/tools/$entry"
        elif [[ -f "${REPO_ROOT}/scripts/plugins/tools/$entry" ]]; then
            script_path="${REPO_ROOT}/scripts/plugins/tools/$entry"
        fi

        if [[ -n "$script_path" ]]; then
            echo "  → Running: $script_path"
            _command=("$script_path" "$@" )
            "${_command[@]}"
        else
            echo "⚠️  Warning: Pre-build hooks script not found: $entry"
        fi
    done
    echo "Pre-build hooks configuration executed successfully."
fi

echo "Pre-build hooks sequence complete."