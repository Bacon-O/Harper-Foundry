# Harper Kernel Foundry

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](.github/workflows/kernel-factory.yml)

The **Harper Kernel Foundry** is a containerized build system for custom Debian Linux kernels. It integrates schedulers (like BORE and EEVDF), applies tuning configurations, and provides automated quality assurance in a reproducible environment.

## ✨ Features

*   **🐳 Containerized Build:** Isolated, reproducible builds using Docker
*   **🔀 Cross-Compilation:** Automatic architecture detection and toolchain configuration (e.g., building x86_64 on ARM64)
*   **⚡ Scheduler Integration:** Patch kernels with BORE scheduler, with automatic EEVDF fallback
*   **🛡️ Automated QA:** Extensible quality assurance framework validates configuration and binaries
*   **🚀 CI/CD Ready:** GitHub Actions integration for automated builds
*   **🎛️ Highly Configurable:** Fine-grained control via parameter files
*   **🔧 Incremental Builds:** Optional fast rebuilds for development

## 🚀 Quick Start

### Prerequisites
*   **Docker** (20.10+)
*   **Bash** (4.0+)
*   **Disk Space:** 20GB+ free for build artifacts

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Bacon-O/Debian-Harper.git
   cd Debian-Harper
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

## 📂 Project Structure

*   `start_build.sh`: The main entry point for local builds.
*   `params/`: Configuration files (e.g., `foundry.params`, `tinyconfig.foundry.params`).
*   `scripts/`: Build scripts.
    *   `env_setup.sh`: Argument parsing and environment hydration.
    *   `furnace_ignite.sh`: Docker container launch logic.
    *   `alloymixtures/`: Build script variants (full, tinyconfig, etc.).
    *   `material_analysis.sh`: Post-build Quality Assurance.
*   `configs/`: Kernel configuration fragments (base configs and tuning overlays).
*   `docker/`: Dockerfiles defining the build environment.

## 🛠️ Configuration

The build is configured via files in the `params/` directory. The default is `params/foundry.params`.

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PROJECT_ROOT` | Absolute path to repository on host | `/path/to/Debian-Harper` |
| `HOST_OUTPUT_DIR` | Where build artifacts are stored | `/mnt/build-data/dist/release` |
| `TARGET_ARCH` | Target CPU architecture | `x86_64`, `aarch64` |
| `KERNEL_SOURCE` | Debian kernel source package | `linux/trixie-backports` |
| `BORE_PATCH_URL` | URL to scheduler patch | `https://...` |
| `BASE_CONFIG` | Base kernel config | `defconfig`, `tinyconfig` |
| `TUNING_CONFIG` | Additional config overlay | `debian_tune_test_v1.config` |
| `BYPASS_QA` | Skip quality assurance | `true`, `false` |
| `QA_MODE` | QA strictness | `SOFT`, `HARD` |

### Validation

Always validate your configuration before building:

```bash
./scripts/validate_params.sh params/foundry.params
```

## 💻 Usage

### Prerequisites
*   Docker installed and running
*   Bash shell (4.0+)
*   20GB+ free disk space

### Quick Start
To start a build using the default configuration:

```bash
./start_build.sh
```

### Command Line Arguments
The foundry accepts several arguments to control the process:

| Flag | Long Option | Description |
| :--- | :--- | :--- |
| `-c` | `--config-file <path>` | Specify a custom params file (default: `params/foundry.params`). |
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
./start_build.sh --config-file params/tinyconfig.foundry.params
# Or simply:
make test
```

**Build using a specific configuration file:**
```bash
./start_build.sh --config-file params/experimental.params
```

**Use a specific build mixture:**
```bash
./start_build.sh --exec alloymixtures/tinyconfig.sh
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
| **full.sh** | 30-60+ min | Production builds | Full .deb packages |
| **tinyconfig.sh** | 2-5 min | Quick testing | bzImage only |

See [scripts/alloymixtures/README.md](scripts/alloymixtures/README.md) for detailed information.

### Quick Test vs Full Build

**Tinyconfig Quick Test:**
- ⚡ 2-5 minute builds
- 🎯 Validates foundry pipeline
- 📦 Minimal artifacts (bzImage only)
- ✅ Perfect for testing changes

**Full Production Build:**
- 🏗️ 30-60+ minute builds
- 🎯 Production-ready kernels
- 📦 Complete .deb packages
- ✅ Ready for deployment

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

*   **Production Builds:** Triggered by version tags (e.g., `v1.0.0`) on the `main` branch
*   **Testing Builds:** Triggered by pushes to `dev` and `feature/*` branches
*   **Manual Dispatch:** Run builds on-demand with custom configurations

### Workflow Stages

1. **Preheat** - Validate configuration and prerequisites
2. **Smelt** - Execute containerized kernel build
3. **Analysis** - Run QA tests on build artifacts
4. **Cleanup** - Remove old builds and free disk space

## 🧪 Quality Assurance

The Foundry includes an extensible QA framework:

### Individual Tests

Located in `scripts/plugins/qatests/`:
- `filesexists.sh` - Verifies required files are present
- `linuxconfig.sh` - Validates kernel configuration
- `debpackage.sh` - Checks Debian package integrity
- `qemuboot.sh` - Tests kernel bootability (optional)

### Test Packages

Collections of related tests in `testpackages/`:
- `harperbase` - Core validation suite

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
    "harperbase"
)

# QA behavior
QA_MODE="SOFT"          # SOFT = warn, HARD = fail build
BYPASS_QA="false"       # Set true to skip QA entirely
```

## 🔧 Advanced Usage

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
FOUNDRY_IMAGE="myregistry/custom-builder:latest"
```

Or build from a local Dockerfile:

```bash
FOUNDRY_IMAGE="docker/my_custom.dockerfile"
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

For common issues and solutions, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

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

- **BORE Scheduler** - [firelzrd/bore-scheduler](https://github.com/firelzrd/bore-scheduler)
- **Debian Kernel Team** - For maintaining excellent kernel packages
- **Linux-TKG** - Inspiration for kernel tuning approaches

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/Bacon-O/Debian-Harper/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Bacon-O/Debian-Harper/discussions)

## TODO
*   Improve testing framework, perhaps introduce modular test packages
