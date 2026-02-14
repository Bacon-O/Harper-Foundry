#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to CHECK_LIST, WARN_LIST, and HOST_OUTPUT_DIR
source "$(dirname "$0")/env_setup.sh" "$@"
#!/usr/bin/env bash

# --- Visual Foundry Utilities ---
log_info()  { echo -e "\e[32m[INFO]\e[0m  $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

handle_failure() {
    local test_name=$1
    if [[ "$QA_MODE" == "HARD" ]]; then
        log_error "QA FAILURE: [$test_name]. Aborting (QA_MODE=HARD)."
        exit 1
    else
        log_warn "QA WARNING: [$test_name] failed. Continuing (QA_MODE=SOFT)."
    fi
}

# --- Phase 1: Function-Level Plugins ---
log_info "Phase 1: Executing Host-Native QA Plugins..."
for test_script in "${QA_TESTS[@]}"; do
    full_path="${TEST_FUNCTIONS_DIR}/${test_script}"
    
    if [[ -x "$full_path" ]]; then
        log_info "Running plugin: $test_script"
        if ! "$full_path"; then
            handle_failure "$test_script"
        fi
    else
        log_warn "Plugin missing or not executable: $full_path"
    fi
done

---

# --- Phase 2: Package-Level Bundles ---
log_info "Phase 2: Executing Host-Native Package Suites..."
for package in "${QA_TEST_PACKAGE[@]}"; do
    pkg_path="${TEST_PACKAGE_DIR}/${package}"
    
    if [[ -d "$pkg_path" ]]; then
        log_info "Opening QA Bundle: $package"
        # Logic: Discover and execute all executable scripts within the folder
        for subtest in "$pkg_path"/*; do
            if [[ -x "$subtest" ]]; then
                test_name=$(basename "$subtest")
                log_info "  -> Executing: $test_name"
                if ! "$subtest"; then
                    handle_failure "$package/$test_name"
                fi
            fi
        done
    else
        log_warn "QA Package directory not found: $pkg_path"
    fi
done

log_info "Material Analysis Complete. All host-side checks finished."