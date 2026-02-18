# Harper Foundry

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](.github/workflows/kernel-factory.yml)

The **Harper Foundry** is an extensible containerized build system. While currently configured for custom Debian Linux kernels, tuning profiles, and automated QA, the foundry architecture can be extended to compile other programs. *(Note: Currently, only kernel build templates are available.)*

## ⚠️ Early Stage Software

**This project is still in early/enthusiast stage.** I have validated the logic for my specific use cae, but it has not been tested against a wide range of hardware,confirations or edge cases. Expect bugs, and use it at your own risk.

**Known Limitations:**
- Limited testing on platforms beyond x86_64/arm64 with Debian 13
- Not recommended for production systems or mission-critical workloads
- Expect rough edges, bugs, and breaking changes as the project evolves
- The Harper kernel itself is experimental—use Debian's official kernels for stability
- Update functionality is not yet implemented. See [Updates](#updates) for the current approach


## Motivation

### The Backstory

This project started as a hands-on way to get exposure to CI/CD pipelines. After switching from Windows to Debian, I fell down the rabbit hole of Linux kernel tuning. While I loved the concept of projects like [linux-tkg](https://github.com/Frogging-Family/linux-tkg), I wanted something automated and tailored for me.

### The Name

I name all my home servers generic names. The build server for this project is named "Harper." During an early POC compile, the name got attached to the kernel; it had a nice ring to it, so it stuck. Harper Foundry was born: an automated forge that cross-compiles a tuned, amd64v3 Debian kernel from within a containerized environment.

### Was it worth the effort?

Honestly? From a pure performance standpoint, probably not. Debian—and most major distributions—already ship incredibly stable, highly compatible, and well-patched kernels that are more than sufficient for 99% of use cases. If you are looking for a massive speed boost, you won't find a "magic pill" here. Seriously, that kernel that shipped with your distro is awesome.

However, from a "Builder's" or "Tinker's" standpoint? Absolutely. The value of Harper Foundry isn't just the resulting .deb file; it was the journey of fighting Debian packaging, mastering containerized cross-compilation, kernel building, and orchestrating a complex CI/CD pipeline. It's about having a "forge" that you own, end-to-end.

### Who is this for?

- **Kernel Hobbyists:** Those looking to build and tune their own kernels
- **Learners:** Anyone exploring CI/CD fundamentals and containerization
- **Developers:** Those who want a clean base to fork and tailor to their own needs

### Technical Stack (The Forge)

To help others find the right tools, here is the machinery under the hood:

- **CI/CD Orchestration:** GitHub Actions for fully automated builds
- **Containerization:** Docker for a reproducible, isolated build environment
- **Kernel Configuration:** Custom Kconfig configurations (x86-64-v3) for modern CPU architectures
- **Toolchain:** Debian Build-Essential & LLVM/Clang for cross-compiling
- **Packaging:** Native .deb generation for easy installation on Debian-based systems

### Public Reference Repo

Right now, this public repo is just my clean "reference" setup, so the CI/CD actions are set to run manually. If you want to fire up the furnace and actually automate your own kernel builds, I highly recommend forking this project and setting up your own pipeline triggers.

That keeps my commit history clean and puts you entirely in the driver's seat for your own build schedule. I’ve provided the templates and tools for development—everything from a clean shell/CLI compile environment to cron jobs and GitHub Actions. I am open to suggestions for improvements; there is still more on my to do list, but I think this is a good starting point to make this repo public.

## ✨ Features

*   **🐳 Containerized Build:** Isolated, reproducible builds using Docker
*   **🔀 Cross-Compilation:** Automatic architecture detection and toolchain configuration (e.g., building x86_64 on ARM64)
*   **🛡️ Automated QA:** Extensible quality assurance framework validates configuration and binaries
*   **🚀 CI/CD Ready:** GitHub Actions integration for automated builds
*   **🎛️ Highly Configurable:** Fine-grained control via parameter files

### Tested Platforms

Currently, the Harper Foundry has been tested and verified on:
- **x86_64** (Native and cross-compilation target)
- **arm64** (Native and cross-compilation host)
- **Debian 13 (Trixie)** as the build environment

Other Linux distributions should work, but **no testing has been performed**. If you encounter issues on other distros, contributions and bug reports are welcome.

### Prerequisites
*   **Docker** (20.10+)
*   **Bash** (4.0+)
*   **Disk Space:** 20GB+ free for build artifacts
*   **ARM64 hosts (cross-compile):** `qemu-x86_64-static` (see [docs/QEMU_USER_EMULATION.md](docs/QEMU_USER_EMULATION.md))

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Bacon-O/Harper-Foundry.git
   cd Harper-Foundry
   ```

2. **Run interactive setup:**
   ```bash
   ./install.sh
   ```
   This will guide you through configuring paths and build options.

3. **Validate configuration:**
   ```bash
   ./scripts/validate_params.sh
   ```

4. **Start your first build:**
   ```bash
   ./start_build.sh
   ```

   Or use the Makefile:
   ```bash
   make build
   ```

Build artifacts will be stored in your configured `HOST_OUTPUT_DIR`.

## 📖 Documentation

- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to the project
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
- **[Configuration Reference](#configuration)** - Detailed parameter documentation
- **[QEMU User Emulation](docs/QEMU_USER_EMULATION.md)** - Why `qemu-x86_64-static` is required on ARM64 hosts

## 📂 Project Structure

*   `start_build.sh`: The main entry point for local builds.
*   `params/`: Configuration files (e.g., `foundry.params`, `tinyconfig.params`).
*   `scripts/`: Build scripts.
    *   `env_setup.sh`: Argument parsing and environment setup.
    *   `furnace_ignite.sh`: Docker container launch logic.
    *   `compile_scripts/`: Build script variants (full, tinyconfig, etc.).
    *   `material_analysis.sh`: Post-build Quality Assurance.
*   `configs/`: Kernel configuration fragments (base configs and tuning overlays).
*   `docker/`: Dockerfiles defining the build environment.

## 🛠️ Configuration

The build is configured via files in the `params/` directory. The default is `params/foundry.params`.

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `BUILD_WORKSPACE_DIR` | Build workspace on host, mounted as /build | `/path/to/build/workspace` |
| `HOST_OUTPUT_DIR` | Where build artifacts are stored | `/path/to/output/dir` |
| `USE_PARAM_SCOPED_DIRS` | Scope default paths per params name | `true` |
| `TARGET_ARCH` | Target CPU architecture | `x86_64`, `aarch64` |
| `KERNEL_SOURCE` | Kernel source plugin to use | `kernel.org`, `debian`, `debian/trixie-backports` |
| `KERNEL_VERSION` | Kernel version or alias | `"latest"`, `"lts"`, `"6.11.8"`, empty for default |
| `BASE_CONFIG` | Base kernel config | `defconfig`, `tinyconfig` |
| `TUNING_CONFIG` | Additional config overlay | `harper_deb13_tune.config` |
| `BYPASS_QA` | Skip quality assurance | `true`, `false` |
| `QA_MODE` | QA strictness | `RELAXED`, `ENFORCED` |

Additional custom variables can be added to your params files and will be exported to the environment. For advanced environment customization (adding custom environment extensions), see [Environment Extensions](scripts/plugins/env_extensions/README.md).
### Validation

Always validate your configuration before building:

```bash
./scripts/validate_params.sh params/foundry.params
```

## 💻 Usage

### Quick Start
To start a build using the default configuration:

```bash
./start_build.sh
```

### Command Line Arguments
The foundry accepts several arguments to control the process:

| Flag | Long Option | Description |
| :--- | :--- | :--- |
| `-p` | `--params-file <path>` | Specify a params file (default: `params/foundry.params`). |
| `-t` | `--test-run` | Enable test mode (uses `tinyconfig`, disables QEMU, ignores non-critical QA). |
| `-r` | `--rebuild` | Force a rebuild of the Docker builder image. |
| `-b` | `--bypass-qa` | Skip the Material Analysis (QA) stage. |
| `-i` | `--incremental` | Skip `make mrproper` for faster rebuilds. |
| `-e` | `--exec <script>` | Override the script executed inside the container. |
| `-h` | `--help` | Display help menu. |

### Makefile Shortcuts

For convenience, common tasks are available via `make`:

```bash
make help        # Show all available targets
make setup       # Run interactive setup
make check       # Check system prerequisites  
make validate    # Validate configuration
make build       # Run full build
make test        # Run fast test build
make status      # Show build artifacts
make clean       # Clean old builds
make deep-clean  # Remove all artifacts
```

### Examples

**Run a fast test build (tinyconfig):**
```bash
./start_build.sh --params-file params/tinyconfig.params
# Or simply:
make test
```

**Build using a specific params file:**
```bash
./start_build.sh --params-file params/experimental.params
```

**Create and use a custom params file (avoiding git conflicts):**
```bash
# Copy a template to params/params.d/ for your customizations
cp params/harper_deb13.params params/params.d/my_custom_build.params
# Edit params/params.d/my_custom_build.params as needed
./start_build.sh --params-file params/params.d/my_custom_build.params

# Your custom configs stay safe - git pull won't conflict them
git pull  # Safe!
```

See [params/README.md](params/README.md#user-customizations-paramsd) for detailed customization patterns.

**Apply override params on top of base config:**
```bash
# Use -o flag for base + override pattern
./start_build.sh -p params/harper_deb13.params -o params/_test_overrides.params

# Or use PRODUCTION_CONFIG environment variable
PRODUCTION_CONFIG=harper_deb13.params ./start_build.sh -p params/_test_overrides.params
```

See [params/README.md](params/README.md#configuration-override-patterns) for detailed override documentation.

**Use a specific build mixture:**
```bash
./start_build.sh --exec compile_scripts/tinyconfig.sh
```

**Force rebuild of Docker image:**
```bash
./start_build.sh --rebuild
```

## 🧪 Build Mixtures (Alloy Configurations)

The foundry supports different "alloy mixtures" - build configurations optimized for different purposes:

### Available Mixtures

| Mixture | Build Time | Purpose | Artifacts |
|---------|------------|---------|-----------|
| **harper_deb13.sh** | 30-60+ min | Enthusiast/hobbyist builds ⚠️ | Full .deb packages, optimized for desktop/gaming (compiled with CLANG/LLVM) |
| **tinyconfig.sh** | 2-5 min | Quick testing | bzImage only |

See [scripts/compile_scripts/README.md](scripts/compile_scripts/README.md) for detailed information.

### Quick Test vs Full Build

**Tinyconfig Quick Test:**
- ⚡ 2-5 minute builds
- 🎯 Validates foundry pipeline
- 📦 Minimal artifacts (bzImage only)
- ✅ Perfect for testing changes

**Harper deb13 (Full Build):**
- Based on Debian 13 Trixie Backports
- 🏗️ 30-60+ minute builds
- 🎯 Complete Harper kernel for enthusiasts
- 📦 Complete .deb packages
- 🔨 Compiled with CLANG/LLVM for modern optimizations
- 🚀 Optimized for desktop/gaming workloads:
  - x86-64-v3 CPU baseline (AVX2, FMA, BMI2)
  - Linux default scheduler (EEVDF)
  - 1000Hz timer frequency (vs Debian's 250Hz)
  - Full preemption for lower latency
  - Intel/AMD P-State frequency scaling
  - ZSTD kernel compression
- No kernel singing implemented
- ⚠️ Experimental - use at your own risk

### Cleanup

The project includes cleanup utilities for managing disk space.

#### Routine Cleanup
To remove older build artifacts while keeping the most recent ones (default: 3):

```bash
./scripts/furnace_clean.sh
```

#### Deep Cleanup (Scrub)
To remove all build artifacts from the distribution directory and prune the Docker builder cache, use the `--deep` or `--scrub` flag. This is useful for reclaiming significant disk space.

```bash
./scripts/furnace_clean.sh --deep
```

## 🏭 CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/kernel-factory.yml`) provides automated builds:

*   **Manual Dispatch:** Dual dropdown select base config + optional testing overrides
*   **Manual Dispatch:** Run builds on-demand with custom configurations

⚠️ **Note:** All Harper builds are experimental. This is a hobbyist/enthusiast project.

### Workflow Stages

1. **Preheat** - Validate configuration and prerequisites
2. **Smelt** - Execute containerized kernel build
3. **Analysis** - Run QA tests on build artifacts
4. **Cleanup** - Remove old builds and free disk space

## 🔔 Automated Trigger Jobs

Harper includes a trigger job system (plugin-based) that monitors Debian Trixie Backports for new kernel releases and automatically builds when available.

**Features:**
- 📡 Monitors Debian Salsa API for upstream updates
- 🎯 Version tracking to avoid duplicate builds
- ⚙️ Runs on configurable schedule (default: every 6 hours)
- 🔧 Extensible plugin system for custom triggers

**Quick Start:**
```bash
# Manual trigger check (via plugin system)
source ./scripts/plugins/triggers/runner.sh
trigger_build harper_deb13_kernel

# Force build regardless of version
trigger_build harper_deb13_kernel --force
```

For full documentation, see [Trigger Jobs Guide](docs/TRIGGER_JOBS.md).

## 🧪 Quality Assurance

The Foundry includes an extensible QA framework with modular test plugins:

### Plugin System

All QA tests are organized under `scripts/plugins/qatests/`:

```
qatests/
├── tests/          # Individual QA test scripts
│   ├── debpackage.sh
│   ├── filesexists.sh
│   ├── linuxconfig.sh
│   └── qemuboot.sh
└── packages/       # Test package definition files (.lst)
    ├── harper.lst
    └── minimal.lst
```

### Individual Tests

Located in `scripts/plugins/qatests/tests/`:
- `filesexists.sh` - Verifies required files are present
- `linuxconfig.sh` - Validates kernel configuration
- `debpackage.sh` - Checks Debian package integrity
- `qemuboot.sh` - Tests kernel bootability (optional)

### Test Packages

Test package definitions in `scripts/plugins/qatests/packages/` (.lst files):
- `harper.lst` - Full validation suite (all 4 tests)
- `minimal.lst` - Minimal suite (quick validation)

For more details, see [QA Tests Documentation](scripts/plugins/qatests/README.md).

### Configuration

```bash
# In params/foundry.params

# Individual tests
QA_TESTS=(
    "filesexists.sh"
    "linuxconfig.sh"
)

# Test packages
QA_TEST_PACKAGE=(
    "harper"
)

# QA behavior
QA_MODE="RELAXED"       # RELAXED = warn, ENFORCED = fail build
BYPASS_QA="false"       # Set true to skip QA entirely
```

### Updates

⚠️ **No built-in update manager exists.** Harper Foundry relies on **git pull** for updates:

```bash
# Update to latest changes
git pull
```

**I acknowledge git is not an update manager**, but this is still early/stage beta software. If you keep all your custom configurations in **`.d/` directories** (gitignored), `git pull` is safe:

```bash
# Your customizations are protected
params/params.d/           # Your custom params (gitignored ✅)
scripts/scripts.d/       # Your custom scripts (gitignored ✅)

# Safe to update
git pull  # Your custom files untouched
```

**Best Practice:** Keep all your custom configurations in `.d/` directories. That way, you can update fearlessly with `git pull` without losing your changes.

If you hit issues, bugs, or have suggestions, please open an issue. This feedback helps improve the project.



## 🔧 Advanced Usage

### Plugin System

Harper Foundry uses a modular, extensible plugin architecture. All plugins follow the Unix **`.d/` pattern** for custom user implementations:

**Directory Structure:**
```
scripts/
├── compile_scripts/            ← Official build script variants
│   └── (harper_deb13.sh, tinyconfig.sh)
├── plugins/                    ← Official plugin types
│   ├── kernelsources/
│   ├── notifiers/
│   ├── patches/
│   ├── qatests/
│   ├── tools/
│   ├── triggers/
│   └── env_extensions/
└── scripts.d/                  ← Your custom scripts (gitignored)
    ├── compile_scripts/        ← Your custom build variants
    └── plugins/                ← Your custom plugins (same structure as official)
        ├── kernelsources/
        ├── notifiers/
        ├── patches/
        ├── qatests/
        ├── tools/
        ├── triggers/
        └── env_extensions/
```

**How It Works:**
- Smart lookup: Checks `scripts/scripts.d/` (your custom implementations) first
- Falls back to official versions in `scripts/plugins/` if custom not found
- **All custom implementations are gitignored** - safe to pull updates without conflicts
- Use the same interface as official plugins

**Available Plugin Types:**

| Plugin | Purpose | Custom Location | Documentation |
|--------|---------|-----------------|----------------|
| **compile_scripts** | Build variants (full, tinyconfig, etc.) | `scripts/scripts.d/compile_scripts/` | [Compile Scripts](scripts/compile_scripts/README.md) |
| **kernelsources** | Fetch kernel from different sources | `scripts/scripts.d/plugins/kernelsources/` | [Kernel Sources](scripts/plugins/kernelsources/README.md) |
| **notifiers** | Integration with monitoring/alerting systems | `scripts/scripts.d/plugins/notifiers/` | [Notifiers](scripts/plugins/notifiers/README.md) |
| **patches** | Apply custom kernel patches | `scripts/scripts.d/plugins/patches/` | [Patches](scripts/plugins/patches/README.md) |
| **qatests** | Add quality assurance tests | `scripts/scripts.d/plugins/qatests/` | [QA Tests](scripts/plugins/qatests/README.md) |
| **tools** | Utility scripts and helpers | `scripts/scripts.d/plugins/tools/` | [Tools](scripts/plugins/tools/README.md) |
| **triggers** | Scheduling and automation | `scripts/scripts.d/plugins/triggers/` | [Triggers](scripts/plugins/triggers/README.md) |
| **env_extensions** | Customize build environment variables | `scripts/scripts.d/plugins/env_extensions/` | [Environment Extensions](scripts/plugins/env_extensions/README.md) |

**Quick Example - Custom Compile Script:**
```bash
# Create your custom build variant
cat > scripts/scripts.d/compile_scripts/minimal.sh << 'EOF'
#!/bin/bash
# My minimal embedded kernel build
# (copy and customize from official compile_scripts/tinyconfig.sh)
EOF
chmod +x scripts/scripts.d/compile_scripts/minimal.sh

# Use it
./start_build.sh --exec minimal.sh
```

**Quick Example - Custom Kernel Source:**
```bash
# Create your custom kernel source plugin
cat > scripts/scripts.d/plugins/kernelsources/my_source.sh << 'EOF'
#!/bin/bash
# My custom kernel source logic
fetch_kernel() {
    # Your implementation here
}
EOF
chmod +x scripts/scripts.d/plugins/kernelsources/my_source.sh

# Use it in params
KERNEL_SOURCE="my_source"
ENV_EXTENSIONS=("kernelsources/my_source.sh")
```

### Safe Customization Pattern (`.d/` Directories)

All customizations follow the **Unix `.d/` pattern** to protect your changes from git conflicts:

- **`params/params.d/`** - Your custom build configurations (gitignored)
- **`scripts/scripts.d/`** - Your custom compile scripts and utilities (gitignored)
  - `compile_scripts/` - Custom build variants alongside official ones
  - `plugins/` - Custom plugin implementations (mirrors official plugin structure)

**Why this matters:**
```bash
# You can safely pull updates without losing your customizations
git pull

# Your files stay put
ls params/params.d/              # Still there! ✅
ls scripts/scripts.d/            # Still there! ✅
ls scripts/scripts.d/    # Still there! ✅

# Update the project fearlessly
git pull
```

**Customization locations:**

- **Build Configurations:** `params/params.d/my_build.params`
- **Compile Scripts:** `scripts/scripts.d/compile_scripts/myconfig.sh`
- **Kernel Sources:** `scripts/scripts.d/plugins/kernelsources/my_source.sh`
- **QA Tests:** `scripts/scripts.d/plugins/qatests/my_test/`
- **Patches:** `scripts/scripts.d/plugins/patches/my.patch`
- **Notifiers:** `scripts/scripts.d/plugins/notifiers/my_notifier.sh`
- **Utilities:** `scripts/scripts.d/plugins/tools/my_tool.sh`
- **Triggers:** `scripts/scripts.d/plugins/triggers/my_trigger.sh`
- **Environment Extensions:** `scripts/scripts.d/plugins/env_extensions/my_env.sh`

For detailed customization examples, see:
- [params/README.md](params/README.md#user-customizations-paramsd) - Parameter customization
- [scripts/scripts.d/README.md](scripts/scripts.d/README.md) - Compile scripts and utilities customization
- [scripts/plugins/README.md](scripts/plugins/README.md) - Plugin customization

### Incremental Builds

Speed up development with incremental builds:

```bash
./start_build.sh --incremental
```

This skips `make mrproper` and reuses previous build state.

### Custom Docker Images

You can use custom Docker images:

```bash
# In params/foundry.params
DOCKERFILE_PATH="myregistry/custom-builder:latest"
```

Or build from a local Dockerfile:

```bash
DOCKERFILE_PATH="docker/my_custom.dockerfile"
```

### Adding Custom QA Tests

1. Create your test script:
   ```bash
   touch scripts/plugins/qatests/mytest.sh
   chmod +x scripts/plugins/qatests/mytest.sh
   ```

2. Implement the test (see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines)

3. Add to params:
   ```bash
   QA_TESTS=(
       "mytest.sh"
   )
   ```

## 🐛 Troubleshooting

For common issues and solutions, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

Quick diagnostics:
```bash
# Validate configuration
./scripts/validate_params.sh

# Check Docker
docker info

# Verify disk space
df -h
```

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development workflow
- Coding standards
- Testing requirements
- Pull request process

## 📜 License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Linux-TKG** - [Frogging-Family/linux-tkg](https://github.com/Frogging-Family/linux-tkg) - Inspiration for kernel tuning approaches
- **Debian and the Debian kernel team** - [wiki.debian.org/Kernel](https://wiki.debian.org/Kernel) - Excellent reference for Debian kernel
- **Linux Kernel** [The Linux Kernel Archive](https://kernel.org/) // [Kernel Build System](https://docs.kernel.org/kbuild/index.html)

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/Bacon-O/Harper-Foundry/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Bacon-O/Harper-Foundry/discussions)

## TODO
*   General testing
*   Improve testing framework
*   Create additional param files for other kernels/distro
*   Create a non-kernel/generic compile job
*   Improve documentation
*   Refine docker image(s)
*   Improve plugins/triggers
*   Improve plugins/notifiers
*   Refine "harvest" steps
