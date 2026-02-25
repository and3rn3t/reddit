#!/usr/bin/env bash
# validate-feeds.sh
# Checks all RSS/JSON feed URLs for availability
# Run: ./scripts/validate-feeds.sh [--markdown]

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
USER_AGENT="daily-briefing-skill/1.0"
TIMEOUT=10

# Define all feeds to check
declare -A FEEDS=(
    # Reddit JSON endpoints
    ["Reddit: r/all top"]="https://www.reddit.com/r/all/top.json?t=day&limit=1"
    ["Reddit: r/all hot"]="https://www.reddit.com/r/all/hot.json?limit=1"
    ["Reddit: r/popular"]="https://www.reddit.com/r/popular/hot.json?limit=1"
    ["Reddit: r/all rising"]="https://www.reddit.com/r/all/rising.json?limit=1"
    
    # Google News RSS
    ["Google News: Main"]="https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"
    ["Google News: Tech"]="https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGRqTVhZU0FtVnVHZ0pWVXlnQVAB"
    ["Google News: Business"]="https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx6TVdZU0FtVnVHZ0pWVXlnQVAB"
    ["Google News: World"]="https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB"
    
    # Other news sources
    ["BBC World"]="http://feeds.bbci.co.uk/news/world/rss.xml"
    ["BBC Tech"]="http://feeds.bbci.co.uk/news/technology/rss.xml"
    ["NPR News"]="https://feeds.npr.org/1001/rss.xml"
    ["Hacker News"]="https://hnrss.org/frontpage"
    ["Ars Technica"]="https://feeds.arstechnica.com/arstechnica/index"
    ["The Verge"]="https://www.theverge.com/rss/index.xml"
    ["TechCrunch"]="https://techcrunch.com/feed/"
)

echo "Validating ${#FEEDS[@]} feed URLs..." >&2
echo "" >&2

# Results arrays
declare -a RESULTS=()
OK_COUNT=0
FAIL_COUNT=0

for name in "${!FEEDS[@]}"; do
    url="${FEEDS[$name]}"
    
    # Get HTTP status code
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -A "$USER_AGENT" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        STATUS="✓ OK"
        ((OK_COUNT++))
    elif [[ "$HTTP_CODE" == "000" ]]; then
        STATUS="✗ Timeout/Error"
        ((FAIL_COUNT++))
    elif [[ "$HTTP_CODE" == "429" ]]; then
        STATUS="⚠ Rate Limited"
        ((FAIL_COUNT++))
    else
        STATUS="✗ HTTP $HTTP_CODE"
        ((FAIL_COUNT++))
    fi
    
    RESULTS+=("$name|$HTTP_CODE|$STATUS|$url")
    echo "  $STATUS  $name" >&2
done

echo "" >&2
echo "Results: $OK_COUNT OK, $FAIL_COUNT failed" >&2
echo "" >&2

# Output
if [[ "$OUTPUT_FORMAT" == "--markdown" ]]; then
    echo "# Feed Validation Report"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    echo "| Feed | Status | HTTP | URL |"
    echo "|------|--------|------|-----|"
    for result in "${RESULTS[@]}"; do
        IFS='|' read -r name code status url <<< "$result"
        echo "| $name | $status | $code | \`$url\` |"
    done
    echo ""
    echo "**Summary:** $OK_COUNT OK, $FAIL_COUNT failed"
elif [[ "$OUTPUT_FORMAT" == "--json" ]]; then
    echo "{"
    echo "  \"generated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"ok\": $OK_COUNT,"
    echo "  \"failed\": $FAIL_COUNT,"
    echo "  \"feeds\": ["
    first=true
    for result in "${RESULTS[@]}"; do
        IFS='|' read -r name code status url <<< "$result"
        [[ "$first" == "true" ]] || echo ","
        first=false
        echo -n "    {\"name\": \"$name\", \"http_code\": $code, \"url\": \"$url\"}"
    done
    echo ""
    echo "  ]"
    echo "}"
else
    # Default table output
    printf "%-25s %-20s %s\n" "Feed" "Status" "URL"
    printf "%-25s %-20s %s\n" "----" "------" "---"
    for result in "${RESULTS[@]}"; do
        IFS='|' read -r name code status url <<< "$result"
        printf "%-25s %-20s %s\n" "$name" "$status" "$url"
    done
fi

# Exit with error if any feeds failed
[[ $FAIL_COUNT -eq 0 ]] || exit 1
