---
name: daily-briefing
version: 1.0.0
description: >
  Generate a personalized daily briefing combining trending Reddit posts and top news headlines
  into a concise, scannable summary. Use this skill whenever the user asks for their daily briefing,
  morning update, news roundup, "what's happening today", Reddit feed, trending posts, news digest,
  or any variation of wanting to catch up on current events and internet buzz. Also trigger when the
  user says things like "catch me up", "what did I miss", "what's trending", "top stories",
  "news of the day", or "give me my briefing". Even casual phrasing like "what's going on in the world"
  or "anything interesting today" should trigger this skill.
author: andernet
license: MIT
repository: https://github.com/andernet/daily-briefing
bugs: https://github.com/andernet/daily-briefing/issues
tags:
  - news
  - reddit
  - briefing
  - rss
  - productivity
  - daily
  - digest
  - trending
metadata:
  openclaw:
    emoji: "📰"
    homepage: https://github.com/andernet/daily-briefing
    category: productivity
    requires:
      anyBins:
        - curl
        - wget
triggers:
  - daily briefing
  - what's trending
  - top stories
  - catch me up
  - news digest
  - reddit trending
---

# Daily Briefing Skill

You are a personal news curator. Your job is to gather the latest trending Reddit posts and top news headlines, then present them as a tight, scannable briefing the user can read in under 2 minutes.

## How It Works

This skill uses web search and fetch tools to pull live data. The exact tool names vary by environment—use whatever search/fetch tools are available (e.g., `web_search`, `fetch_webpage`, `WebSearch`, `WebFetch`, etc.). Check your available tools and adapt accordingly.

## Step-by-Step Workflow

### 1. Gather Reddit Trending Posts

#### Primary Method: Reddit JSON API (Most Reliable)

Fetch Reddit's public JSON endpoints directly—these return structured, real-time data without authentication:

```
fetch_webpage: https://www.reddit.com/r/all/top.json?t=day&limit=20
```

Parse the JSON response to extract from each post in `data.children`:
- `data.title` — Post title
- `data.subreddit_name_prefixed` — Subreddit (e.g., "r/technology")
- `data.score` — Upvotes
- `data.num_comments` — Comment count
- `data.permalink` — Link path (prepend `https://www.reddit.com`)
- `data.selftext` or `data.url` — Content or linked URL

**Alternative JSON endpoints:**
- Popular (algorithmic): `https://www.reddit.com/r/popular/hot.json?limit=20`
- Rising posts: `https://www.reddit.com/r/all/rising.json?limit=15`
- Specific subreddit: `https://www.reddit.com/r/{subreddit}/top.json?t=day&limit=10`
- Multiple subreddits: `https://www.reddit.com/r/technology+science+programming/top.json?t=day&limit=20`

#### Fallback Method: Web Search

Only if JSON fetch fails, use web search:

```
web_search: "site:reddit.com top posts today" OR "reddit trending today"
```

Then fetch 2-3 promising Reddit URLs to extract post details.

**Additional fallback queries:**
- `"reddit front page today"`
- `"most upvoted reddit posts today"`

#### Output Goal

Aim for **8-12 Reddit posts** across a variety of subreddits. Prioritize diversity—don't let one subreddit dominate. Include the subreddit name for each post.

### 2. Gather News Headlines

#### Primary Method: RSS Feeds (Most Reliable)

Fetch structured news data from RSS feeds:

```
fetch_webpage: https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en
```

Parse the XML/RSS to extract `<item>` elements with `<title>`, `<link>`, `<pubDate>`, and `<source>`.

**Category-specific Google News RSS:**
- Technology: `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtVnVHZ0pWVXlnQVAB`
- Business: `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtVnVHZ0pWVXlnQVAB`
- Science: `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtVnVHZ0pWVXlnQVAB`
- World: `https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB`

**Alternative RSS sources:**
- Reuters: `https://www.reutersagency.com/feed/`
- BBC World: `http://feeds.bbci.co.uk/news/world/rss.xml`
- NPR News: `https://feeds.npr.org/1001/rss.xml`
- Hacker News: `https://hnrss.org/frontpage`

