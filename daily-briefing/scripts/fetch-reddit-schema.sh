#!/usr/bin/env bash
# fetch-reddit-schema.sh
# Fetches live Reddit JSON and extracts the actual field schema
# Run: ./scripts/fetch-reddit-schema.sh [--markdown]

set -euo pipefail

ENDPOINT="https://www.reddit.com/r/all/top.json?t=day&limit=1"
USER_AGENT="daily-briefing-skill/1.0"
OUTPUT_FORMAT="${1:-json}"

echo "Fetching Reddit schema from: $ENDPOINT" >&2

# Fetch a single post to introspect
RESPONSE=$(curl -s -A "$USER_AGENT" "$ENDPOINT")

if [[ -z "$RESPONSE" ]] || ! echo "$RESPONSE" | jq -e '.data.children[0]' >/dev/null 2>&1; then
    echo "Error: Failed to fetch or parse Reddit response" >&2
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Extract fields from first post
FIELDS=$(echo "$RESPONSE" | jq -r '
    .data.children[0].data | 
    to_entries | 
    map({
        field: .key,
        type: (.value | type),
        example: (
            if .value == null then "null"
            elif (.value | type) == "string" then 
                if (.value | length) > 50 then (.value[:50] + "...") else .value end
            elif (.value | type) == "array" then "[array:\((.value | length) ) items]"
            elif (.value | type) == "object" then "{object}"
            elif (.value | type) == "number" then (.value | tostring)
            elif (.value | type) == "boolean" then (.value | tostring)
            else (.value | tostring)
            end
        )
    })
')

if [[ "$OUTPUT_FORMAT" == "--markdown" ]]; then
    echo "# Reddit Post Schema"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "Endpoint: \`$ENDPOINT\`"
    echo ""
    echo "| Field | Type | Example |"
    echo "|-------|------|---------|"
    echo "$FIELDS" | jq -r '.[] | "| `\(.field)` | \(.type) | \(.example | gsub("\\|"; "\\|") | gsub("\n"; " ")) |"'
    echo ""
    echo "## Key Fields for Daily Briefing"
    echo ""
    echo "| Field | Description |"
    echo "|-------|-------------|"
    echo "| \`title\` | Post title |"
    echo "| \`subreddit_name_prefixed\` | Subreddit with r/ prefix |"
    echo "| \`score\` | Net upvotes |"
    echo "| \`num_comments\` | Comment count |"
    echo "| \`permalink\` | Post path (prepend https://www.reddit.com) |"
    echo "| \`url\` | External link (for link posts) |"
    echo "| \`selftext\` | Text body (for self posts) |"
    echo "| \`created_utc\` | Unix timestamp |"
else
    echo "$FIELDS" | jq '.'
fi

echo "" >&2
echo "✓ Schema extracted from live Reddit API" >&2
