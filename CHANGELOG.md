# Changelog

All notable changes to the Harper Foundry project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Compile Scripts System** - Modular build script variants in `scripts/compile_scripts/`
  - `harpe_deb13.sh` - Harper's Debian 13 desktop kernel builds (moved from `ci-build.sh`)
  - `tinyconfig.sh` - Fast 2-5 minute test builds for pipeline validation
  - Comprehensive README documenting each mixture
- **Tinyconfig Quick Test** - Dedicated fast build configuration
  - `params/tinyconfig.params` - Optimized for speed
  - Minimal QA validation (filesexists only)
  - Builds bzImage in 2-5 minutes vs 30-60+ for full build
- **Prerequisites checker** (`scripts/check_prerequisites.sh`) - Validates system requirements before building
- **Build status viewer** (`scripts/show_builds.sh`) - Display build artifacts and disk usage information
- **Configuration validator** (`scripts/validate_params.sh`) - Comprehensive validation of foundry_template.params
- **CONTRIBUTING.md** - Comprehensive contribution guidelines
- **TROUBLESHOOTING.md** - Detailed troubleshooting guide with common issues and solutions
- **.editorconfig** - Consistent coding style configuration
- Enhanced **README.md** with badges, better structure, and comprehensive documentation
- Integration of prerequisite checking in `install.sh`
- Better error handling and user feedback in `start_build.sh`
- QA test package structure for `harperbase` test suite

### Changed
- **Reorganized build scripts** - Moved `ci-build.sh` to `compile_scripts/harper_deb13.sh`
  - Removed `ci-build.sh` symlink; update any custom references
  - Updated `FOUNDRY_EXEC` in `foundry_template.params`

- **README structure** - Added compile scripts section and comparison table

### Fixed
- **Critical bug**: Removed duplicate `CROSS_COMPILE` variable definition in `foundry_template.params`
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
- Configurable kernel tuning system
- Quality assurance framework
- GitHub Actions CI/CD integration
- Interactive setup script (`install.sh`)
- Build orchestration scripts
- Cleanup utilities
- Example configurations for multiple architectures

### Features
- `start_build.sh` - Main build entry point
- `params/foundry_template.params` - Configuration file
- `scripts/env_setup.sh` - Environment setup and argument parsing
- `scripts/validate.sh` - Prerequisites checking
- `scripts/launch.sh` - Docker container orchestration
- `scripts/clean.sh` - Artifact cleanup
- `scripts/compile_scripts/harper_deb13.sh` - Container-internal build logic
- `scripts/material_analysis.sh` - QA test orchestration
- QA test plugins:
  - `filesexists.sh` - File presence validation
  - `linuxconfig.sh` - Kernel config validation
  - `kernedebpkg.sh` - Package integrity checks
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

[Unreleased]: https://github.com/Bacon-O/Harper-Foundry/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Bacon-O/Harper-Foundry/releases/tag/v1.0.0
