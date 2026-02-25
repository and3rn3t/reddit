# News RSS Feeds Reference

> **Validate feeds:** Run `./scripts/validate-feeds.sh` to check which feeds are currently working.

## Google News

### Main Feed

```
https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en
```

### Category Feeds

| Category | URL |
|----------|-----|
| World | `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB` |
| Business | `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtVnVHZ0pWVXlnQVAB` |
| Technology | `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtVnVHZ0pWVXlnQVAB` |
| Science | `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtVnVHZ0pWVXlnQVAB` |
| Health | `https://news.google.com/rss/topics/CAAqIQgKIhtDQkFTRGdvSUwyMHZNR3QwTlRFU0FtVnVLQUFQAQ` |
| Sports | `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRFp1ZEdvU0FtVnVHZ0pWVXlnQVAB` |
| Entertainment | `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNREpxYW5RU0FtVnVHZ0pWVXlnQVAB` |

### Localization Parameters

- `hl=en-US` — Language
- `gl=US` — Geographic location
- `ceid=US:en` — Country/language combo

## Other News Sources

### Major Wire Services

| Source | Feed URL |
|--------|----------|
| Reuters | `https://www.reutersagency.com/feed/` |
| AP News | `https://apnews.com/apf-topnews/feed` |

### Broadcast

| Source | Feed URL |
|--------|----------|
| BBC World | `http://feeds.bbci.co.uk/news/world/rss.xml` |
| BBC Tech | `http://feeds.bbci.co.uk/news/technology/rss.xml` |
| NPR News | `https://feeds.npr.org/1001/rss.xml` |

### Tech-Specific

| Source | Feed URL |
|--------|----------|
| Hacker News | `https://hnrss.org/frontpage` |
| Ars Technica | `https://feeds.arstechnica.com/arstechnica/index` |
| The Verge | `https://www.theverge.com/rss/index.xml` |
| TechCrunch | `https://techcrunch.com/feed/` |
| Wired | `https://www.wired.com/feed/rss` |

## RSS Response Structure

Standard RSS 2.0 format:

```xml
<rss version="2.0">
  <channel>
    <title>Google News</title>
    <item>
      <title>Headline text here</title>
      <link>https://news.google.com/articles/...</link>
      <pubDate>Tue, 25 Feb 2026 14:30:00 GMT</pubDate>
      <description>Brief description or snippet</description>
      <source url="https://reuters.com">Reuters</source>
    </item>
    <!-- more items -->
  </channel>
</rss>
```

## Key Fields to Extract

| Field | Description |
|-------|-------------|
| `<title>` | Headline |
| `<link>` | Article URL |
| `<pubDate>` | Publication timestamp |
| `<source>` | Original news outlet |
| `<description>` | Brief snippet (may contain HTML) |

## Google News Link Resolution

Google News links are redirects. The actual article URL is:

1. Encoded in the Google URL path, OR
2. Available after following the redirect

For direct links, you may need to follow the redirect or parse the encoded URL.

## Freshness Filtering

When processing RSS feeds, filter by `<pubDate>`:

- Current day: Include
- Yesterday: Include with "(yesterday)" tag
- Older: Generally exclude for daily briefing

## Common Issues

1. **CORS**: Some RSS feeds don't allow browser fetches. Server-side fetch required.

2. **Rate limits**: Most RSS feeds don't rate limit, but Google may throttle excessive requests.

3. **Stale feeds**: Some feeds cache aggressively. Results may be 15-30 min behind.

4. **HTML in descriptions**: Strip HTML tags from `<description>` content before displaying.
