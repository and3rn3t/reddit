# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-02-25

### Added

- Initial release
- Reddit JSON API integration for trending posts
- Multi-source RSS feed support (Google News, BBC, Reuters, NPR, Hacker News)
- Configurable YAML configuration (`config.yaml`)
- Multiple output formats: Markdown, JSON, HTML, plain text
- Content filtering (NSFW, score thresholds, keyword blocklists)
- Response caching with configurable TTL
- Parallel fetching for improved performance
- Deduplication across Reddit and news sources
- Time-based filtering (max_age_hours)
- Comprehensive logging with configurable levels
- GitHub Actions CI pipeline
- Pre-commit hooks for code quality
- 20 evaluation test cases

### Scripts

- `generate-briefing.sh` — Full-featured briefing generator
- `generate-sample.sh` — Simple sample output generator
- `validate-feeds.sh` — Feed availability testing
- `fetch-reddit-schema.sh` — Reddit API schema inspection
- `lib.sh` — Shared utilities (logging, HTTP, retry logic)
- `config.sh` — Configuration parsing library

### Documentation

- `SKILL.md` — ClawHub skill definition
- `README.md` — Usage and installation guide
- `references/reddit-api.md` — Reddit JSON API reference
- `references/news-rss.md` — RSS feed reference

[Unreleased]: https://github.com/andernet/daily-briefing/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andernet/daily-briefing/releases/tag/v1.0.0
