#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables
source "$(dirname "$0")/../../env_setup.sh" "$@"

echo "System is powering off..."
# Place holder command for power off - replace with actual command to power off the system