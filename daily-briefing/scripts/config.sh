#!/usr/bin/env bash
# config.sh — Configuration management for daily-briefing scripts
# Source this file: source "$(dirname "$0")/config.sh"

# Requires: yq (preferred) or basic grep/sed fallback
# Install yq: brew install yq OR pip install yq

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# Config file paths (local overrides default)
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/config.yaml}"
CONFIG_LOCAL="${CONFIG_LOCAL:-$CONFIG_DIR/config.local.yaml}"

# Use local config if it exists
if [[ -f "$CONFIG_LOCAL" ]]; then
    CONFIG_FILE="$CONFIG_LOCAL"
fi

# Check if yq is available
if command -v yq &>/dev/null; then
    HAS_YQ=true
else
    HAS_YQ=false
fi

# ===== Config Reading Functions =====

# Get a config value by path (e.g., "reddit.filters.nsfw")
# Usage: config_get "path.to.value" [default]
config_get() {
    local path="$1"
    local default="${2:-}"
    local value=""
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi
    
    if [[ "$HAS_YQ" == "true" ]]; then
        value=$(yq -r ".$path // \"\"" "$CONFIG_FILE" 2>/dev/null)
    else
        # Basic fallback - only works for simple scalar values
        # Convert path to grep pattern
        value=$(_config_grep_fallback "$path")
    fi
    
    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Get a config array as newline-separated values
# Usage: config_get_array "reddit.subreddits[].name"
config_get_array() {
    local path="$1"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return
    fi
    
    if [[ "$HAS_YQ" == "true" ]]; then
        yq -r ".$path // empty" "$CONFIG_FILE" 2>/dev/null | grep -v '^null$'
    fi
}

# Get enabled news feeds as JSON array
config_get_enabled_feeds() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '[]'
        return
    fi
    
    if [[ "$HAS_YQ" == "true" ]]; then
        yq -o=json '.news.feeds | map(select(.enabled == true))' "$CONFIG_FILE" 2>/dev/null
    else
        # Fallback: return default Google News
        echo '[{"name":"Google News","url":"https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en","limit":10}]'
    fi
}

# Get subreddit configs as JSON array
config_get_subreddits() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '[{"name":"all","sort":"top","time":"day","limit":10}]'
        return
    fi
    
    if [[ "$HAS_YQ" == "true" ]]; then
        yq -o=json '.reddit.subreddits' "$CONFIG_FILE" 2>/dev/null
    else
        echo '[{"name":"all","sort":"top","time":"day","limit":10}]'
    fi
}

# Get blocklist words as newline-separated
config_get_blocklist() {
    local section="${1:-reddit}"  # reddit or news
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return
    fi
    
    if [[ "$HAS_YQ" == "true" ]]; then
        yq -r ".${section}.blocklist[]? // empty" "$CONFIG_FILE" 2>/dev/null
    fi
}

# ===== Boolean Config Helpers =====

config_is_enabled() {
    local path="$1"
    local value
    value=$(config_get "$path" "false")
    [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]
}

# ===== Fallback Parser =====

_config_grep_fallback() {
    local path="$1"
    local key
    key=$(echo "$path" | rev | cut -d. -f1 | rev)
    
    # Very basic: find "key: value" pattern
    grep -E "^[[:space:]]*${key}:" "$CONFIG_FILE" 2>/dev/null | \
        head -1 | \
        sed 's/^[^:]*:[[:space:]]*//' | \
        sed 's/[[:space:]]*#.*//' | \
        sed 's/^["'"'"']//' | \
        sed 's/["'"'"']$//'
}

# ===== Cache Helpers =====

CACHE_DIR=$(config_get "cache.directory" "/tmp/daily-briefing-cache")
CACHE_TTL=$(config_get "cache.ttl_seconds" "300")

cache_init() {
    if config_is_enabled "cache.enabled"; then
        mkdir -p "$CACHE_DIR"
    fi
}

# Get cached content if fresh
# Usage: cache_get "key" -> outputs cached content or returns 1
cache_get() {
    local key="$1"
    local cache_file="$CACHE_DIR/$(echo "$key" | md5sum | cut -d' ' -f1)"
    
    if ! config_is_enabled "cache.enabled"; then
        return 1
    fi
    
    if [[ -f "$cache_file" ]]; then
        local age
        age=$(( $(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat --format=%Y "$cache_file" 2>/dev/null || echo 0) ))
        if [[ $age -lt $CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    return 1
}

# Save content to cache
# Usage: echo "content" | cache_set "key"
cache_set() {
    local key="$1"
    local cache_file="$CACHE_DIR/$(echo "$key" | md5sum | cut -d' ' -f1)"
    
    if config_is_enabled "cache.enabled"; then
        cat > "$cache_file"
    else
        cat  # Pass through
    fi
}

# Clear cache
cache_clear() {
    if [[ -d "$CACHE_DIR" ]]; then
        rm -rf "${CACHE_DIR:?}"/*
    fi
}

# ===== Initialize =====

cache_init

# Export config file path
export CONFIG_FILE
