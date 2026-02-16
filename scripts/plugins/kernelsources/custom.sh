#!/bin/bash

# ==============================================================================
#  HARPER FOUNDRY: CUSTOM SOURCE TEMPLATE
# ==============================================================================
# This is a template for users who want to implement custom kernel source
# fetching logic. Copy this file and modify it for your specific needs.
#
# IMPORTANT: This is NOT CALLED by the plugin system. It's a reference template.
# To use custom logic:
#
# 1. Set KERNEL_SOURCE="custom" or "none" in your params file
# 2. The plugin runner will skip automatic fetch
# 3. Implement your own ci-build script with custom fetch logic
# 4. Example:
#
#    #!/bin/bash
#    source /opt/factory/scripts/plugins/kernelsources/runner.sh
#    
#    if [ "$KERNEL_SOURCE" == "custom" ]; then
#        # Your custom logic here
#        git clone https://my-kernel-repo.com/kernel.git $BUILD_ROOT/kernel
#        cd $BUILD_ROOT/kernel
#    elif [ "$KERNEL_SOURCE" == "custom-tarball" ]; then
#        wget https://my-server.com/kernel-custom.tar.xz
#        tar xf kernel-custom.tar.xz
#        cd kernel-custom
#    fi
#    
#    make tinyconfig
#    # ... rest of build ...
#
# ==============================================================================

echo "[INFO] Custom kernel source plugin - implement your own logic!" >&2
echo "[ERROR] This is a template, not a functional plugin" >&2
exit 1
