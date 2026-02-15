FROM debian:trixie-slim

RUN echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian trixie main" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian trixie-backports main" >> /etc/apt/sources.list

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
    pkg-config \
    curl \
    patch \
    binutils-x86-64-linux-gnu \
    build-essential \
    debhelper \
    debianutils \
    gcc-x86-64-linux-gnu \
    initramfs-tools \
    kmod \
    libc6-dev-amd64-cross \
    libelf-dev \
    libssl-dev \
    libdw-dev \
    crossbuild-essential-amd64 \
    quilt \
    python3-dacite
    
# 3. Install x86_64 Target Libraries (the "Satisfiers")
# These prevent the "cannot find -lelf" and "wrong format" errors
RUN apt-get install -y \
    libelf-dev:amd64 \
    libssl-dev:amd64 \
    libc6-dev:amd64

# 4. Create non-root user for builds
# Accept UID/GID as build arguments to match host user
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd -g ${USER_GID} builder && \
    useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash builder && \
    mkdir -p /build /opt/factory/output /opt/factory/configs /opt/factory/scripts && \
    chown -R builder:builder /build /opt/factory

# 5. Set up a working directory
WORKDIR /build

# 6. Set environment variables to favor the x86_64 toolchain
ENV ARCH=x86_64
ENV CROSS_COMPILE=x86_64-linux-gnu-
ENV KBUILD_BUILD_ARCH=x86_64
ENV DEB_TARGET_ARCH=amd64

# This ensures the container knows how to find the x86_64 libraries
ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig

# 7. Switch to non-root user for all subsequent operations
USER builder