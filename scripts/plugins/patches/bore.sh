#!/bin/bash
# ==============================================================================
#  HARPER FOUNDRY: BORE SCHEDULER PATCH PLUGIN
# ==============================================================================
# Applies the BORE (Burst-Oriented Response Enhancer) scheduler patch
# to the Linux kernel source tree.
#
# USAGE:
#   source /foundry/scripts/plugins/patches/bore.sh
#
# REQUIRES:
#   - BORE_PATCH_URL: URL to the BORE patch file (optional)
#
# EXPORTS:
#   - SCHEDULER_LABEL: "bore" if patch applied, "eevdf" otherwise
#   - SCHED_PRIORITY: "2" for BORE, "1" for EEVDF (for versioning)
#
# BEHAVIOR:
#   - Downloads and applies BORE patch if BORE_PATCH_URL is set
#   - Falls back to EEVDF scheduler if patch fails or URL not provided
#   - Must be run from kernel source root directory
# ==============================================================================

apply_bore_patch() {
    echo "💉 Checking for scheduler patches..."
    
    # Default to EEVDF scheduler
    export SCHEDULER_LABEL="eevdf"
    export SCHED_PRIORITY="1"
    
    # Apply BORE patch if URL provided
    if [ -n "$BORE_PATCH_URL" ]; then
        echo "📥 Downloading BORE patch from: $BORE_PATCH_URL"
        
        if curl -fLo bore.patch "$BORE_PATCH_URL"; then
            echo "🔧 Applying BORE scheduler patch..."
            
            if patch -p1 -F3 < bore.patch; then
                echo "✅ BORE patch applied successfully!"
                export SCHEDULER_LABEL="bore"
                export SCHED_PRIORITY="2"
            else
                echo "⚠️  BORE patch failed to apply."
                echo "⚠️  Falling back to default EEVDF scheduler."
            fi
        else
            echo "⚠️  Failed to download BORE patch."
            echo "⚠️  Falling back to default EEVDF scheduler."
        fi
    else
        echo "ℹ️  No BORE_PATCH_URL specified - using default EEVDF scheduler."
    fi
    
    echo "📊 Scheduler: $SCHEDULER_LABEL (priority: $SCHED_PRIORITY)"
}

# Run the patch application if script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    apply_bore_patch
fi
