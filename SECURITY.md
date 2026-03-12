# Security

This is beta software. Don't use it for mission-critical systems or anything requiring formal security compliance.

## Reporting Issues

If you find a security issue, please report it responsibly:
- Open an issue and mark it with the `security` label (private to maintainers)
- Or contact through GitHub directly

## Known Limitations

- **Not formally audited** - no security review or certification
- **Docker execution** - builds run in containers with elevated privileges; keep Docker updated
- **Experimental kernel** - use Debian's official kernels for production systems
- **No automatic updates** - security updates are manual via `git pull`
- **Beta software** - expect bugs and breaking changes

## Bottom Line

Don't run this on:
- Systems you don't control
- Systems you can't afford to break
- Production environments requiring uptime or compliance
- Hardware with critical data

This is a personal project. Use at your own risk.

