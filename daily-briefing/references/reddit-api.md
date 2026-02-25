# Reddit JSON API Quick Reference

> **Live schema:** Run `./scripts/fetch-reddit-schema.sh --markdown` to generate current field schema from the live API.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `/r/all/top.json?t=day&limit=20` | Top posts from all subreddits (past 24h) |
| `/r/all/hot.json?limit=20` | Currently hot posts across Reddit |
| `/r/all/rising.json?limit=15` | Rising posts (gaining traction) |
| `/r/popular/hot.json?limit=20` | Popular posts (slightly different algorithm) |
| `/r/{subreddit}/top.json?t=day&limit=10` | Top posts from specific subreddit |
| `/r/sub1+sub2+sub3/top.json?t=day` | Combined multi-subreddit feed |

### Time Parameters (`t=`)

- `hour` — Past hour
- `day` — Past 24 hours (default for daily briefing)
- `week` — Past week
- `month` — Past month
- `year` — Past year
- `all` — All time

## Response Structure

```json
{
  "kind": "Listing",
  "data": {
    "children": [
      {
        "kind": "t3",
        "data": {
          "title": "Post title here",
          "subreddit": "technology",
          "subreddit_name_prefixed": "r/technology",
          "score": 15234,
          "ups": 15234,
          "num_comments": 892,
          "permalink": "/r/technology/comments/abc123/post_title/",
          "url": "https://external-link.com/article",
          "selftext": "Text content for self-posts",
          "is_self": false,
          "author": "username",
          "created_utc": 1740500000,
          "over_18": false,
          "spoiler": false,
          "stickied": false,
          "link_flair_text": "News"
        }
      }
    ],
    "after": "t3_xyz789",
    "before": null
  }
}
```

## Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Post title |
| `subreddit_name_prefixed` | string | Subreddit with "r/" prefix |
| `score` | int | Net upvotes (ups - downs) |
| `num_comments` | int | Comment count |
| `permalink` | string | Path to post (prepend `https://www.reddit.com`) |
| `url` | string | External link (for link posts) |
| `selftext` | string | Text body (for self/text posts) |
| `is_self` | bool | True if text post, false if link post |
| `created_utc` | float | Unix timestamp of creation |
| `over_18` | bool | NSFW flag |
| `link_flair_text` | string | Flair/tag text (may be null) |

## Building Full URLs

```
Post URL: https://www.reddit.com + permalink
Example: https://www.reddit.com/r/technology/comments/abc123/post_title/
```

## Headers (Recommended)

Reddit may rate-limit or block requests without a proper User-Agent:

```
User-Agent: daily-briefing-skill/1.0
```

## Rate Limits

- Without authentication: ~10 requests/minute
- With OAuth: 60 requests/minute
- 429 errors indicate rate limiting — back off and retry

## Common Issues

1. **Empty response**: Reddit occasionally returns empty listings. Retry or try `/hot.json` instead of `/top.json`.

2. **403 Forbidden**: Usually means rate limiting or blocked User-Agent. Wait and retry.

3. **NSFW filtering**: Posts with `over_18: true` may be filtered. Decide whether to include/exclude.

4. **Score formatting**: For display, convert large numbers: 15234 → "15.2k"