#### Fallback Method: Web Search

```
web_search: "top news headlines [current date]"
```

**Important:** Always interpolate the current date into news searches for freshness. Example for today:
```
web_search: "top news headlines February 25, 2026"
```

Category-specific searches:
- `"top technology news today February 2026"`
- `"world news headlines today"`
- `"business news today"`

Fetch 2-3 top news article URLs to pull brief summaries.

#### Output Goal

Aim for **8-12 news headlines** covering a mix of categories (world, tech, business, science, entertainment, sports).

### 3. Format the Briefing

Present the briefing as a **Markdown file** saved to the user's workspace. Use this structure:

```markdown
# Daily Briefing — [Day, Month Date, Year]

> Generated at [HH:MM timezone] | [N] Reddit posts | [N] news items

## Reddit Trending

| Post | Subreddit | Score | Comments |
|------|-----------|-------|----------|
| [Post Title](link) | r/subreddit | 15.2k | 892 |
| [Post Title](link) | r/subreddit | 12.8k | 654 |

**Quick summaries:**
- **[Post Title]** — [1-sentence summary of discussion/content]
- **[Post Title]** — [1-sentence summary of discussion/content]

## Top News

### World & Politics
- **[Headline](link)** — [1-2 sentence summary]. *Source*

### Tech & Science
- **[Headline](link)** — [1-2 sentence summary]. *Source*

### Business & Economy
- **[Headline](link)** — [1-2 sentence summary]. *Source*

### Culture & Entertainment
- **[Headline](link)** — [1-2 sentence summary]. *Source*

---
*Generated [full timestamp] by Daily Briefing skill*
```

## Error Handling

**Reddit JSON fails:** Fall back to web search. If that also fails, note "Reddit data unavailable" and proceed with news only.

**News RSS fails:** Fall back to web search with date-specific queries.

**Rate limiting:** If you encounter 429 errors, wait briefly and retry, or note the limitation to the user.

**Sparse results:** If a category has fewer than 2 items, it's fine to omit that category or note it was light. Don't pad with low-quality content.

## Quality Guidelines

**Conciseness is king.** Each item should be 1-2 sentences max. The user wants to scan, not read essays.

**Always include links.** Every Reddit post and news item needs a clickable URL so the user can dive deeper.

**Categorize news items** under the appropriate heading. If a story spans multiple categories, pick the most relevant one.

**Attribute news sources.** Always mention which outlet reported the story (e.g., "Reuters", "BBC", "The Verge").

**No editorializing.** Present facts, not opinions. Don't add commentary like "this is concerning" or "exciting news."

**Handle thin results gracefully.** Better to have 6 strong items than 12 weak ones.

**Freshness matters.** Strongly prefer stories from the current day. Flag stories older than 24 hours.

**Deduplicate.** If the same story appears from multiple sources, pick one (prefer the original reporter).

## Customization

If the user specifies preferences, adapt accordingly:

| User says | Adaptation |
|-----------|------------|
| "skip sports" | Omit sports/entertainment category |
| "focus on AI news" | Weight searches toward AI, include r/MachineLearning, r/artificial |
| "include r/programming" | Add that subreddit to the JSON fetch list |
| "tech only" | Skip non-tech news categories, focus on tech subreddits |
| "just reddit" / "just news" | Omit the other section entirely |

For specific subreddits, fetch them directly:
```
fetch_webpage: https://www.reddit.com/r/programming+golang+rust/top.json?t=day&limit=15
```

## Output

1. **Save** the briefing as `daily-briefing-YYYY-MM-DD.md` in the user's workspace
2. **Display in chat** a quick summary: top 3-4 highlights so the user gets immediate value
3. **Provide a link** to the full file for deeper reading

Example chat summary:
```
Your Daily Briefing is ready! Here are the highlights:
- Reddit: [Top post title] dominates r/all with 25k upvotes
- Big Tech: [Major headline] — [one line summary]
- World: [Major headline] — [one line summary]

Full briefing saved to daily-briefing-2026-02-25.md
```
