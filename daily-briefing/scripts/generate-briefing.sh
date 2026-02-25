#!/usr/bin/env bash
# generate-briefing.sh — Enhanced daily briefing generator
# Features: config file, parallel fetch, multiple sources, caching, filtering, dedup
# 
# Usage: ./scripts/generate-briefing.sh [options] [output-file]
# Options:
#   --format FORMAT    Output format: markdown (default), json, html, text
#   --no-cache         Disable caching
#   --no-parallel      Disable parallel fetching
#   --config FILE      Use custom config file
#   --verbose          Enable debug logging
#   --help             Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/config.sh"

# ===== Defaults =====
OUTPUT_FORMAT="${OUTPUT_FORMAT:-markdown}"
PARALLEL_FETCH="${PARALLEL_FETCH:-true}"

# ===== CLI Argument Parsing =====
OUTPUT_FILE=""
CLI_FORMAT=""
NO_CACHE=false
NO_PARALLEL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            CLI_FORMAT="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --no-parallel)
            NO_PARALLEL=true
            shift
            ;;
        --config)
            export CONFIG_FILE="$2"
            source "$SCRIPT_DIR/config.sh"  # Reload config
            shift 2
            ;;
        --verbose)
            export LOG_LEVEL=DEBUG
            shift
            ;;
        --help)
            sed -n '2,15p' "$0" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            exit 1
            ;;
        *)
            OUTPUT_FILE="$1"
            shift
            ;;
    esac
done

# Apply CLI overrides
if [[ -n "$CLI_FORMAT" ]]; then
    OUTPUT_FORMAT="$CLI_FORMAT"
fi
if [[ "$NO_CACHE" == "true" ]]; then
    export CACHE_ENABLED=false
fi
if [[ "$NO_PARALLEL" == "true" ]]; then
    PARALLEL_FETCH=false
fi

# Default output file based on format
if [[ -z "$OUTPUT_FILE" ]]; then
    case "$OUTPUT_FORMAT" in
        json) OUTPUT_FILE="briefing.json" ;;
        html) OUTPUT_FILE="briefing.html" ;;
        text) OUTPUT_FILE="briefing.txt" ;;
        *)    OUTPUT_FILE="briefing.md" ;;
    esac
fi

# ===== Data Collection =====

# Temp files for parallel processing
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# All collected items (JSON array)
REDDIT_ITEMS='[]'
NEWS_ITEMS='[]'
ERRORS=0

# Get current timestamps
DATE_FULL=$(date +"%A, %B %d, %Y")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CUTOFF_HOURS=$(config_get "reddit.filters.max_age_hours" "24")
CUTOFF_TIME=$(($(date +%s) - CUTOFF_HOURS * 3600))

log_info "Generating daily briefing..."
log_debug "Output format: $OUTPUT_FORMAT, File: $OUTPUT_FILE"
log_debug "Parallel: $PARALLEL_FETCH, Cache: $(config_get cache.enabled true)"

# ===== Fetch Functions =====

fetch_subreddit() {
    local name="$1"
    local sort="${2:-top}"
    local time="${3:-day}"
    local limit="${4:-10}"
    local cache_key="reddit_${name}_${sort}_${time}"
    local url="/r/${name}/${sort}.json?t=${time}&limit=${limit}"
    local response
    
    # Try cache first
    if response=$(cache_get "$cache_key" 2>/dev/null); then
        log_debug "Cache hit: $cache_key"
        echo "$response"
        return 0
    fi
    
    # Fetch from API
    response=$(fetch_reddit "$url") || {
        log_warn "Failed to fetch r/$name"
        echo '{"data":{"children":[]}}'
        return 1
    }
    
    # Save to cache
    echo "$response" | cache_set "$cache_key"
    echo "$response"
}

fetch_feed() {
    local name="$1"
    local url="$2"
    local limit="${3:-10}"
    local cache_key="feed_$(echo "$url" | md5sum | cut -d' ' -f1)"
    local response
    
    # Try cache first  
    if response=$(cache_get "$cache_key" 2>/dev/null); then
        log_debug "Cache hit: $name"
        echo "$response"
        return 0
    fi
    
    # Fetch from URL
    response=$(fetch_rss "$url") || {
        log_warn "Failed to fetch feed: $name"
        return 1
    }
    
    # Save to cache
    echo "$response" | cache_set "$cache_key"
    echo "$response"
}

