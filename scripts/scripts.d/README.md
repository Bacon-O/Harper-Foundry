# Custom Scripts Directory (scripts.d/)

**⚠️ This directory is gitignored. All custom scripts here are safe from git conflicts.**

## Overview

`scripts/scripts.d/` is the central location for user customizations of Harper Foundry build scripts and utilities. This directory mirrors the official script structure but is completely protected from version control updates.

## Directory Structure

### `scripts.d/compile_scripts/`

Custom compile scripts - alternative build variants for specific use cases.

**Example:** Create your own specialized build configurations
```bash
scripts/scripts.d/compile_scripts/
├── minimal.sh          # Your minimal embedded build
├── debug.sh            # Debug symbols + verbose logging
├── performance.sh      # Benchmarking optimizations
└── README.md           # Document your custom scripts
```

**Usage:**
```bash
./start_build.sh --exec minimal.sh
./start_build.sh --exec debug.sh
```

### `scripts.d/plugins/`

Custom plugin implementations following the same structure as official plugins.

#### `kernelsources/`

Custom kernel source fetchers for alternative architectures or custom repositories.

```bash
scripts/scripts.d/plugins/kernelsources/
├── custom_arm64.sh     # Custom ARM64 kernel source
├── gitlab_private.sh   # Private GitLab kernel repository
└── README.md
```

#### `notifiers/`

Custom build status notifiers - Slack, Discord, email, etc.

```bash
scripts/scripts.d/plugins/notifiers/
├── slack_webhook.sh    # Slack build notifications
├── email_results.sh    # Email build results
└── README.md
```

#### `patches/`

Custom kernel patches for specific use cases.

```bash
scripts/scripts.d/plugins/patches/
├── security_hardening.patch
├── bpf_optimizations.patch
└── README.md
```

#### `qatests/`

Custom quality assurance test suites.

```bash
scripts/scripts.d/plugins/qatests/
├── packages/           # Custom QA test packages
│   └── mytest/
│       ├── mytest.sh
│       └── runner.sh
├── tests/              # Custom QA test implementations
│   ├── custom_bench.sh
│   └── memtest.sh
└── README.md
```

#### `tools/`

Custom utility scripts and helpers.

```bash
scripts/scripts.d/plugins/tools/
├── build_profiler.sh   # Custom build profiling
├── log_analyzer.sh     # Build log analysis
└── README.md
```

#### `triggers/`

Custom scheduling triggers for automated builds.

```bash
scripts/scripts.d/plugins/triggers/
├── webhook_trigger.sh  # HTTP webhook handler
├── github_actions.sh   # Custom GitHub Actions trigger
└── README.md
```

## Smart Lookup

Most Harper Foundry systems use smart lookup for custom scripts:

1. Check `scripts/scripts.d/*` first (your custom implementations)
2. Fall back to `scripts/*` (official implementations) if custom not found

This means:
- **Custom overrides official:** If you create `scripts.d/plugins/kernelsources/custom.sh`, it takes precedence
- **Mix and match:** Use custom scripts where you need them, official elsewhere
- **No broken references:** If a custom script is deleted, it gracefully falls back to official

## Getting Started

### 1. Create Your Custom Compile Script

```bash
# Copy an existing one as template
cp scripts/compile_scripts/tinyconfig.sh scripts/scripts.d/compile_scripts/myconfig.sh

# Edit it
nano scripts/scripts.d/compile_scripts/myconfig.sh

# Use it
./start_build.sh --exec myconfig.sh
```

### 2. Create Your Custom Plugin

Example: Adding a custom kernel source:

```bash
# Create the file
cat > scripts/scripts.d/plugins/kernelsources/mykernel.sh << 'EOF'
#!/bin/bash
# Custom kernel source fetcher
KERNEL_VERSION="6.10-custom"
fetch_kernel() {
    echo "Fetching custom kernel $KERNEL_VERSION..."
    # Your custom fetch logic here
}
EOF

chmod +x scripts/scripts.d/plugins/kernelsources/mykernel.sh
```

Then configure it in `params/your.params`:

```bash
ENV_EXTENSIONS=("mykernel.sh")
```

### 3. Document Your Scripts

Create a README in each subdirectory explaining your custom scripts and how to use them.

## Git Handling

These files are **gitignored** - they won't be tracked by git. This means:

✅ Safe to customize without conflicting with upstream changes
✅ Won't be accidentally committed to the repository
✅ Your customizations survive `git pull`

## Advanced Usage

### Override an Official Script

```bash
# Current official location
scripts/plugins/kernelsources/debian.sh

# Create custom override
cat > scripts/scripts.d/plugins/kernelsources/debian.sh << 'EOF'
#!/bin/bash
# My custom Debian kernel fetch logic
# This will be used instead of the official version
EOF
```

### Mix Official and Custom

You can use both in `ENV_EXTENSIONS`:

```bash
# params/hybrid.params
ENV_EXTENSIONS=(
    "kernelsources/mykernel.sh"   # Custom (checked first)
    "notifiers/slack.sh"           # Custom (checked first)
    "patches/security.patch"       # Official fallback if custom not found
)
```

### Testing Before Committing

Before you decide a custom script is "production ready," keep it in `scripts.d/`. Once tested:

1. Move it to the official location (`scripts/plugins/...`)
2. Update documentation
3. Commit upstream

## Performance Notes

- Smart lookup adds minimal overhead (fast directory checks)
- Custom scripts run with the same privileges and environment as official ones
- No impact on build time

## Troubleshooting

**"Custom script not loading?"**
- Ensure filename matches (case-sensitive on Linux)
- Check that the file is executable: `chmod +x scripts/scripts.d/plugins/...`
- Verify environment variables are set correctly in params

**"Which version is being used?"**
- Enable verbose logging to see which script path is being loaded
- Check `env_setup.sh` for the exact lookup order

## See Also

- [Official plugins documentation](../plugins/README.md)
- [Compile scripts documentation](../compile_scripts/README.md)
- [Contributing guidelines](../../CONTRIBUTING.md)
