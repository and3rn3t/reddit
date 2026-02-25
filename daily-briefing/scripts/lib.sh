#!/usr/bin/env bash
# lib.sh — Shared utilities for daily-briefing scripts
# Source this file: source "$(dirname "$0")/lib.sh"

# ===== Configuration =====
LOG_FILE="${LOG_FILE:-/tmp/daily-briefing.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR
USER_AGENT="daily-briefing-skill/1.0"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-2}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-15}"

# ===== Logging =====
_log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local message="[$timestamp] [$level] $*"
    
    # Always write to log file
    echo "$message" >> "$LOG_FILE"
    
    # Write to stderr based on level
    case "$LOG_LEVEL" in
        DEBUG) echo "$message" >&2 ;;
        INFO)  [[ "$level" != "DEBUG" ]] && echo "$message" >&2 || true ;;
        WARN)  [[ "$level" == "WARN" || "$level" == "ERROR" ]] && echo "$message" >&2 || true ;;
        ERROR) [[ "$level" == "ERROR" ]] && echo "$message" >&2 || true ;;
    esac
}

log_debug() { _log "DEBUG" "$@"; }
log_info()  { _log "INFO" "$@"; }
log_warn()  { _log "WARN" "$@"; }
log_error() { _log "ERROR" "$@"; }

# ===== HTTP Fetching with Retry =====
# Usage: fetch_url "https://example.com" [expected_content_type]
# Returns: Response body on success, empty string on failure
# Sets: HTTP_STATUS, HTTP_ERROR variables
fetch_url() {
    local url="$1"
    local expected_type="${2:-}"
    local attempt=1
    
    HTTP_STATUS=""
    HTTP_ERROR=""
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_debug "Fetching $url (attempt $attempt/$MAX_RETRIES)"
        
        # Create temp file for response
        local tmp_body
        tmp_body=$(mktemp)
        local tmp_headers
        tmp_headers=$(mktemp)
        
        # Fetch with timeout and capture HTTP status
        HTTP_STATUS=$(curl -s -w "%{http_code}" \
            -A "$USER_AGENT" \
            --max-time "$HTTP_TIMEOUT" \
            -D "$tmp_headers" \
            -o "$tmp_body" \
            "$url" 2>/dev/null) || HTTP_STATUS="000"
        
        # Check status
        case "$HTTP_STATUS" in
            200)
                log_debug "Success: HTTP $HTTP_STATUS for $url"
                cat "$tmp_body"
                rm -f "$tmp_body" "$tmp_headers"
                return 0
                ;;
            429)
                # Rate limited - check Retry-After header
                local retry_after
                retry_after=$(grep -i "retry-after" "$tmp_headers" 2>/dev/null | awk '{print $2}' | tr -d '\r')
                retry_after=${retry_after:-$RETRY_DELAY}
                log_warn "Rate limited (429) for $url, waiting ${retry_after}s"
                sleep "$retry_after"
                ;;
            5[0-9][0-9])
                # Server error - retry
                log_warn "Server error (HTTP $HTTP_STATUS) for $url, retrying..."
                sleep "$RETRY_DELAY"
                ;;
            000)
                # Timeout/connection error
                HTTP_ERROR="Connection timeout or network error"
                log_warn "Connection failed for $url: $HTTP_ERROR"
                sleep "$RETRY_DELAY"
                ;;
            4[0-9][0-9])
                # Client error - don't retry
                HTTP_ERROR="HTTP $HTTP_STATUS"
                log_error "Client error ($HTTP_STATUS) for $url - not retrying"
                rm -f "$tmp_body" "$tmp_headers"
                return 1
                ;;
            *)
                HTTP_ERROR="Unexpected HTTP $HTTP_STATUS"
                log_warn "$HTTP_ERROR for $url"
                sleep "$RETRY_DELAY"
                ;;
        esac
        
        rm -f "$tmp_body" "$tmp_headers"
        attempt=$((attempt + 1))
    done
    
    HTTP_ERROR="Max retries ($MAX_RETRIES) exceeded for $url"
    log_error "$HTTP_ERROR"
    return 1
}

# ===== Reddit-specific fetch =====
fetch_reddit() {
    local endpoint="$1"
    local url="https://www.reddit.com${endpoint}"
    local response
    
    log_info "Fetching Reddit: $endpoint"
    response=$(fetch_url "$url")
    
    if [[ -z "$response" ]]; then
        log_error "Reddit fetch failed: $HTTP_ERROR"
        echo '{"data":{"children":[]}}'
        return 1
    fi
    
    # Validate JSON
    if ! echo "$response" | jq -e '.data.children' >/dev/null 2>&1; then
        log_error "Invalid Reddit JSON response"
        echo '{"data":{"children":[]}}'
        return 1
    fi
    
    echo "$response"
}

# ===== RSS-specific fetch =====
fetch_rss() {
    local url="$1"
    local response
    
    log_info "Fetching RSS: $url"
    response=$(fetch_url "$url")
    
    if [[ -z "$response" ]]; then
        log_error "RSS fetch failed: $HTTP_ERROR"
        return 1
    fi
    
    # Validate XML (basic check)
    if ! echo "$response" | grep -q '<rss\|<feed\|<item>'; then
        log_error "Invalid RSS/XML response from $url"
        return 1
    fi
    
    echo "$response"
}

# ===== Cleanup =====
cleanup_logs() {
    local max_size="${1:-1048576}"  # 1MB default
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat --format=%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $max_size ]]; then
        log_info "Rotating log file (exceeded $max_size bytes)"
        mv "$LOG_FILE" "${LOG_FILE}.old"
    fi
}

# Initialize
cleanup_logs
log_debug "Library loaded, log file: $LOG_FILE"
