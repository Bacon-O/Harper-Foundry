#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to QA_CRITICAL_CHECKS, QA_OPTIONAL_CHECKS, and HOST_OUTPUT_DIR
source "$(dirname "$0")/env_setup.sh" "$@"

# --- Visual Foundry Utilities ---
log_info()  { echo -e "\e[32m[INFO]\e[0m  $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

handle_failure() {
    local test_name=$1
    if [[ "$QA_MODE" == "ENFORCED" ]]; then
        log_error "QA FAILURE: [$test_name]. Aborting (QA_MODE=ENFORCED)."
        exit 1
    else
        log_warn "QA WARNING: [$test_name] failed. Continuing (QA_MODE=RELAXED)."
    fi
}

# --- Phase 1: Function-Level Plugins ---
log_info "Phase 1: Executing Host-Native QA Plugins..."
for test_script in "${QA_TESTS[@]}"; do
    # Check custom tests first (plugins.d/qatests/)
    # Go up two levels from tests/ to plugins/ then down to plugins.d/qatests/
    custom_test="${TEST_FUNCTIONS_DIR}/../../plugins.d/qatests/${test_script}"
    if [[ -x "$custom_test" ]]; then
        full_path="$custom_test"
        log_info "Running custom plugin: $test_script"
    else
        # Fall back to project tests
        full_path="${TEST_FUNCTIONS_DIR}/${test_script}"
        if [[ -x "$full_path" ]]; then
            log_info "Running plugin: $test_script"
        else
            log_warn "Plugin missing or not executable: $full_path"
            continue
        fi
    fi
    
    if ! "$full_path" "$@"; then
        handle_failure "$test_script"
    fi
done

# --- Phase 2: Package-Level Bundles ---
log_info "Phase 2: Executing Host-Native Package Suites..."
for package in "${QA_TEST_PACKAGE[@]}"; do
    # Check custom packages first (plugins.d/qatests/)
    # Go up two levels from tests/ to plugins/ then down to plugins.d/qatests/
    custom_list="${TEST_FUNCTIONS_DIR}/../../plugins.d/qatests/${package}.lst"
    if [[ -f "$custom_list" ]]; then
        list_file="$custom_list"
        log_info "Opening custom QA Bundle: $package"
    else
        # Fall back to project packages
        list_file="${TEST_PACKAGE_DIR}/${package}.lst"
        if [[ ! -f "$list_file" ]]; then
            log_warn "QA Package list not found: $list_file"
            continue
        fi
        log_info "Opening QA Bundle: $package"
    fi
    
    # Read tests from .lst file and execute each one
    while IFS= read -r test_name; do
        # Skip empty lines and comments
        [[ -z "$test_name" || "$test_name" == \#* ]] && continue
        
        test_path="${TEST_FUNCTIONS_DIR}/${test_name}"
        if [[ -x "$test_path" ]]; then
            log_info "  -> Executing: $test_name"
            if ! "$test_path" "$@"; then
                handle_failure "$package/$test_name"
            fi
        else
            log_warn "Test not found or not executable: $test_path"
        fi
    done < "$list_file"
done

log_info "Material Analysis Complete. All host-side checks finished."