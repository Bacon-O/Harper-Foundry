#!/bin/bash
set -e

# ==============================================================================
#  HARPER FOUNDRY: SCHED-EXT/SCX SOURCE FETCHER
# ==============================================================================
# Fetches sched-ext/scx from GitHub using release tags.
#
# Version behavior:
#   - "" / "latest" / "stable" / "lts": latest GitHub release tag
#   - "rc": falls back to latest release tag unless the repo starts
#           publishing a separate RC tag stream
#   - Specific version: exact tag, or the same version prefixed with "v"
# ==============================================================================

readonly SCX_REPO_URL="https://github.com/sched-ext/scx.git"
readonly SCX_RELEASES_API_URL="https://api.github.com/repos/sched-ext/scx/releases/latest"

list_remote_tags() {
    git ls-remote --tags --refs "$SCX_REPO_URL" 2>/dev/null \
        | awk '{sub("refs/tags/", "", $2); print $2}'
}

resolve_latest_release_tag() {
    local latest_tag

    echo "[INFO] Querying GitHub for latest sched-ext/scx release tag..." >&2
    latest_tag=$(curl -fsSL "$SCX_RELEASES_API_URL" 2>/dev/null \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
        | head -n1)

    if [[ -n "$latest_tag" ]]; then
        echo "[INFO] Latest sched-ext/scx release tag: $latest_tag" >&2
        echo "$latest_tag"
        return 0
    fi

    echo "[WARN] GitHub release API lookup failed, falling back to remote tag discovery" >&2
    latest_tag=$(list_remote_tags | sort -V | tail -n1)

    if [[ -z "$latest_tag" ]]; then
        echo "[ERROR] Unable to determine latest sched-ext/scx tag" >&2
        return 1
    fi

    echo "[INFO] Latest sched-ext/scx tag from git: $latest_tag" >&2
    echo "$latest_tag"
}

resolve_requested_tag() {
    local version_spec="${1:-latest}"
    local candidate

    case "$version_spec" in
        ""|latest|stable|lts)
            resolve_latest_release_tag
            return 0
            ;;
        rc)
            echo "[WARN] sched-ext/scx does not expose a dedicated rc channel here; using the latest release tag" >&2
            resolve_latest_release_tag
            return 0
            ;;
    esac

    for candidate in "$version_spec" "v$version_spec"; do
        if list_remote_tags | grep -Fxq "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    echo "[ERROR] Requested sched-ext/scx version not found: $version_spec" >&2
    return 1
}

SOFTWARE_VERSION=$(resolve_requested_tag "${1:-}")
BUILD_ROOT="${2:-.}"
CHECKOUT_DIR="$BUILD_ROOT/scx-${SOFTWARE_VERSION#v}"

mkdir -p "$BUILD_ROOT"

if [[ ! -d "$CHECKOUT_DIR/.git" ]]; then
    echo "[INFO] Cloning sched-ext/scx repository into $CHECKOUT_DIR" >&2
    git clone --quiet "$SCX_REPO_URL" "$CHECKOUT_DIR"
else
    echo "[INFO] Reusing existing sched-ext/scx checkout at $CHECKOUT_DIR" >&2
fi

cd "$CHECKOUT_DIR"
git fetch --quiet --tags origin
git checkout --quiet "tags/$SOFTWARE_VERSION"

echo "[INFO] sched-ext/scx source ready: $CHECKOUT_DIR" >&2
echo "$CHECKOUT_DIR"