# Daily Briefing Skill

📰 **Generate a personalized daily briefing combining trending Reddit posts and top news headlines into a concise, scannable summary.**

## Installation

```bash
npx clawhub@latest install daily-briefing
```

Or with other package managers:

```bash
pnpm dlx clawhub@latest install daily-briefing
bunx clawhub@latest install daily-briefing
```

## Triggers

This skill activates when you say things like:

- "Give me my daily briefing"
- "What's trending today?"
- "Catch me up on the news"
- "What did I miss?"
- "Top stories"
- "Reddit trending"

## What It Does

1. **Fetches Reddit trending posts** via Reddit's JSON API (`/r/all/top.json`)
2. **Gathers news headlines** from RSS feeds (Google News, BBC, Reuters, NPR, Hacker News)
3. **Filters content** by score, age, NSFW status, and custom blocklists
4. **Deduplicates** stories appearing in both Reddit and news
5. **Formats a scannable briefing** as Markdown, JSON, HTML, or plain text

## Output Formats

| Format | Description |
|--------|-------------|
| `markdown` | Clean tables and lists (default) |
| `json` | Machine-readable for downstream processing |
| `html` | Styled page viewable in browser |
| `text` | Plain text for terminal/email |

## Configuration

Copy `config.yaml` to `config.local.yaml` for personal customization:

```yaml
reddit:
  subreddits:
    - name: all
      sort: top
      time: day
      limit: 10
    - name: technology
      sort: top
      time: day
      limit: 5
  filters:
    nsfw: false
    min_score: 100
    min_comments: 10
    max_age_hours: 24
  blocklist:
    - "spam keyword"

news:
  feeds:
    - name: "Google News"
      url: "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"
      limit: 10
      enabled: true
    - name: "BBC World"
      url: "http://feeds.bbci.co.uk/news/world/rss.xml"
      limit: 5
      enabled: true

cache:
  enabled: true
  ttl_seconds: 300

deduplication:
  enabled: true
```

## Scripts

| Script | Purpose |
|--------|---------|
| `generate-briefing.sh` | Enhanced generator with all features |
| `generate-sample.sh` | Simple sample output generator |
| `validate-feeds.sh` | Test all configured feeds |
| `fetch-reddit-schema.sh` | Inspect Reddit API response structure |

### Command-line Options

```bash
./scripts/generate-briefing.sh [options] [output-file]

Options:
  --format FORMAT    markdown, json, html, text
  --no-cache         Disable response caching
  --no-parallel      Disable parallel fetching
  --config FILE      Use custom config file
  --verbose          Enable debug logging
```

## Features

- **Parallel fetching** — Fetch multiple sources simultaneously
- **Caching** — Avoid repeated API calls (configurable TTL)
- **Multiple RSS sources** — Google News, BBC, Reuters, NPR, Hacker News, Guardian
- **Content filtering** — NSFW filter, score thresholds, keyword blocklists
- **Deduplication** — Removes duplicate stories across sources
- **Time filtering** — Only show content from last N hours
- **Error handling** — Graceful fallbacks when sources fail
- **Logging** — Configurable log levels (DEBUG, INFO, WARN, ERROR)

## Customization Prompts

Tell the skill what you want:

- "Just give me reddit, skip the news"
- "Focus on tech and AI"
- "What's trending on r/programming and r/golang?"
- "Skip sports and entertainment"
- "Daily briefing in JSON format"
- "Briefing from the last 6 hours only"

## Requirements

- **jq** — JSON processing
- **curl** — HTTP requests
- **yq** (optional) — YAML config parsing (falls back to basic grep)

No API keys needed — uses public Reddit JSON and RSS feeds.

## Development

### Pre-commit Hooks

```bash
pip install pre-commit
pre-commit install
```

### CI/CD

GitHub Actions workflow runs on every push:

- Shell script linting (shellcheck)
- YAML/JSON validation
- Feed availability testing
- Script execution tests
- Eval validation

## License

MIT
