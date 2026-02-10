#!/bin/bash
set -e

# 1. Fueling
source ./scripts/env_setup.sh "$@"

# 2. Preheat
bash ./scripts/furnace_preheat.sh "$@"

# 3. Ignition
bash ./scripts/furnace_ignite.sh "$@"

# 4. Material Analysis (Conditional)
if [ "$BYPASS_QA" == "true" ]; then
    echo "⏩ Skipping Material Analysis (Bypass Active)."
else
    bash ./scripts/material_analysis.sh "$@"
fi

echo "✨ Foundry cycle complete."