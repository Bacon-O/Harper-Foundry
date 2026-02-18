#!/bin/bash
set -e

# 1. Load the Foundry Environment
source "$(dirname "$0")/env_setup.sh" "$@"


### Place holder for future export functionality. This will likely involve:
# - Packaging build artifacts into a tarball or zip file
# - Optionally uploading to a remote server or cloud storage
# - Generating checksums for integrity verification
# - Providing a summary report of the exported artifacts 
###
# ARTIFCAT_DELIVERY="false"
# ARTIFCAT_DELIVERY_METHOD=""
# REMOTE_DELIVERY_HOST=""
# REMOTE_DELIVERY_USER=""
# REMOTE_DELIVERY_PATH=""
# ARTIFCAT_SSH_KEY=""  # Optional: Path to SSH key for authentication (if needed)
# LOCAL_DELIVERY_PATH="${BUILD_OUTPUT_DIR}/build_${TIMESTAMP}/artifacts"

echo "🚀 Export functionality is not yet implemented. Stay tuned for updates!"

# Validation check for remote delivery configuration (if enabled)
if [[ "$ARTIFCAT_DELIVERY" == "true" ]]; then
    echo "⚠️  ARTIFCAT_DELIVERY is enabled, but export functionality is not implemented. Please disable ARTIFCAT_DELIVERY or wait for future updates."
    

    if [[ "$ARTIFCAT_DELIVERY_METHOD" == "sftp" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "SFTP" ]] || 
        [[ "$ARTIFCAT_DELIVERY_METHOD" == "scp" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "SCP" ]]; then
        
        echo "   → Delivery Method: $ARTIFCAT_DELIVERY_METHOD"
        if [[ -n "$REMOTE_DELIVERY_HOST" ]]; then
            echo "   → Delivery Host: $REMOTE_DELIVERY_HOST"
        else
            echo "   → No REMOTE_DELIVERY_HOST specified."
            exit 1
        fi
    
        if [[ -n "$REMOTE_DELIVERY_USER" ]]; then
            echo "   → Delivery User: $REMOTE_DELIVERY_USER"
        else
            echo "   → No REMOTE_DELIVERY_USER specified."
            exit 1
        fi
        
        if [[ -n "$REMOTE_DELIVERY_PATH" ]]; then
            echo "   → Delivery Path: $REMOTE_DELIVERY_PATH"
        else
            echo "   → No REMOTE_DELIVERY_PATH specified."
            exit 1
        fi
        
        # Use an array to construct the command safely (avoids eval)
        _sftp_cmd=("scp" "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=yes")
        if [[ -n "$ARTIFCAT_SSH_KEY" ]]; then
            echo "   → SSH Key: SET (${ARTIFCAT_SSH_KEY})"
            _sftp_cmd+=("-i" "$ARTIFCAT_SSH_KEY")
        fi
        
        _sftp_cmd+=("-r" "${BUILD_OUTPUT_DIR}" "${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}")
        
        "${_sftp_cmd[@]}"

    elif [[ "$ARTIFCAT_DELIVERY_METHOD" == "rsync" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "RSYNC" ]]; then
        
        echo "   → Delivery Method: $ARTIFCAT_DELIVERY_METHOD"
        if [[ -n "$REMOTE_DELIVERY_HOST" ]]; then
            echo "   → Delivery Host: $REMOTE_DELIVERY_HOST"
        else
            echo "   → No REMOTE_DELIVERY_HOST specified."
            exit 1 
        fi
        if [[ -n "$REMOTE_DELIVERY_USER" ]]; then
            echo "   → Delivery User: $REMOTE_DELIVERY_USER"
        else
            echo "   → No REMOTE_DELIVERY_USER specified."
            exit 1
        fi
        if [[ -n "$REMOTE_DELIVERY_PATH" ]]; then
            echo "   → Delivery Path: $REMOTE_DELIVERY_PATH"
        else
            echo "   → No REMOTE_DELIVERY_PATH specified."
            exit 1
        fi 
        echo "⚠️  RSYNC delivery method is not yet implemented. Please wait for future updates."
        # Placeholder for RSYNC upload command
        echo "🧪 [DRY RUN] Placeholder command for RSYNC upload:"
        echo "rsync -avz ${BUILD_OUTPUT_DIR}/ ${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}"

    elif [[ "$ARTIFCAT_DELIVERY_METHOD" == "local_copy" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "LOCAL_COPY" ]]; then
        echo "⚠️  LOCAL_COPY delivery method is not yet implemented. Please wait for future updates."
        if [[ -d "$LOCAL_DELIVERY_PATH" ]]; then
            echo "   → Local Delivery Path: $LOCAL_DELIVERY_PATH"
            cp -r "${BUILD_OUTPUT_DIR}/" "${LOCAL_DELIVERY_PATH}/"
            echo "   → Artifacts copied to ${LOCAL_DELIVERY_PATH}/"
        else
            echo "   → No valid LOCAL_DELIVERY_PATH specified."
            exit 1
        fi

    elif [[ "$ARTIFCAT_DELIVERY_METHOD" == "local_move" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "LOCAL_MOVE" ]]; then
        echo "⚠️  LOCAL_MOVE delivery method is not yet implemented. Please wait for future updates."
        if [[ -d "$LOCAL_DELIVERY_PATH" ]]; then
            echo "   → Local Delivery Path: $LOCAL_DELIVERY_PATH"
            mv -f "${BUILD_OUTPUT_DIR}/" "${LOCAL_DELIVERY_PATH}/"
            echo "   → Artifacts moved to ${LOCAL_DELIVERY_PATH}/"
        else
            echo "   → No valid LOCAL_DELIVERY_PATH specified."
            exit 1
        fi  
    else
        echo "⚠️  Unsupported ARTIFCAT_DELIVERY_METHOD: $ARTIFCAT_DELIVERY_METHOD. Supported methods are: sftp, scp, rsync, local_copy, local_move."
        exit 1
    fi
fi

exit 0