# ===== Parallel Fetch =====

fetch_all_reddit() {
    local subreddits
    subreddits=$(config_get_subreddits)
    local pids=()
    local i=0
    
    log_info "Fetching Reddit data..."
    
    # Parse subreddits JSON and fetch each
    echo "$subreddits" | jq -c '.[]' 2>/dev/null | while read -r sub; do
        local name sort time limit
        name=$(echo "$sub" | jq -r '.name')
        sort=$(echo "$sub" | jq -r '.sort // "top"')
        time=$(echo "$sub" | jq -r '.time // "day"')
        limit=$(echo "$sub" | jq -r '.limit // 10')
        
        if [[ "$PARALLEL_FETCH" == "true" ]]; then
            fetch_subreddit "$name" "$sort" "$time" "$limit" > "$TMP_DIR/reddit_$i.json" &
            pids+=($!)
        else
            fetch_subreddit "$name" "$sort" "$time" "$limit" > "$TMP_DIR/reddit_$i.json"
        fi
        i=$((i + 1))
    done
    
    # Wait for parallel jobs
    if [[ "$PARALLEL_FETCH" == "true" ]]; then
        for pid in "${pids[@]:-}"; do
            wait "$pid" 2>/dev/null || true
        done
    fi
    
    # Combine all Reddit results
    local combined='[]'
    for f in "$TMP_DIR"/reddit_*.json; do
        [[ -f "$f" ]] || continue
        local items
        items=$(jq '.data.children // []' "$f" 2>/dev/null) || continue
        combined=$(echo "$combined" "$items" | jq -s 'add')
    done
    
    echo "$combined"
}

fetch_all_news() {
    local feeds
    feeds=$(config_get_enabled_feeds)
    local pids=()
    local i=0
    
    log_info "Fetching news feeds..."
    
    echo "$feeds" | jq -c '.[]' 2>/dev/null | while read -r feed; do
        local name url limit
        name=$(echo "$feed" | jq -r '.name')
        url=$(echo "$feed" | jq -r '.url')
        limit=$(echo "$feed" | jq -r '.limit // 10')
        
        if [[ "$PARALLEL_FETCH" == "true" ]]; then
            fetch_feed "$name" "$url" "$limit" > "$TMP_DIR/feed_$i.xml" &
            pids+=($!)
        else
            fetch_feed "$name" "$url" "$limit" > "$TMP_DIR/feed_$i.xml"
        fi
        i=$((i + 1))
    done
    
    # Wait for parallel jobs
    if [[ "$PARALLEL_FETCH" == "true" ]]; then
        for pid in "${pids[@]:-}"; do
            wait "$pid" 2>/dev/null || true
        done
    fi
}

# ===== Content Filtering =====

filter_reddit_items() {
    local items="$1"
    local min_score min_comments nsfw_allowed blocklist
    
    min_score=$(config_get "reddit.filters.min_score" "100")
    min_comments=$(config_get "reddit.filters.min_comments" "10")
    nsfw_allowed=$(config_get "reddit.filters.nsfw" "false")
    
    # Build blocklist regex
    blocklist=$(config_get_blocklist "reddit" | tr '\n' '|' | sed 's/|$//')
    
    echo "$items" | jq --argjson min_score "$min_score" \
                       --argjson min_comments "$min_comments" \
                       --argjson nsfw "$([[ "$nsfw_allowed" == "true" ]] && echo true || echo false)" \
                       --arg blocklist "$blocklist" \
                       --argjson cutoff "$CUTOFF_TIME" '
        [.[] | .data | select(
            .score >= $min_score and
            .num_comments >= $min_comments and
            (if $nsfw then true else (.over_18 | not) end) and
            (.created_utc >= $cutoff) and
            (if $blocklist == "" then true else (.title | test($blocklist; "i") | not) end)
        )]
    ' 2>/dev/null || echo '[]'
}

# ===== Parse News XML to JSON =====

