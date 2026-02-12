FROM debian:trixie-slim

# 1. Enable Multiarch so we can install amd64 libraries on an arm64 host
RUN dpkg --add-architecture amd64

# 2. Install native ARM64 tools (the "Engine")
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    llvm \
    lld \
    git \
    flex \
    bison \
    bc \
    kmod \
    cpio \
    rsync \
    lsb-release \
    debhelper \
    python3 \
    pkg-config

# 3. Install x86_64 Target Libraries (the "Satisfiers")
# These prevent the "cannot find -lelf" and "wrong format" errors
RUN apt-get install -y \
    libelf-dev:amd64 \
    libssl-dev:amd64 \
    libc6-dev:amd64

# 4. Set up a working directory
WORKDIR /build

# 5. Set environment variables to favor the x86_64 toolchain
ENV ARCH=x86_64
ENV CROSS_COMPILE=x86_64-linux-gnu-
ENV KBUILD_BUILD_ARCH=x86_64
ENV DEB_TARGET_ARCH=amd64

# This ensures the container knows how to find the x86_64 libraries
ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig