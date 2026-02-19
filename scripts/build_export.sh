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
    echo "ARTIFCAT_DELIVERY is enabled"
    _commpression_command=()
    if [[ "$ARTIFCAT_COMMPRESSION" == "tar.gz" ]]; then
        echo "Artifact compression: tar.gz"
        _commpression_command=("tar" "-czf" "${BUILD_OUTPUT_DIR}.tar.gz" "-C" "${BUILD_OUTPUT_DIR}" ".")
    elif [[ "$ARTIFCAT_COMMPRESSION" == "zip" ]]; then
        echo "Artifact compression: zip"
        _commpression_command=("zip" "-r" "${BUILD_OUTPUT_DIR}.zip" "${BUILD_OUTPUT_DIR}")
    else
        echo "No valid ARTIFCAT_COMMPRESSION method specified"
    fi

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
        "${_commpression_command[@]}"
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
        
        _rsync_cmd=("rsync" "-avz")
        # Ensure rsync fails fast on connection errors (BatchMode) just like SCP
        _ssh_opts="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes"
        if [[ -n "$ARTIFCAT_SSH_KEY" ]]; then
            echo "   → SSH Key: SET (${ARTIFCAT_SSH_KEY})"
            _ssh_opts+=" -i '$ARTIFCAT_SSH_KEY'"
        fi
        _rsync_cmd+=("-e" "$_ssh_opts" "${BUILD_OUTPUT_DIR}" "${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}")
        
        "${_commpression_command[@]}"
        "${_rsync_cmd[@]}"

    elif [[ "$ARTIFCAT_DELIVERY_METHOD" == "local_copy" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "LOCAL_COPY" ]]; then
        echo "LOCAL_COPY delivery selected."
        if [[ -d "$LOCAL_DELIVERY_PATH" ]]; then
            echo "   → Local Delivery Path: $LOCAL_DELIVERY_PATH"
            "${_commpression_command[@]}"
            cp -r "${BUILD_OUTPUT_DIR}/" "${LOCAL_DELIVERY_PATH}/"
            echo "   → Artifacts copied to ${LOCAL_DELIVERY_PATH}/"
        else
            echo "   → No valid LOCAL_DELIVERY_PATH specified."
            exit 1
        fi

    elif [[ "$ARTIFCAT_DELIVERY_METHOD" == "local_move" ]] || [[ "$ARTIFCAT_DELIVERY_METHOD" == "LOCAL_MOVE" ]]; then
        echo "LOCAL_MOVE delivery selected."
        if [[ -d "$LOCAL_DELIVERY_PATH" ]]; then
            echo "   → Local Delivery Path: $LOCAL_DELIVERY_PATH"
            "${_commpression_command[@]}"
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