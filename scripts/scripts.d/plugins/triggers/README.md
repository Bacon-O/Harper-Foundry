# Custom Triggers

Add custom build triggers (webhooks, cron, event-driven, etc.).

Implement standard functions: `{name}_trigger()`, `{name}_build_successful()`, `{name}_build_failed()`

See [Official triggers](../../plugins/triggers/README.md) for detailed interface.

trigger_init() {
    PORT=${1:-8080}
    echo "Listening for GitHub webhooks on port $PORT"
}

trigger_handler() {
    # nc -l -p $PORT -e ./start_build.sh
    # Or use Python/Node webhook server
}

export -f trigger_init trigger_handler
```

### Cron Wrapper

```bash
#!/bin/bash
# scripts/scripts.d/plugins/triggers/nightly_build.sh

# Add to crontab: 0 2 * * * /path/to/nightly_build.sh

trigger_handler() {
    echo "Running nightly build..."
    cd /home/user/devel/Debian-Harper
    ./start_build.sh --params-file params/foundry_template.params
    # Notify on completion
}

trigger_handler
```

### File Watch Trigger

```bash
#!/bin/bash
# scripts/scripts.d/plugins/triggers/watch_trigger.sh

trigger_init() {
    WATCH_FILE="/tmp/trigger_build"
    echo "Watching $WATCH_FILE for changes..."
}

trigger_handler() {
    while true; do
        if [[ -f "$WATCH_FILE" ]]; then
            echo "Build triggered by file change"
            ./start_build.sh
            rm "$WATCH_FILE"
        fi
        sleep 5
    done
}

export -f trigger_init trigger_handler
```

### Kernel Release Trigger

```bash
#!/bin/bash
# scripts/scripts.d/plugins/triggers/kernel_release.sh

trigger_handler() {
    LATEST_VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.[0].version')
    CURRENT_VERSION=$(grep "^SOFTWARE_VERSION=" params/foundry_template.params)
    
    if [[ "$LATEST_VERSION" != "$CURRENT_VERSION" ]]; then
        echo "New kernel $LATEST_VERSION released - triggering build"
        sed -i "s/^SOFTWARE_VERSION=.*/SOFTWARE_VERSION=$LATEST_VERSION/" params/foundry_template.params
        ./start_build.sh
    fi
}

export -f trigger_handler
```

## Integration with CI/CD

### GitHub Actions

```yaml
name: Custom Trigger Build

on:
  workflow_dispatch:
  schedule:
    - cron: '0 2 * * *'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run custom trigger
        run: ./scripts/scripts.d/plugins/triggers/github_actions.sh
```

### GitLab CI

```yaml
custom_trigger_build:
  script:
    - ./scripts/scripts.d/plugins/triggers/gitlab_trigger.sh
  only:
    - schedules
```

## Smart Lookup

Custom triggers checked in `scripts/scripts.d/plugins/triggers/` before official triggers in `scripts/plugins/triggers/`.

## Best Practices

1. **Handle errors gracefully** - Include error checking
2. **Log activity** - Write to logs for debugging
3. **Clean up resources** - Implement trigger_cleanup
4. **Documentation** - Document trigger setup and configuration
5. **Security** - Validate inputs, restrict file permissions

## See Also

- [Official triggers documentation](../../plugins/triggers/README.md)
- [Custom scripts documentation](../README.md)
