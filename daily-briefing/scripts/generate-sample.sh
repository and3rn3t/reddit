#!/usr/bin/env bash
# generate-sample.sh
# DEPRECATED: Use generate-briefing.sh instead, which has more features.
# This script is kept for backward compatibility.
#
# Generates a sample daily briefing from live Reddit and news data
# Run: ./scripts/generate-sample.sh [output-file]
# Preferred: ./scripts/generate-briefing.sh [output-file]

set -euo pipefail

echo "⚠ DEPRECATED: Use generate-briefing.sh for more features" >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared library if available
if [[ -f "$SCRIPT_DIR/lib.sh" ]]; then
    # shellcheck source=lib.sh
    source "$SCRIPT_DIR/lib.sh"
    USE_LIB=true
else
    USE_LIB=false
    log_info() { echo "[INFO] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

OUTPUT_FILE="${1:-sample-briefing.md}"
USER_AGENT="daily-briefing-skill/1.0"
REDDIT_LIMIT=10
NEWS_LIMIT=10

# Track errors for exit code
ERRORS=0

log_info "Generating sample daily briefing..."

# Get current date
DATE_FULL=$(date +"%A, %B %d, %Y")
DATE_SHORT=$(date +"%Y-%m-%d")
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Fetch Reddit data
log_info "Fetching Reddit trending posts..."
if [[ "$USE_LIB" == "true" ]]; then
    REDDIT_JSON=$(fetch_reddit "/r/all/top.json?t=day&limit=$REDDIT_LIMIT") || {
        log_warn "Reddit fetch failed, using empty data"
        REDDIT_JSON='{"data":{"children":[]}}'
        ERRORS=$((ERRORS + 1))
    }
else
    REDDIT_JSON=$(curl -s -A "$USER_AGENT" --max-time 15 "https://www.reddit.com/r/all/top.json?t=day&limit=$REDDIT_LIMIT" 2>/dev/null) || REDDIT_JSON=""
    if [[ -z "$REDDIT_JSON" ]] || ! echo "$REDDIT_JSON" | jq -e '.data' >/dev/null 2>&1; then
        log_warn "Reddit fetch failed"
        REDDIT_JSON='{"data":{"children":[]}}'
        ERRORS=$((ERRORS + 1))
    fi
fi

# Fetch Google News RSS
log_info "Fetching news headlines..."
if [[ "$USE_LIB" == "true" ]]; then
    NEWS_XML=$(fetch_rss "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en") || {
        log_warn "News RSS fetch failed"
        NEWS_XML=""
        ERRORS=$((ERRORS + 1))
    }
else
    NEWS_XML=$(curl -s -A "$USER_AGENT" --max-time 15 "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en" 2>/dev/null) || NEWS_XML=""
    if [[ -z "$NEWS_XML" ]] || ! echo "$NEWS_XML" | grep -q '<item>'; then
        log_warn "News RSS fetch failed or empty"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Start building output
{
    echo "# Daily Briefing — $DATE_FULL"
    echo ""
    echo "> Generated at $TIMESTAMP | Sample output from live data"
    echo ""
    
    # Reddit section
    echo "## Reddit Trending"
    echo ""
    echo "| Post | Subreddit | Score | Comments |"
    echo "|------|-----------|-------|----------|"
    
    # Parse Reddit JSON
    if echo "$REDDIT_JSON" | jq -e '.data.children[0]' >/dev/null 2>&1; then
        echo "$REDDIT_JSON" | jq -r '
            .data.children[:10][] | 
            .data | 
            "| [\(.title | gsub("\\|"; "-") | if length > 60 then .[:57] + "..." else . end)](https://www.reddit.com\(.permalink)) | \(.subreddit_name_prefixed) | \(if .score >= 1000 then ((.score / 1000 * 10 | floor) / 10 | tostring) + "k" else (.score | tostring) end) | \(.num_comments) |"
        ' 2>/dev/null || echo "| *Unable to parse Reddit data* | - | - | - |"
    else
        echo "| *Reddit data unavailable* | - | - | - |"
    fi
    
    echo ""
    echo "## Top News"
    echo ""
    
    # Parse News RSS (basic XML parsing with sed/grep - jq can't parse XML)
    if [[ -n "$NEWS_XML" ]] && echo "$NEWS_XML" | grep -q '<item>'; then
        echo "### Headlines"
        echo ""
        
        # Extract individual items using sed (put each item on one line, then process)
        _news_count=0
        while IFS= read -r line; do
            [[ $_news_count -ge $NEWS_LIMIT ]] && break
            
            # Extract title and link from the line
            title=$(echo "$line" | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' | head -1)
            link=$(echo "$line" | sed -n 's/.*<link>\([^<]*\)<\/link>.*/\1/p' | head -1)
            source=$(echo "$line" | sed -n 's/.*<source[^>]*>\([^<]*\)<\/source>.*/\1/p' | head -1)
            
            if [[ -n "$title" && -n "$link" ]]; then
                # Clean up title
                title=$(echo "$title" | sed 's/|/-/g')
                if [[ -n "$source" ]]; then
                    echo "- **[$title]($link)** — *$source*"
                else
                    echo "- **[$title]($link)**"
                fi
                _news_count=$((_news_count + 1))
            fi
        done < <(echo "$NEWS_XML" | tr '\n' ' ' | sed 's/<item>/\n<item>/g' | grep '<item>')
    else
        echo "### Headlines"
        echo ""
        echo "*News data unavailable*"
    fi
    
    echo ""
    echo "---"
    echo "*Generated $TIMESTAMP by Daily Briefing skill (sample output)*"
    
} > "$OUTPUT_FILE"

log_info "Sample briefing saved to: $OUTPUT_FILE"

# Summary stats
REDDIT_COUNT=$(echo "$REDDIT_JSON" | jq '.data.children | length' 2>/dev/null) || REDDIT_COUNT="0"
log_info "Reddit posts fetched: $REDDIT_COUNT"

NEWS_COUNT=0
if [[ -n "$NEWS_XML" ]]; then
    # Count items by counting <item> occurrences in the XML
    NEWS_COUNT=$(echo "$NEWS_XML" | tr '\n' ' ' | grep -oE '<item>' | wc -l | tr -d ' ') || NEWS_COUNT="0"
    log_info "News items available: $NEWS_COUNT (showing up to $NEWS_LIMIT)"
fi

# Final status
if [[ $ERRORS -gt 0 ]]; then
    log_warn "Completed with $ERRORS error(s) - some data may be missing"
    echo "" >&2
    echo "⚠ Briefing generated with warnings (check log: ${LOG_FILE:-/tmp/daily-briefing.log})" >&2
    exit 1
else
    echo "" >&2
    echo "✓ Briefing generated successfully: $OUTPUT_FILE" >&2
    echo "  Reddit: $REDDIT_COUNT posts | News: $NEWS_COUNT items" >&2
    exit 0
fi
