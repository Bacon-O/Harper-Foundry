#!/bin/bash
set -e

# 1. Load Fuel Mix
source "$(dirname "$0")/env_setup.sh" "$@"

echo "Performing post-build hooks"

if [[ ${#POST_BUILD_HOOKS[@]} -eq 0 ]]; then
    echo "No post-build hooks configuration specified. Skipping post-build steps."
else
    echo "Executing post-build hooks configuration(s): ${POST_BUILD_HOOKS[*]}"
    for entry in "${POST_BUILD_HOOKS[@]}"; do
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
            #bash "$script_path" "$@"
        else
            echo "⚠️  Warning: Post-build hooks script not found: $entry"
        fi
    done
    echo "Post-build hooks configuration executed successfully."
fi

echo "Post-build hooks sequence complete."