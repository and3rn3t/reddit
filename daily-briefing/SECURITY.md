# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it by:

1. **Do NOT** open a public GitHub issue
2. Email the maintainer directly or use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Considerations

This skill:

- **Does NOT require API keys** — uses only public endpoints
- **Does NOT store credentials** — no auth tokens are cached
- **Does NOT execute arbitrary code** — scripts are read-only data fetchers
- **Caches responses locally** — in `/tmp/daily-briefing-cache` by default

### Data Sources

All data is fetched from public sources:

- Reddit JSON API (public, no auth)
- RSS feeds (public)

### Cache Security

Cached data is stored in `/tmp/daily-briefing-cache` with standard file permissions. To clear:

```bash
rm -rf /tmp/daily-briefing-cache
```

### Log Security

Logs are written to `/tmp/daily-briefing.log`. They may contain:
- URLs fetched
- Error messages
- Timestamps

Logs do NOT contain:
- User credentials
- Personal data
- API keys

To clear logs:

```bash
rm /tmp/daily-briefing.log
```
