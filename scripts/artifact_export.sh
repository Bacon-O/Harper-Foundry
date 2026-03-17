#!/bin/bash
set -e

# 1. Load the Foundry Environment
source "$(dirname "$0")/env_setup.sh" "$@"


###
# ARTIFACT_DELIVERY="false"
# ARTIFACT_COMPRESSION="" # Options: "tar.gz", "zip", or "" for none
# ARTIFACT_DELIVERY_METHOD=""
# REMOTE_DELIVERY_HOST=""
# REMOTE_DELIVERY_USER=""
# REMOTE_DELIVERY_PATH=""
# ARTIFACT_SSH_KEY=""  # Optional: Path to SSH key for authentication (if needed)
# LOCAL_DELIVERY_PATH="${BUILD_OUTPUT_DIR}/build_${TIMESTAMP}/artifacts"

echo "🚀 Artifact export starting..."

# Validation check for remote delivery configuration (if enabled)
if [[ "${ARTIFACT_DELIVERY:-false}" == "true" ]]; then
    echo "Artifact delivery is enabled"
    compression_command=()
    delivery_command=()
    delivery_message=""
    build_artifact="${BUILD_OUTPUT_DIR}"
    
    # Check for compression method and validate parameters
    if [[ -n "${ARTIFACT_COMPRESSION:-}" ]]; then
        if [[ "$ARTIFACT_COMPRESSION" == "tar.gz" ]]; then
            echo "Artifact compression: tar.gz"
            _src_dir="$(dirname "$BUILD_OUTPUT_DIR")"
            _src_name="$(basename "$BUILD_OUTPUT_DIR")"
            build_artifact="${BUILD_OUTPUT_DIR}.tar.gz"
            compression_command=("tar" "-C" "$_src_dir" "-czf" "$build_artifact" "$_src_name")
        elif [[ "$ARTIFACT_COMPRESSION" == "zip" ]]; then
            echo "Artifact compression: zip"
            _src_dir="$(dirname "$BUILD_OUTPUT_DIR")"
            _src_name="$(basename "$BUILD_OUTPUT_DIR")"
            build_artifact="${BUILD_OUTPUT_DIR}.zip"
            compression_command=("bash" "-c" "cd '$_src_dir' && zip -r '$build_artifact' '$_src_name'")
        else
            echo "No valid Artifact compression method specified"
            exit 1
        fi
    else
        echo "No Artifact compression method specified, skipping compression"
    fi

    if [[ "${ARTIFACT_DELIVERY_METHOD:-}" == "sftp" ]] || [[ "$ARTIFACT_DELIVERY_METHOD" == "SFTP" ]] || 
        [[ "$ARTIFACT_DELIVERY_METHOD" == "scp" ]] || [[ "$ARTIFACT_DELIVERY_METHOD" == "SCP" ]]; then
        
        echo "   → Delivery Method: $ARTIFACT_DELIVERY_METHOD"
        if [[ -n "${REMOTE_DELIVERY_HOST:-}" ]]; then
            echo "   → Delivery Host: $REMOTE_DELIVERY_HOST"
        else
            echo "   → No REMOTE_DELIVERY_HOST specified."
            exit 1
        fi
    
        if [[ -n "${REMOTE_DELIVERY_USER:-}" ]]; then
            echo "   → Delivery User: $REMOTE_DELIVERY_USER"
        else
            echo "   → No REMOTE_DELIVERY_USER specified."
            exit 1
        fi
        
        if [[ -n "${REMOTE_DELIVERY_PATH:-}" ]]; then
            echo "   → Delivery Path: $REMOTE_DELIVERY_PATH"
        else
            echo "   → No REMOTE_DELIVERY_PATH specified."
            exit 1
        fi
        
        # Use an array to construct the command safely (avoids eval)
        delivery_command=("scp" "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=yes")
        
        if [[ -n "${ARTIFACT_SSH_KEY:-}" ]]; then
            echo "   → SSH Key: SET (${ARTIFACT_SSH_KEY})"
            delivery_command+=("-i" "$ARTIFACT_SSH_KEY")
        fi

        delivery_message="SCP delivery to ${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}"
        delivery_command+=("${build_artifact}" "${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}")

    elif [[ "${ARTIFACT_DELIVERY_METHOD:-}" == "rsync" ]] || [[ "$ARTIFACT_DELIVERY_METHOD" == "RSYNC" ]]; then
        
        echo "   → Delivery Method: $ARTIFACT_DELIVERY_METHOD"
        if [[ -n "${REMOTE_DELIVERY_HOST:-}" ]]; then
            echo "   → Delivery Host: $REMOTE_DELIVERY_HOST"
        else
            echo "   → No REMOTE_DELIVERY_HOST specified."
            exit 1 
        fi
        if [[ -n "${REMOTE_DELIVERY_USER:-}" ]]; then
            echo "   → Delivery User: $REMOTE_DELIVERY_USER"
        else
            echo "   → No REMOTE_DELIVERY_USER specified."
            exit 1
        fi
        if [[ -n "${REMOTE_DELIVERY_PATH:-}" ]]; then
            echo "   → Delivery Path: $REMOTE_DELIVERY_PATH"
        else
            echo "   → No REMOTE_DELIVERY_PATH specified."
            exit 1
        fi 
        
        delivery_command=("rsync" "-avz")
        # Ensure rsync fails fast on connection errors (BatchMode) just like SCP
        _ssh_opts=("ssh" "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=yes")
        if [[ -n "${ARTIFACT_SSH_KEY:-}" ]]; then
            echo "   → SSH Key: SET (${ARTIFACT_SSH_KEY})"
            _ssh_opts+=("-i" "$ARTIFACT_SSH_KEY")
        fi
        # Build ssh command string from array
        _ssh_cmd="${_ssh_opts[0]}"
        for arg in "${_ssh_opts[@]:1}"; do _ssh_cmd+=" '$arg'"; done

        delivery_message="RSYNC delivery to ${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}"
        delivery_command+=("-e" "$_ssh_cmd" "${build_artifact}" "${REMOTE_DELIVERY_USER}@${REMOTE_DELIVERY_HOST}:${REMOTE_DELIVERY_PATH}")

    elif [[ "${ARTIFACT_DELIVERY_METHOD:-}" == "local_copy" ]] || [[ "$ARTIFACT_DELIVERY_METHOD" == "LOCAL_COPY" ]]; then
        echo "LOCAL_COPY delivery selected."
        if [[ -d "${LOCAL_DELIVERY_PATH:-}" ]]; then
            echo "   → Local Delivery Path: $LOCAL_DELIVERY_PATH"
            delivery_command=("cp" "-r" "${BUILD_OUTPUT_DIR}" "${LOCAL_DELIVERY_PATH}/")
            delivery_message="Local copy to ${LOCAL_DELIVERY_PATH}/"
        else
            echo "   → No valid LOCAL_DELIVERY_PATH specified."
            exit 1
        fi

    elif [[ "${ARTIFACT_DELIVERY_METHOD:-}" == "local_move" ]] || [[ "$ARTIFACT_DELIVERY_METHOD" == "LOCAL_MOVE" ]]; then
        echo "LOCAL_MOVE delivery selected."
        if [[ -d "${LOCAL_DELIVERY_PATH:-}" ]]; then
            echo "   → Local Delivery Path: $LOCAL_DELIVERY_PATH"
            "${compression_command[@]}"
            delivery_command=("mv" "-f" "${BUILD_OUTPUT_DIR}" "${LOCAL_DELIVERY_PATH}/")
            delivery_message="Local move to ${LOCAL_DELIVERY_PATH}/"
        else
            echo "   → No valid LOCAL_DELIVERY_PATH specified."
            exit 1
        fi  
    else
        echo "⚠️  Unsupported ARTIFACT_DELIVERY_METHOD: $ARTIFACT_DELIVERY_METHOD. Supported methods are: sftp, scp, rsync, local_copy, local_move."
        exit 1
    fi

    # Once delivery command and compression command are constructed, execute them in sequence
    echo "Starting artifact delivery:"
    echo "   → ${delivery_message}"
    "${compression_command[@]}"
    "${delivery_command[@]}" || { echo "Artifact delivery failed!"; exit 1; }
    echo "Artifact delivery completed successfully!"
fi

exit 0