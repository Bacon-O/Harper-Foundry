#!/bin/bash
set -e

readonly PKG_NAME="scx-scheds-harper"
readonly CONTAINER_BUILD_ROOT="/build"
readonly CONTAINER_OUTPUT_DIR="/opt/factory/output"
readonly SCX_PKG_DEB_DIR="/opt/factory/scripts/plugins/patches/scx-pkg"
readonly SCX_SCHEDS_HARPER_SUB_VERSION="harper1"

# Always restore ownership back to the host user, even on failures.
RESTORE_UID=""
RESTORE_GID=""
BUILD_DEB_DIR=""
DEB_FILE=""

restore_artifact_ownership() {
    if [[ -n "$BUILD_DEB_DIR" && -e "$BUILD_DEB_DIR" && -n "$RESTORE_UID" && -n "$RESTORE_GID" ]]; then
        sudo chown -R "$RESTORE_UID:$RESTORE_GID" "$BUILD_DEB_DIR" || true
    fi

    if [[ -n "$DEB_FILE" && -e "$CONTAINER_OUTPUT_DIR/$(basename "$DEB_FILE")" && -n "$RESTORE_UID" && -n "$RESTORE_GID" ]]; then
        sudo chown "$RESTORE_UID:$RESTORE_GID" "$CONTAINER_OUTPUT_DIR/$(basename "$DEB_FILE")" || true
    fi
}

trap restore_artifact_ownership EXIT

# 1️⃣ Load Environment
if [[ -f "/opt/factory/scripts/env_setup.sh" ]]; then
    source /opt/factory/scripts/env_setup.sh "$@"
else
    echo "⚠️  env_setup.sh not found. Using defaults."
    TARGET_ARCH="x86-64"
    SOFTWARE_SOURCE="sched-ext/scx"
    SOFTWARE_VERSION="latest"
    HOST_UID="$(id -u)"
    HOST_GID="$(id -g)"
    FINAL_JOBS=$(nproc)
fi

RESTORE_UID="${HOST_UID:-$(id -u)}"
RESTORE_GID="${HOST_GID:-$(id -g)}"

echo "🚀 Starting Harper Foundry Smelt..."

# 2️⃣ Prepare Source
mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching sched-ext source via plugin: SOFTWARE_SOURCE=${SOFTWARE_SOURCE:-sched-ext/scx}" 
source "${PLUGIN_DIR}/source_fetcher/runner.sh"
SCX_DIR=$(fetch_software_source "${SOFTWARE_SOURCE:-sched-ext/scx}" "${SOFTWARE_VERSION:-latest}" "$CONTAINER_BUILD_ROOT")
if [[ -z "$SCX_DIR" ]] || [[ ! -d "$SCX_DIR" ]]; then
    echo "❌ ERROR: Failed to fetch sched-ext/scx source"
    exit 1
fi

SCX_DIR_NAME="$(basename "$SCX_DIR")"
cd "$SCX_DIR"

# 3️⃣ Build Binaries
echo "🛠 Building $PKG_NAME with mold and $TARGET_ARCH optimizations..."
# We use mold for speed and target-cpu for performance
RUSTFLAGS="-C link-arg=-fuse-ld=mold -C target-cpu=$TARGET_ARCH" cargo build \
    --release \
    --jobs "$FINAL_JOBS"

# 4️⃣ Debian Packaging Step
echo "📦 Preparing Debian package..."

# ignore the build scx package from git operations
#echo "scx-package-workspace/" >> .git/info/exclude

# Identify Versions
NEW_TAG=$(git describe --tags --abbrev=0)
OLD_TAG=$(git describe --tags --abbrev=0 "${NEW_TAG}^" 2>/dev/null || echo "")
DEB_VERSION=$(echo "$NEW_TAG" | sed 's/^v//')

# Handle Dirty State
if [ -n "$(git status --porcelain)" ]; then
    DEB_VERSION="${DEB_VERSION}+dirty"
fi

FULL_VERSION="$DEB_VERSION-$SCX_SCHEDS_HARPER_SUB_VERSION"

# 5️⃣ Generate Changelog
if [ -z "$OLD_TAG" ]; then
    LOG_CHANGES=$(git log --pretty=format:"    * %s")
else
    LOG_CHANGES=$(git log "${OLD_TAG}..${NEW_TAG}" --pretty=format:"    * %s")
fi


# We leave the scx git dir one level to build deb pacakge
cd ..

# Create a fresh workspace for the debian files
BUILD_DEB_DIR="./scx-package-workspace"
cp -r "$SCX_PKG_DEB_DIR" "$BUILD_DEB_DIR"

echo "✅ Version set to: $FULL_VERSION"
# Update Control File
sed -i "s/^Version:.*/Version: $FULL_VERSION/" "$BUILD_DEB_DIR/DEBIAN/control"

echo "📝 Generating automated changelog..."
DOC_DIR="$BUILD_DEB_DIR/usr/share/doc/$PKG_NAME"
mkdir -p "$DOC_DIR"
DATE_STR=$(date -R)

cat <<EOF > "$DOC_DIR/changelog"
${PKG_NAME} (${FULL_VERSION}) unstable; urgency=low

${LOG_CHANGES}

 -- Bacon-O <128566458+Bacon-O@users.noreply.github.com>  ${DATE_STR}
EOF

gzip -9n "$DOC_DIR/changelog"
chmod 644 "$DOC_DIR/changelog.gz"
mv "$DOC_DIR/changelog.gz" \
   "$DOC_DIR/changelog.Debian.gz"

# 6️⃣ Final Assembly
echo "🏗 Finalizing .deb assembly..."
mkdir -p "$BUILD_DEB_DIR/usr/bin"
find "$SCX_DIR_NAME/target/release/" -maxdepth 1 -type f -name "scx_*" -executable -exec cp {} "$BUILD_DEB_DIR/usr/bin/" \;

echo "🧹 Polishing binaries and metadata..."
# 1. Strip binaries to save massive amounts of space
strip --strip-unneeded "$BUILD_DEB_DIR/usr/bin/scx_"*

# Build the .deb
# Using sudo because dpkg-deb requires root-like ownership (root:root) for the final archive
DEB_FILE="${PKG_NAME}_${FULL_VERSION}_amd64.deb"
sudo chown -R root:root "$BUILD_DEB_DIR"

dpkg-deb --build "$BUILD_DEB_DIR" "$DEB_FILE"

echo "✨ Smelt Complete: $DEB_FILE"

echo "Move the .deb file to the output directory for export..."
mkdir -p "$CONTAINER_OUTPUT_DIR"
mv "$DEB_FILE" "$CONTAINER_OUTPUT_DIR/"

ls -lh "${CONTAINER_OUTPUT_DIR}/$(basename "$DEB_FILE")"