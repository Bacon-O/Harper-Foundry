# Changelog

All notable changes to the Harper Kernel Foundry project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Prerequisites checker** (`scripts/check_prerequisites.sh`) - Validates system requirements before building
- **Build status viewer** (`scripts/show_builds.sh`) - Display build artifacts and disk usage information
- **Configuration validator** (`scripts/validate_params.sh`) - Comprehensive validation of foundry.params
- **Makefile** - Common task shortcuts for building, testing, and maintenance
- **CONTRIBUTING.md** - Comprehensive contribution guidelines
- **TROUBLESHOOTING.md** - Detailed troubleshooting guide with common issues and solutions
- **.editorconfig** - Consistent coding style configuration
- Enhanced **README.md** with badges, better structure, and comprehensive documentation
- Integration of prerequisite checking in `install.sh`
- Better error handling and user feedback in `start_build.sh`
- QA test package structure for `harperbase` test suite

### Fixed
- **Critical bug**: Removed duplicate `CROSS_COMPILE` variable definition in `foundry.params`
- **Critical bug**: Fixed syntax error in `material_analysis.sh` (duplicate shebang)
- **Critical bug**: Fixed typo `DEB_TARTET_ARCH` → `DEB_TARGET_ARCH` throughout codebase
- **Bug**: QA test scripts now properly source `env_setup.sh` with correct relative paths
- **Bug**: QA test scripts now properly define `LATEST_BUILD_DIR`, `CONFIG_FILE`, and `KERNEL_IMAGE` variables
- **Bug**: `linuxconfig.sh` missing `#` comment marker before section header

### Changed
- Enhanced `.gitignore` with more comprehensive exclusions
- Improved `install.sh` with validation step and better user feedback
- Enhanced `start_build.sh` with phase labels and better error messages
- QA test package structure: `harperbase` converted from file to directory with symlinks

### Improved
- Better user experience with clear phase indicators during build
- More informative error messages with troubleshooting hints
- Validation workflow integrated into setup process
- Documentation significantly expanded with multiple guides

## [1.0.0] - Initial Release

### Added
- Core build system with Docker containerization
- Cross-compilation support (ARM64 host → x86_64 target)
- BORE scheduler patch integration with EEVDF fallback
- Configurable kernel tuning system
- Quality assurance framework
- GitHub Actions CI/CD integration
- Interactive setup script (`install.sh`)
- Build orchestration scripts
- Cleanup utilities
- Example configurations for multiple architectures

### Features
- `start_build.sh` - Main build entry point
- `params/foundry.params` - Configuration file
- `scripts/env_setup.sh` - Environment setup and argument parsing
- `scripts/furnace_preheat.sh` - Prerequisites checking
- `scripts/furnace_ignite.sh` - Docker container orchestration
- `scripts/furnace_clean.sh` - Artifact cleanup
- `scripts/ci-build.sh` - Container-internal build logic
- `scripts/material_analysis.sh` - QA test orchestration
- QA test plugins:
  - `filesexists.sh` - File presence validation
  - `linuxconfig.sh` - Kernel config validation
  - `debpackage.sh` - Package integrity checks
  - `qemuboot.sh` - Boot testing (optional)

---

## Release Notes Template

When preparing a release, copy this template:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes
```

---

## Version Number Guidelines

- **MAJOR** (X.0.0): Incompatible API changes, major restructuring
- **MINOR** (0.X.0): New features, backwards-compatible
- **PATCH** (0.0.X): Bug fixes, backwards-compatible

---

[Unreleased]: https://github.com/Bacon-O/Debian-Harper/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Bacon-O/Debian-Harper/releases/tag/v1.0.0
