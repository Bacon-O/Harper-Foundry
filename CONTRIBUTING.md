# Contributing to Harper Foundry

Thank you for your interest in contributing to the Harper Foundry! This document provides guidelines and best practices for contributing to the project.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Project Structure](#project-structure)

## Getting Started

### Prerequisites

Before contributing, ensure you have:
- Docker installed and running
- Bash 4.0 or higher
- Git for version control
- A basic understanding of Linux kernel configuration

### Setting Up Your Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Harper-Foundry.git
   cd Harper-Foundry
   ```
3. Run the interactive setup:
   ```bash
   ./install.sh
   ```
4. Validate your configuration:
   ```bash
   ./scripts/validate_params.sh
   ```

## Development Workflow

### Branch Naming Convention

- `feature/*` - New features or enhancements
- `fix/*` - Bug fixes
- `docs/*` - Documentation improvements
- `refactor/*` - Code refactoring without functional changes
- `test/*` - Test improvements or additions

### Making Changes

1. Create a new branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **For testing with custom parameters**, use `params.d/`:
   ```bash
   # Create development params without git conflicts
   cp params/harper_deb13.params params.d/dev_custom.params
   # Edit and test as needed
   ./start_build.sh --params-file params.d/dev_custom.params
   
   # The params/params.d/ folder is gitignored - your custom params won't conflict
   ```

3. Make your changes following the coding standards below

4. Test your changes:
   ```bash
   # Run a quick test build (2-5 minutes)
   ./start_build.sh --params-file params/tinyconfig.params
   
   # Or use make
   make test
   
   # Validate params
   ./scripts/validate_params.sh
   ```

5. Commit your changes with descriptive messages:
   ```bash
   git commit -m "feat: add support for new architecture"
   ```

### Pre-Commit Shellcheck

The repository includes a pre-commit hook that runs shellcheck on all shell scripts.

**For regular users (non-contributors):**
- The hook is installed automatically by `install.sh`
- Shellcheck issues are shown but **do not block commits**
- This allows you to customize the repo without strict linting requirements

**For contributors:**
- Enable strict mode to block commits with shellcheck issues:
  ```bash
  git config --local foundry.strictLint true
  ```
- Install shellcheck:
  ```bash
  # Debian/Ubuntu
  sudo apt install shellcheck
  
  # macOS
  brew install shellcheck
  ```
- Run manual checks:
  ```bash
  make lint
  ```

The hook automatically excludes `*.params` files since they are configuration files, not executable scripts.

## Coding Standards

### Shell Scripts

- **Shebang**: Always use `#!/bin/bash` for bash scripts
- **Set options**: Use `set -e` to exit on errors
- **Error handling**: Check return codes and provide meaningful error messages
- **Comments**: 
  - Use `#` for single-line comments
  - Add section headers with `# ===` formatting
  - Document non-obvious logic
- **Variables**:
  - Use UPPER_CASE for environment variables and constants
  - Use lower_case for local variables
  - Quote variables: `"$var"` not `$var`
- **Functions**:
  - Use descriptive names with underscores
  - Document parameters and return values
  - Keep functions focused on a single task

### Example:
```bash
#!/bin/bash
set -e

# Validates the kernel configuration file
# Arguments:
#   $1 - Path to the config file
# Returns:
#   0 on success, 1 on failure
validate_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ ERROR: Config file not found: $config_file"
        return 1
    fi
    
    echo "✅ Config file is valid"
    return 0
}
```

### Configuration Files

- Use clear, descriptive variable names
- Add `# @PROMPT` comments for user-configurable options
- Add `# @NO_PROMPT` for system-managed variables
- Group related configurations together
- Include inline documentation for complex settings

### Dockerfiles

- Use multi-stage builds when appropriate
- Minimize layers by combining RUN commands
- Order commands from least to most frequently changing
- Clean up package manager caches
- Document non-obvious dependencies

## Testing

### Test Categories

1. **Unit Tests** - QA test scripts in `scripts/plugins/qatests/`
2. **Integration Tests** - Test packages in `scripts/plugins/qatests/testpackages/`
3. **Build Tests** - Full kernel build tests

### Adding New QA Tests

1. Create your test script in `scripts/plugins/qatests/`:
   ```bash
   touch scripts/plugins/qatests/mytest.sh
   chmod +x scripts/plugins/qatests/mytest.sh
   ```

2. Structure your test:
   ```bash
   #!/bin/bash
   set -e
   
   # Load environment
   source "$(dirname "$0")/../../env_setup.sh" "$@"
   
   # Your test logic here
   echo "✅ Test passed"
   exit 0
   ```

3. Add to `QA_TESTS` array in `params/foundry_template.params`:
   ```bash
   QA_TESTS=(
       "mytest.sh"
   )
   ```

### Creating Test Packages

Test packages are collections of related tests stored in `scripts/plugins/qatests/packages/`.

1. Create a new directory:
   ```bash
   mkdir scripts/plugins/qatests/packages/mypackage
   ```

2. Add test scripts or symlinks to the directory

3. Add to `QA_TEST_PACKAGE` array in params:
   ```bash
   QA_TEST_PACKAGE=(
       "mypackage"
   )
   ```

## Submitting Changes

### Before Submitting

- [ ] Code follows the project's style guidelines
- [ ] All tests pass (`./start_build.sh --test-run`)
- [ ] Configuration is valid (`./scripts/validate_params.sh`)
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear and descriptive

### Pull Request Process

1. Push your changes to your fork
2. Create a Pull Request against the `main` branch
3. Fill out the PR template with:
   - Description of changes
   - Motivation/reason for changes
   - Testing performed
   - Any breaking changes
4. Wait for review and address feedback
5. Once approved, a maintainer will merge your PR

### Commit Message Guidelines

Follow conventional commits format:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style/formatting changes
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

Example:
```
feat: add ARM64 cross-compilation support

- Added new Docker image for ARM64 builds
- Updated env_setup.sh to detect architecture
- Added ARM64-specific configuration options
```

## Project Structure

```
Harper-Foundry/
├── configs/           # Kernel configuration fragments
├── docker/           # Dockerfiles for build environments
├── params/           # Build parameter files
│   └── params.d/     # Your custom parameters (gitignored)
├── scripts/          # Build and utility scripts
│   ├── compile_scripts/  # Official build script variants
│   ├── plugins/      # Extensible plugins
│   │   ├── kernelsources/
│   │   ├── notifiers/
│   │   ├── patches/
│   │   ├── qatests/  # Quality assurance tests
│   │   ├── tools/
│   │   ├── triggers/
│   │   └── env_extensions/
│   ├── scripts.d/    # Your custom scripts (gitignored)
│   │   ├── compile_scripts/
│   │   └── plugins/
│   ├── env_setup.sh  # Environment setup and validation
│   ├── furnace_*.sh  # Build orchestration scripts
│   └── material_analysis.sh  # QA orchestration
├── install.sh        # Interactive setup script
└── start_build.sh    # Main build entry point
```

### Key Files to Know

- `params/foundry_template.params` - Default build configuration
- `scripts/env_setup.sh` - Environment variable definitions
- `scripts/compile_scripts/harper_deb13.sh` - Core build logic (runs in Docker)
- `scripts/material_analysis.sh` - QA test runner
- `.github/workflows/kernel-factory.yml` - CI/CD pipeline

### Customization Directories (All Gitignored)

- `params/params.d/` - Your custom build configurations
- `scripts/scripts.d/` - Your custom compile scripts and utilities
  - `compile_scripts/` - Custom build variants
  - `plugins/` - Custom plugin implementations (kernelsources, notifiers, qatests, etc.)

## Questions or Issues?

- Check existing issues before creating a new one
- Provide detailed information: OS, Docker version, error messages
- Include relevant logs and configuration snippets
- Be patient and respectful in all interactions

Thank you for contributing to Harper Foundry! 🚀
