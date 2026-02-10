FROM debian:trixie

# 1. Trixie + Backports
RUN echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian trixie main" >> /etc/apt/sources.list && \
    echo "deb-src http://deb.debian.org/debian trixie-backports main" >> /etc/apt/sources.list

# 2. Hardened Dependency Layer
RUN dpkg --add-architecture amd64 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential crossbuild-essential-amd64 \
    git zip curl file pkg-config ca-certificates python3 python3-pip \
    dpkg-dev flex bison bc rsync kmod cpio fakeroot lsb-release \
    gcc-x86-64-linux-gnu g++-x86-64-linux-gnu binutils-x86-64-linux-gnu \
    clang-19 lld-19 llvm-19 libclang-19-dev \
    libelf-dev:amd64 libssl-dev:amd64 libncurses-dev:amd64 \
    debhelper:amd64 libc6-dev-i386:amd64 libcap-dev:amd64 \
    libdw-dev:amd64 libdw-dev:arm64 \
    libelf-dev:arm64 libssl-dev:arm64 libcap-dev:arm64 \
    libncurses-dev:arm64 \
    ccache qtbase5-dev \
    schedtool wget \
    pahole dwarves zstd lz4 libbpf-dev && \
    apt-get clean

# 3. Toolchain Symlinks (Enhanced)
RUN ln -sf /usr/bin/clang-19 /usr/bin/clang && \
    ln -sf /usr/bin/ld.lld-19 /usr/bin/ld.lld && \
    ln -sf /usr/bin/llvm-ar-19 /usr/bin/llvm-ar && \
    ln -sf /usr/bin/llvm-nm-19 /usr/bin/llvm-nm && \
    ln -sf /usr/bin/llvm-objcopy-19 /usr/bin/llvm-objcopy

# 4. Pro-Level Environment
# FIX: Use PKG_CONFIG_PATH to keep host/target libs separate
ENV ARCH=x86_64 \
    CROSS_COMPILE=x86_64-linux-gnu- \
    LLVM=1 \
    KCFLAGS="-O2 -march=x86-64-v3 -pipe -D_FORTIFY_SOURCE=2" \
    # Ensure host tools link against ARM64 libs, target against x86_64
    HOSTCFLAGS="-I/usr/include/aarch64-linux-gnu" \
    HOSTLDFLAGS="-L/usr/lib/aarch64-linux-gnu -lelf" \
    PKG_CONFIG_PATH_FOR_TARGET=/usr/lib/x86_64-linux-gnu/pkgconfig \
    WINE_NTSYNC=1 \
    SCX_BPF_CPU=v4 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

# 5. Rust Toolchain Setup
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.sh; \
    sh rustup.sh -y --no-modify-path --default-toolchain stable --profile minimal; \
    rm rustup.sh; \
    /usr/local/cargo/bin/rustup target add x86_64-unknown-linux-gnu; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# 6. Buildbot Worker Setup
RUN pip3 install --break-system-packages buildbot-worker twisted

WORKDIR /home/buildbot-worker/storage
COPY scripts/ci-build_full.sh /usr/local/bin/ci-build_full.sh
RUN chmod +x /usr/local/bin/ci-build_full.sh

CMD ["/bin/bash"]