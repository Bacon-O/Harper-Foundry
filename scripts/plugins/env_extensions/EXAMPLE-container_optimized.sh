#!/bin/bash
# Example: Container-optimized environment extension
#
# This is an EXAMPLE extension showing how to layer environment customizations
# on top of env_setup.sh without modifying the core script.
#
# Location: scripts/plugins/env_extensions/
# (This is the official project directory)
#
# For your own custom extensions WITHOUT git conflicts, use:
# scripts/scripts.d/plugins/env_extensions/

# Example: Override Docker memory limit for larger builds
if [[ -z "$DOCKER_MEMORY_LIMIT" ]]; then
    export DOCKER_MEMORY_LIMIT="8g"
fi

# Example: Set custom CPU limits
if [[ -z "$DOCKER_CPU_LIMIT" ]]; then
    export DOCKER_CPU_LIMIT="16"
fi

# Uncomment to enable:
# echo "🐳 Container-optimized environment extension applied"
