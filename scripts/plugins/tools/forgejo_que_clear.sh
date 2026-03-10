#!/bin/bash
set -e

source "$(dirname "$0")/../../env_setup.sh" "$@"

# This script checks the Forgejo queue for a specific runner label.
# Predicate functions follow shell conventions: return 0 when true.
_forgejo_api_is_que_empty() {
    response=$(curl -s -H "Authorization: token $FORGEJO_API_TOKEN" "$FORGEJO_URL/api/v1/queue?label=$FORGEJO_RUNNER_LABEL")
    queue_length=$(echo "$response" | jq '.total')

    if [[ "$queue_length" -eq 0 ]]; then
        echo "No items in the Forgejo queue for label '$FORGEJO_RUNNER_LABEL'."
        return 0
    else
        echo "There are $queue_length items in the Forgejo queue for label '$FORGEJO_RUNNER_LABEL'."
        return 1
    fi
}

# Check multiple times to ensure queue remains empty before continuing.
forgejo_is_que_empty() {

    if ! command -v jq &> /dev/null; then
        echo "jq is required but not installed. Please install jq to use this function."
        return 1
    fi

    if [[ -z "$FORGEJO_URL" ]]; then
        echo "FORGEJO_URL environment variable is not set. Please set it to the URL of your Forgejo instance."
        return 1
    fi

    if [[ -z "$FORGEJO_API_TOKEN" ]]; then
        echo "FORGEJO_API_TOKEN environment variable is not set. Please set it to a valid API token for your Forgejo instance."
        return 1
    fi

    if [[ -z "$FORGEJO_RUNNER_LABEL" ]]; then
        echo "FORGEJO_RUNNER_LABEL environment variable is not set. Please set it to the label of the runner you want to check the queue for."
        return 1
    fi

    for i in $(seq 1 "$FORGEJO_QUEUE_CHECK_RETRIES"); do
        echo "Checking Forgejo queue for label '$FORGEJO_RUNNER_LABEL' (Attempt $i of $FORGEJO_QUEUE_CHECK_RETRIES)..."
        if _forgejo_api_is_que_empty; then
            echo "Waiting for $FORGEJO_QUEUE_CHECK_INTERVAL_SECONDS seconds before rechecking the Forgejo queue..."
            sleep "$FORGEJO_QUEUE_CHECK_INTERVAL_SECONDS"
        else
            echo "Forgejo runner $FORGEJO_RUNNER_LABEL queue is not empty."
            return 1
        fi
    done

    echo "Forgejo queue is clear after $FORGEJO_QUEUE_CHECK_RETRIES attempts."
    return 0
}   
