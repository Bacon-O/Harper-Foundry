# Harper Foundry - Makefile
# Common tasks and shortcuts

.PHONY: help setup validate check build test clean deep-clean status

# Default target
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Harper Foundry - Make Targets"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Setup & Configuration:"
	@echo "  make setup       - Run interactive setup (install.sh)"
	@echo "  make check       - Check system prerequisites"
	@echo "  make validate    - Validate foundry_template.params configuration"
	@echo ""
	@echo "Building:"
	@echo "  make build       - Run full kernel build"
	@echo "  make test        - Run fast test build (tinyconfig)"
	@echo "  make rebuild     - Force rebuild Docker image and build"
	@echo ""
	@echo "Maintenance:"
	@echo "  make status      - Show build artifacts and disk usage"
	@echo "  make clean       - Remove old build artifacts (keep 3 newest)"
	@echo "  make deep-clean  - Remove all artifacts and Docker cache"
	@echo ""
	@echo "Development:"
	@echo "  make lint        - Run shellcheck on all scripts"
	@echo "  make format      - Format shell scripts with shfmt"
	@echo ""

# Setup and configuration
setup:
	@echo "🚀 Running interactive setup..."
	./install.sh

check:
	@echo "🔍 Checking system prerequisites..."
	./scripts/check_prerequisites.sh

validate:
	@echo "🔍 Validating configuration..."
	./scripts/validate_params.sh

# Build targets
build:
	@echo "🔨 Starting kernel build..."
	./start_build.sh

test:
	@echo "🧪 Running tinyconfig quick test build..."
	./start_build.sh --params-file params/tinyconfig.params

rebuild:
	@echo "🔨 Rebuilding Docker image and kernel..."
	./start_build.sh --rebuild

# Maintenance
status:
	@echo "📊 Checking build status..."
	./scripts/show_builds.sh

clean:
	@echo "🧹 Cleaning old build artifacts..."
	./scripts/clean.sh

deep-clean:
	@echo "🧼 Deep cleaning all artifacts and Docker cache..."
	./scripts/clean.sh --deep

# Development tools (optional)
SHFMT_FLAGS := $(shell cat .shfmt 2>/dev/null)

# Note: *.params files are intentionally excluded from linting.
# They are configuration files (VAR=value assignments), not executable scripts.
lint:
	@echo "🔍 Linting shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find scripts -name "*.sh" -exec shellcheck {} +; \
		shellcheck install.sh start_build.sh; \
	else \
		echo "❌ shellcheck not installed. Install with: apt install shellcheck"; \
		exit 1; \
	fi
	@if command -v shfmt >/dev/null 2>&1; then \
		find scripts -name "*.sh" -exec shfmt -d $(SHFMT_FLAGS) {} +; \
		shfmt -d $(SHFMT_FLAGS) install.sh start_build.sh; \
	else \
		echo "❌ shfmt not installed. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
		exit 1; \
	fi

format:
	@echo "✨ Formatting shell scripts..."
	@if command -v shfmt >/dev/null 2>&1; then \
		find scripts -name "*.sh" -exec shfmt -w $(SHFMT_FLAGS) {} +; \
		shfmt -w $(SHFMT_FLAGS) install.sh start_build.sh; \
	else \
		echo "❌ shfmt not installed. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
		exit 1; \
	fi
