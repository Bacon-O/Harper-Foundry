# Custom Notifiers

Add custom build status notifiers here. These override official notifiers with the same name.

## Purpose

Send build status updates to your systems:
- Slack webhooks
- Discord webhooks
- Email
- Matrix/Elements
- Custom monitoring systems
- SMS alerts

## Template

```bash
#!/bin/bash
# scripts/scripts.d/plugins/notifiers/myalert.sh

notify_start() {
    echo "Build started: $BUILD_ID"
    # Send notification
}

notify_success() {
    echo "Build succeeded: $BUILD_ID"
    # Send notification
}

notify_failure() {
    echo "Build failed: $BUILD_ID - $1"
    # Send notification
}

export -f notify_start notify_success notify_failure
```

## Usage

Reference in your params file:

```bash
# params/your.params
ENV_EXTENSIONS=("notifiers/myalert.sh")
```

## Examples

### Slack Webhook

```bash
#!/bin/bash
# scripts/scripts.d/plugins/notifiers/slack.sh

notify_start() {
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d '{"text":"🔨 Build starting: '$BUILD_ID'"}'
}

notify_success() {
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d '{"text":"✅ Build succeeded: '$BUILD_ID'"}'
}

notify_failure() {
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d '{"text":"❌ Build failed: '$BUILD_ID' - '$1'"}'
}

export -f notify_start notify_success notify_failure
```

### Email

```bash
#!/bin/bash
# scripts/scripts.d/plugins/notifiers/email.sh

notify_start() {
    echo "Build $BUILD_ID started" | mail -s "Harper Build: Starting" admin@example.com
}

notify_success() {
    echo "Build artifacts ready" | mail -s "Harper Build: SUCCESS" admin@example.com
}

notify_failure() {
    echo "Build failed: $1" | mail -s "Harper Build: FAILED" admin@example.com
}

export -f notify_start notify_success notify_failure
```

## Smart Lookup

When configured:
1. Looks in `scripts/scripts.d/plugins/notifiers/` first
2. Falls back to `scripts/plugins/notifiers/` if custom not found

## See Also

- [Official notifiers documentation](../../plugins/notifiers/README.md)
- [Custom scripts documentation](../README.md)
