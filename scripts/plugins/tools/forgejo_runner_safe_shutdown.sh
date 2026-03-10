#!/bin/bash
set -e

_ORIG_ARGS=("$@")
ENV_SETUP_ALLOW_UNKNOWN_ARGS=true
source "$(dirname "$0")/../../env_setup.sh" "${_ORIG_ARGS[@]}"

usage() {
    echo "Usage: $0 [--forgejo-url <url>] [--api-token <token>] [--forgejo-label <label>]"
}

echo "current args:"
ehco "$@""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --api-token)
            if [[ -z "${2:-}" || "$2" == --* ]]; then
                echo "Error: --api-token requires a value."
                usage
                exit 1
            fi
            FORGEJO_API_TOKEN="$2"
            shift 2
            ;;
        --forgejo-url)
            if [[ -z "${2:-}" || "$2" == --* ]]; then
                echo "Error: --forgejo-url requires a value."
                usage
                exit 1
            fi
            FORGEJO_URL="$2"
            shift 2
            ;;
        --forgejo-label)
            if [[ -z "${2:-}" || "$2" == --* ]]; then
                echo "Error: --forgejo-label requires a value."
                usage
                exit 1
            fi
            FORGEJO_RUNNER_LABEL="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Forgejo: Error: Unknown option '$1'."
            usage
            exit 1
            ;;
    esac
done

source "$(dirname "$0")/forgejo_que_clear.sh"
source "$(dirname "$0")/power_off.sh"

echo "Checking if Forgejo queue is empty for runner label '$FORGEJO_RUNNER_LABEL' before shutting down..."
if forgejo_is_que_empty; then
    echo "Forgejo queue is empty; proceeding with shutdown."
    host_shutdown
else
    echo "Forgejo queue for runner label '$FORGEJO_RUNNER_LABEL' is not empty; not shutting down."
fi