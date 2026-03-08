#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables
source "$(dirname "$0")/../../env_setup.sh" "$@"

echo "Sending system to sleep..."
# Place holder command for sleep - replace with actual command to put system to sleep
echo "System is now in sleep mode."