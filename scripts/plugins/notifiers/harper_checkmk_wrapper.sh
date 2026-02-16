#!/bin/bash
# CheckMK Local Check Wrapper for Harper Builds
# 
# Installation:
#   sudo ln -s /path/to/Debian-Harper/scripts/plugins/notifiers/harper_checkmk_wrapper.sh \
#     /usr/lib/check_mk_agent/local/harper_builds
#
# Or copy this file and modify REPO_ROOT path

# Set Harper repository root (MODIFY THIS PATH)
REPO_ROOT="${REPO_ROOT}"

# Load runner and execute check
cd "$REPO_ROOT" || exit 3
source "$REPO_ROOT/scripts/plugins/notifiers/runner.sh" 2>/dev/null || exit 3
notify harper_checkmk --profile alloy_deb13