parse_news_xml() {
    local xml_file="$1"
    local feed_name="${2:-Unknown}"
    local limit="${3:-10}"
    local items='[]'
    local count=0
    
    [[ -f "$xml_file" ]] || return
    [[ -s "$xml_file" ]] || return
    
    while IFS= read -r line; do
        [[ $count -ge $limit ]] && break
        
        local title link source pubdate
        title=$(echo "$line" | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' | head -1 | sed 's/"/\\"/g')
        link=$(echo "$line" | sed -n 's/.*<link>\([^<]*\)<\/link>.*/\1/p' | head -1)
        source=$(echo "$line" | sed -n 's/.*<source[^>]*>\([^<]*\)<\/source>.*/\1/p' | head -1)
        pubdate=$(echo "$line" | sed -n 's/.*<pubDate>\([^<]*\)<\/pubDate>.*/\1/p' | head -1)
        
        if [[ -n "$title" && -n "$link" ]]; then
            local item
            item=$(jq -n --arg title "$title" \
                         --arg link "$link" \
                         --arg source "${source:-$feed_name}" \
                         --arg pubdate "$pubdate" \
                         '{title: $title, link: $link, source: $source, pubdate: $pubdate}')
            items=$(echo "$items" | jq --argjson item "$item" '. + [$item]')
            count=$((count + 1))
        fi
    done < <(tr '\n' ' ' < "$xml_file" | sed 's/<item>/\n<item>/g' | grep '<item>')
    
    echo "$items"
}

# ===== Deduplication =====

deduplicate_items() {
    local reddit_items="$1"
    local news_items="$2"
    
    if ! config_is_enabled "deduplication.enabled"; then
        echo "$news_items"
        return
    fi
    
    # Simple dedup: remove news items whose titles appear in Reddit
    # (More sophisticated would use similarity matching)
    local reddit_titles
    reddit_titles=$(echo "$reddit_items" | jq -r '.[].title | ascii_downcase' 2>/dev/null | sort -u)
    
    echo "$news_items" | jq --arg titles "$reddit_titles" '
        [.[] | select(
            (.title | ascii_downcase) as $t |
            ($titles | split("\n") | map(. as $rt | $t | contains($rt)) | any | not)
        )]
    ' 2>/dev/null || echo "$news_items"
}

# ===== Output Formatters =====

format_markdown() {
    local reddit_items="$1"
    local news_items="$2"
    
    cat << EOF
# Daily Briefing — $DATE_FULL

> Generated at $TIMESTAMP

## Reddit Trending

| Post | Subreddit | Score | Comments |
|------|-----------|-------|----------|
EOF
    
    echo "$reddit_items" | jq -r '
        .[:20][] |
        "| [\(.title | gsub("\\|"; "-") | if length > 60 then .[:57] + "..." else . end)](https://www.reddit.com\(.permalink)) | \(.subreddit_name_prefixed) | \(if .score >= 1000 then ((.score / 1000 * 10 | floor) / 10 | tostring) + "k" else (.score | tostring) end) | \(.num_comments) |"
    ' 2>/dev/null || echo "| *No Reddit data* | - | - | - |"
    
    echo ""
    echo "## Top News"
    echo ""
    
    echo "$news_items" | jq -r '
        .[:20][] |
        "- **[\(.title)](\(.link))** — *\(.source)*"
    ' 2>/dev/null || echo "*No news data*"
    
    cat << EOF

---
*Generated $TIMESTAMP by Daily Briefing skill*
EOF
}

format_json() {
    local reddit_items="$1"
    local news_items="$2"
    
    jq -n --arg date "$DATE_FULL" \
          --arg timestamp "$TIMESTAMP" \
          --argjson reddit "$reddit_items" \
          --argjson news "$news_items" \
          '{
            generated: $timestamp,
            date: $date,
            reddit: $reddit,
            news: $news
          }'
}

