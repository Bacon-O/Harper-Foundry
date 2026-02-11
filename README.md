# Harper Kernel Foundry

The **Harper Kernel Foundry** is a containerized build system for custom Debian Linux kernels. It integrates schedulers (like BORE and EEVDF) and applies tuning configurations in a reproducible environment.

## 🚀 Features

*   **Containerized Build:** Builds run inside a Docker environment.
*   **Cross-Compilation:** Detects architecture mismatches (e.g., building x86_64 on ARM64) and adjusts toolchains.
*   **Scheduler Injection:** Patches kernels with the BORE scheduler, falling back to EEVDF if patching fails.
*   **Automated QA:** Verifies kernel configuration and binary integrity.
*   **CI/CD:** Integrated with GitHub Actions.

## 📂 Project Structure

*   `start_build.sh`: The main entry point for local builds.
*   `params/`: Configuration files (e.g., `foundry.params`).
*   `scripts/`: Build scripts.
    *   `env_setup.sh`: Argument parsing and environment hydration.
    *   `furnace_ignite.sh`: Docker container launch logic.
    *   `ci-build.sh`: The internal build script executed inside the container.
    *   `material_analysis.sh`: Post-build Quality Assurance.
*   `configs/`: Kernel configuration fragments (base configs and tuning overlays).
*   `docker/`: Dockerfiles defining the build environment.

## 🛠️ Configuration

The build is configured by files located in the `params/` directory. The default is `params/foundry.params`.

Key variables include:
*   `TARGET_ARCH`: Target architecture (e.g., `x86_64`).
*   `KERNEL_SOURCE`: Debian source package name (e.g., `linux/trixie-backports`).
*   `BORE_PATCH_URL`: URL for the scheduler patch.
*   `CHECK_LIST`: Critical Kconfig options that must be present.

## 💻 Usage

### Prerequisites
*   Docker installed and running.
*   Bash shell.

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
| `-e` | `--exec <script>` | Override the script executed inside the container. |
| `-h` | `--help` | Display help menu. |

### Examples

**Run a fast test build:**
```bash
./start_build.sh --test-run
```

**Build using a specific configuration file:**
```bash
./start_build.sh --config-file params/experimental.params
```

### Cleanup

The project includes a script to manage build artifacts and Docker resources.

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

This repository includes a GitHub Actions workflow (`.github/workflows/kernel-factory.yml`).

*   **Push to Main/Tags:** Triggers a production build using `foundry.params`.
*   **Other Pushes:** Triggers a testing build using `_testing.foundry.params`.

## TODO
*   Improve testing framework, perhaps introduce modular test packages
