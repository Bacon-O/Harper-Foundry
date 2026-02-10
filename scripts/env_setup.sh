#!/bin/bash

# Define the location of the blueprint
PARAMS_FILE="params/foundry.params"

if [ -f "$PARAMS_FILE" ]; then
    echo "📖 Hydrating Environment from $PARAMS_FILE..."
    
    # Export all variables defined in the params file
    set -a
    source "$PARAMS_FILE"
    set +a
    
    # Capture Host Identity for file permission fixing later
    export HOST_UID=$(id -u)
    export HOST_GID=$(id -g)
    
    echo "✅ Environment fueled for $TARGET_ARCH build."
else
    echo "❌ Error: $PARAMS_FILE not found! Check your directory structure."
    exit 1
fi