format_html() {
    local reddit_items="$1"
    local news_items="$2"
    
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily Briefing</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f5f5f5; }
        a { color: #007AFF; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .news-item { margin: 10px 0; }
        .source { color: #666; font-style: italic; }
        footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #999; font-size: 0.9em; }
    </style>
</head>
<body>
EOF
    
    echo "<h1>Daily Briefing — $DATE_FULL</h1>"
    echo "<p><em>Generated at $TIMESTAMP</em></p>"
    echo ""
    echo "<h2>Reddit Trending</h2>"
    echo "<table><tr><th>Post</th><th>Subreddit</th><th>Score</th><th>Comments</th></tr>"
    
    echo "$reddit_items" | jq -r '
        .[:20][] |
        "<tr><td><a href=\"https://www.reddit.com\(.permalink)\">\(.title | if length > 60 then .[:57] + "..." else . end)</a></td><td>\(.subreddit_name_prefixed)</td><td>\(.score)</td><td>\(.num_comments)</td></tr>"
    ' 2>/dev/null || echo "<tr><td colspan=\"4\">No Reddit data</td></tr>"
    
    echo "</table>"
    echo "<h2>Top News</h2>"
    
    echo "$news_items" | jq -r '
        .[:20][] |
        "<div class=\"news-item\"><a href=\"\(.link)\">\(.title)</a> <span class=\"source\">— \(.source)</span></div>"
    ' 2>/dev/null || echo "<p>No news data</p>"
    
    cat << EOF
<footer>Generated $TIMESTAMP by Daily Briefing skill</footer>
</body>
</html>
EOF
}

format_text() {
    local reddit_items="$1"
    local news_items="$2"
    
    echo "DAILY BRIEFING — $DATE_FULL"
    echo "Generated at $TIMESTAMP"
    echo ""
    echo "=== REDDIT TRENDING ==="
    echo ""
    
    echo "$reddit_items" | jq -r '
        .[:20][] |
        "[\(.score)] \(.title)\n    r/\(.subreddit) | \(.num_comments) comments\n    https://www.reddit.com\(.permalink)\n"
    ' 2>/dev/null || echo "No Reddit data"
    
    echo ""
    echo "=== TOP NEWS ==="
    echo ""
    
    echo "$news_items" | jq -r '
        .[:20][] |
        "* \(.title)\n  Source: \(.source)\n  \(.link)\n"
    ' 2>/dev/null || echo "No news data"
}

# ===== Main Execution =====

# Fetch all data
REDDIT_ITEMS=$(fetch_all_reddit)
fetch_all_news

# Parse news XML files
ALL_NEWS='[]'
for f in "$TMP_DIR"/feed_*.xml; do
    [[ -f "$f" ]] || continue
    local_news=$(parse_news_xml "$f" "News" 10)
    ALL_NEWS=$(echo "$ALL_NEWS" "$local_news" | jq -s 'add')
done

# Apply filters
log_info "Filtering content..."
REDDIT_FILTERED=$(filter_reddit_items "$REDDIT_ITEMS")
NEWS_FILTERED=$(deduplicate_items "$REDDIT_FILTERED" "$ALL_NEWS")

# Count results
REDDIT_COUNT=$(echo "$REDDIT_FILTERED" | jq 'length' 2>/dev/null) || REDDIT_COUNT=0
NEWS_COUNT=$(echo "$NEWS_FILTERED" | jq 'length' 2>/dev/null) || NEWS_COUNT=0

log_info "Collected: $REDDIT_COUNT Reddit posts, $NEWS_COUNT news items"

# Generate output
log_info "Generating $OUTPUT_FORMAT output..."
case "$OUTPUT_FORMAT" in
    json)
        format_json "$REDDIT_FILTERED" "$NEWS_FILTERED" > "$OUTPUT_FILE"
        ;;
    html)
        format_html "$REDDIT_FILTERED" "$NEWS_FILTERED" > "$OUTPUT_FILE"
        ;;
    text)
        format_text "$REDDIT_FILTERED" "$NEWS_FILTERED" > "$OUTPUT_FILE"
        ;;
    *)
        format_markdown "$REDDIT_FILTERED" "$NEWS_FILTERED" > "$OUTPUT_FILE"
        ;;
esac

log_info "Saved to: $OUTPUT_FILE"
echo "✓ Briefing generated: $OUTPUT_FILE (Reddit: $REDDIT_COUNT, News: $NEWS_COUNT)" >&2
