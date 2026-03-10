#!/bin/bash
set -e

# nano /etc/polkit-1/rules.d/10-shutdown.rules
# polkit.addRule(function(action, subject) {
#     if ((action.id == "org.freedesktop.login1.power-off" ||
#          action.id == "org.freedesktop.login1.reboot") &&
#         subject.user == "USERNAME") {
#         return polkit.Result.YES;
#     }
# });
# 1. Load the Foundry Environment
# This ensures we have access to all the necessary environment variables and configurations for the Foundry server.
# enviroment variable used:
#   - SHUTDOWN_DELAY_SECONDS - Optional environment variable to specify a delay (in seconds) before the shutdown command is executed. If not set, the shutdown will proceed immediately.

#source "$(dirname "$0")/../../env_setup.sh" "$@"


host_shutdown() {
    shutdown_delay_args="$1"
    actual_shutdown_delay=0
    echo "Initiating system shutdown..."

    if [[ -n "$shutdown_delay_args" ]] && [[ -n "$SHUTDOWN_DELAY_SECONDS" ]]; then
        echo "Argument and environment variable for shutdown delay are both set."
        echo "Using argument value: $shutdown_delay_args seconds."
        actual_shutdown_delay="$shutdown_delay_args"
    elif [[ -n "$shutdown_delay_args" ]]; then
        echo "Using argument value for shutdown delay: $shutdown_delay_args seconds."
        actual_shutdown_delay="$shutdown_delay_args"
    elif [[ -n "$SHUTDOWN_DELAY_SECONDS" ]]; then
        echo "Using environment variable for shutdown delay: $SHUTDOWN_DELAY_SECONDS seconds."
        actual_shutdown_delay="$SHUTDOWN_DELAY_SECONDS"
    else
        echo "No shutdown delay specified. Proceeding with immediate shutdown."
    fi

    if [[ "$actual_shutdown_delay" -gt 0 ]]; then
        echo "Delaying shutdown for $actual_shutdown_delay seconds..."
        sleep "$actual_shutdown_delay"
    fi
    echo "System will power off now."
    systemctl poweroff
}
