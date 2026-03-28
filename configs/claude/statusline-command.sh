#!/usr/bin/env bash
# Claude Code Status Line (Powerline style — Material Darker palette)

input=$(cat)

SEP=$(printf '\xee\x82\xb0')

# ANSI helpers
fg() { printf '\e[38;5;%sm' "$1"; }
bg() { printf '\e[48;5;%sm' "$1"; }
bold() { printf '\e[1m'; }
reset() { printf '\e[0m'; }

# Color palette (Material Darker)
C_MODEL=176       # #c792ea purple
C_COST=174        # #f07178 red
C_TOKENS=209      # #f78c6c orange
C_CTX_GOOD=150    # #c3e88d green
C_CTX_MID=222     # #ffcb6b yellow
C_CTX_LOW=204     # #ff5370 error red
C_DIR=111         # #82aaff blue
C_STYLE=117       # #89ddff cyan
C_VIM=208         # #FF9800 accent orange
C_USAGE=73        # #5fafaf teal
C_FG=255          # #eeffff white

# Helper: format token count with K/M suffix
fmt_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc -l)"
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        printf "%.1fK" "$(echo "scale=1; $n / 1000" | bc -l)"
    else
        printf "%s" "$n"
    fi
}

# Extract data from JSON
model=$(echo "$input" | jq -r '.model.display_name // "Claude"' | sed 's/ context)/)/g')
version=$(echo "$input" | jq -r '.version // ""')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
output_style=$(echo "$input" | jq -r '.output_style.name // ""')
vim_mode=$(echo "$input" | jq -r '.vim.mode // ""')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Session cost
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Token data
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
total_tokens=$((total_input + total_output))

# Short directory name
if [ -n "$cwd" ]; then
    short_dir=$(basename "$cwd")
else
    short_dir="~"
fi

# 5h/7d usage from Anthropic OAuth usage API (real percentages)
USAGE_CACHE="$HOME/.claude/.statusline-usage-cache.json"
USAGE_LOCK="${USAGE_CACHE}.lock"
USAGE_CACHE_TTL=300       # 5 minutes between successful fetches
USAGE_ERROR_TTL=120       # 2 minutes after errors before retrying
USAGE_BACKOFF_TTL=600     # 10 minutes after rate-limit (429) before retrying
USAGE_STALE_MAX=86400     # serve stale data up to 24 hours (old data >> no data)
USAGE_LOCK_TTL=15         # lock expires after 15s (curl timeout is 5s)
h5_pct=""
d7_pct=""

# Acquire lock to prevent multiple sessions from fetching simultaneously.
# Uses mkdir for atomic lock creation (works across all shells/platforms).
# Returns 0 if lock acquired, 1 if another session is already fetching.
acquire_lock() {
    if mkdir "$USAGE_LOCK" 2>/dev/null; then
        echo $$ > "$USAGE_LOCK/pid"
        return 0
    fi
    # Check for stale lock (process died or took too long)
    if [ -f "$USAGE_LOCK/pid" ]; then
        local lock_pid lock_age
        lock_pid=$(cat "$USAGE_LOCK/pid" 2>/dev/null)
        lock_age=0
        if [ -f "$USAGE_LOCK/pid" ]; then
            local lock_mtime
            lock_mtime=$(stat -f %m "$USAGE_LOCK/pid" 2>/dev/null || stat -c %Y "$USAGE_LOCK/pid" 2>/dev/null)
            if [ -n "$lock_mtime" ]; then
                lock_age=$(( $(date +%s) - lock_mtime ))
            fi
        fi
        # Stale lock: owner dead or lock older than LOCK_TTL
        if [ "$lock_age" -ge "$USAGE_LOCK_TTL" ] || { [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; }; then
            rm -rf "$USAGE_LOCK"
            if mkdir "$USAGE_LOCK" 2>/dev/null; then
                echo $$ > "$USAGE_LOCK/pid"
                return 0
            fi
        fi
    fi
    return 1
}

release_lock() {
    rm -rf "$USAGE_LOCK"
}

fetch_usage_api() {
    local access_token
    # Try keychain first, then credentials file
    local token
    token=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$token" ]; then
        access_token=$(echo "$token" | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
    fi
    if [ -z "$access_token" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
        access_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
    fi
    [ -z "$access_token" ] && return 1
    local resp http_code
    resp=$(curl -s --max-time 5 -w '\n%{http_code}' -H "Authorization: Bearer $access_token" -H "anthropic-beta: oauth-2025-04-20" "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || {
        # Network error — write error cache to avoid rapid retries
        local now; now=$(date +%s)
        [ -f "$USAGE_CACHE" ] && jq --argjson err_ts "$now" '.err_ts = $err_ts' "$USAGE_CACHE" > "${USAGE_CACHE}.tmp" 2>/dev/null && mv "${USAGE_CACHE}.tmp" "$USAGE_CACHE"
        return 1
    }
    http_code=$(echo "$resp" | tail -1)
    resp=$(echo "$resp" | sed '$d')
    # Handle rate-limiting: mark backoff timestamp
    if [ "$http_code" = "429" ]; then
        local now; now=$(date +%s)
        if [ -f "$USAGE_CACHE" ]; then
            jq --argjson bt "$now" '.backoff_ts = $bt' "$USAGE_CACHE" > "${USAGE_CACHE}.tmp" 2>/dev/null && mv "${USAGE_CACHE}.tmp" "$USAGE_CACHE"
        else
            printf '{"ts":0,"h5":0,"d7":0,"backoff_ts":%d}\n' "$now" > "$USAGE_CACHE"
        fi
        return 1
    fi
    [ "$http_code" != "200" ] && return 1
    local h5 d7
    h5=$(echo "$resp" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    d7=$(echo "$resp" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    [ -z "$h5" ] && [ -z "$d7" ] && return 1
    printf '{"ts":%d,"h5":%s,"d7":%s}\n' "$(date +%s)" "${h5:-0}" "${d7:-0}" > "$USAGE_CACHE"
    echo "$h5 $d7"
}

get_usage() {
    local now
    now=$(date +%s)
    # Try cache first
    if [ -f "$USAGE_CACHE" ]; then
        local cached_ts backoff_ts err_ts ttl
        cached_ts=$(jq -r '.ts // 0' "$USAGE_CACHE" 2>/dev/null)
        backoff_ts=$(jq -r '.backoff_ts // 0' "$USAGE_CACHE" 2>/dev/null)
        err_ts=$(jq -r '.err_ts // 0' "$USAGE_CACHE" 2>/dev/null)

        # If in rate-limit backoff, serve stale and don't fetch
        if [ "$backoff_ts" -gt 0 ] 2>/dev/null && [ $((now - backoff_ts)) -lt "$USAGE_BACKOFF_TTL" ]; then
            if [ "$cached_ts" -gt 0 ] 2>/dev/null && [ $((now - cached_ts)) -lt "$USAGE_STALE_MAX" ]; then
                jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
            fi
            return
        fi

        # If in error cooldown, serve stale and don't fetch
        if [ "$err_ts" -gt 0 ] 2>/dev/null && [ $((now - err_ts)) -lt "$USAGE_ERROR_TTL" ]; then
            if [ "$cached_ts" -gt 0 ] 2>/dev/null && [ $((now - cached_ts)) -lt "$USAGE_STALE_MAX" ]; then
                jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
            fi
            return
        fi

        # Successful cache still fresh
        if [ $((now - cached_ts)) -lt "$USAGE_CACHE_TTL" ]; then
            jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
            return
        fi
    fi
    # Try to acquire lock — only one session fetches at a time
    if ! acquire_lock; then
        # Another session is fetching; serve stale cache if available
        if [ -f "$USAGE_CACHE" ]; then
            local cached_ts
            cached_ts=$(jq -r '.ts // 0' "$USAGE_CACHE" 2>/dev/null)
            if [ "$cached_ts" -gt 0 ] 2>/dev/null && [ $((now - cached_ts)) -lt "$USAGE_STALE_MAX" ]; then
                jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
            fi
        fi
        return
    fi
    # Re-check cache after acquiring lock (another session may have just refreshed it)
    if [ -f "$USAGE_CACHE" ]; then
        local recheck_ts
        recheck_ts=$(jq -r '.ts // 0' "$USAGE_CACHE" 2>/dev/null)
        if [ $((now - recheck_ts)) -lt "$USAGE_CACHE_TTL" ]; then
            jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
            release_lock
            return
        fi
    fi
    # Fetch fresh (if it fails, use stale cache)
    local result
    result=$(fetch_usage_api 2>/dev/null)
    release_lock
    if [ -n "$result" ]; then
        echo "$result"
    elif [ -f "$USAGE_CACHE" ]; then
        local cached_ts
        cached_ts=$(jq -r '.ts // 0' "$USAGE_CACHE" 2>/dev/null)
        if [ "$cached_ts" -gt 0 ] 2>/dev/null && [ $((now - cached_ts)) -lt "$USAGE_STALE_MAX" ]; then
            jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
        fi
    fi
}

read h5_pct d7_pct < <(get_usage)
h5_pct=${h5_pct:-0}
d7_pct=${d7_pct:-0}

# Build sections: text and bg color pairs
texts=()
bgs=()
fgs=()

# Section 1: Directory (leftmost)
texts+=("$short_dir")
bgs+=($C_DIR)
fgs+=($C_FG)

# Section 2: Context percentage (dynamic color)
if [ -n "$remaining_pct" ] && [ "$remaining_pct" != "null" ]; then
    if (( $(echo "$remaining_pct < 20" | bc -l 2>/dev/null || echo 0) )); then
        texts+=("ctx ${remaining_pct}%!")
        bgs+=($C_CTX_LOW)
        fgs+=(232)
    elif (( $(echo "$remaining_pct < 50" | bc -l 2>/dev/null || echo 0) )); then
        texts+=("ctx ${remaining_pct}%")
        bgs+=($C_CTX_MID)
        fgs+=(232)
    else
        texts+=("ctx ${remaining_pct}%")
        bgs+=($C_CTX_GOOD)
        fgs+=(232)
    fi
fi

# Section 3: 5h/7d Usage (OMC HUD style with threshold colors)
if [ "$h5_pct" != "0" ] || [ "$d7_pct" != "0" ]; then
    h5_disp=$(printf "%.0f" "$h5_pct" 2>/dev/null || echo "0")
    d7_disp=$(printf "%.0f" "$d7_pct" 2>/dev/null || echo "0")
    # Pick segment bg color based on max usage (green <70, yellow 70-90, red >=90)
    max_pct=$h5_disp
    [ "$d7_disp" -gt "$max_pct" ] 2>/dev/null && max_pct=$d7_disp
    if [ "$max_pct" -ge 90 ] 2>/dev/null; then
        usage_bg=$C_CTX_LOW    # red
        usage_fg=232
    elif [ "$max_pct" -ge 70 ] 2>/dev/null; then
        usage_bg=$C_CTX_MID    # yellow
        usage_fg=232
    else
        usage_bg=$C_USAGE      # teal
        usage_fg=$C_FG
    fi
    texts+=("5h:${h5_disp}% wk:${d7_disp}%")
    bgs+=($usage_bg)
    fgs+=($usage_fg)
fi

# Section 4: Model + Version
model_section="$model"
if [ -n "$version" ]; then
    model_section="$model v$version"
fi
texts+=("$model_section")
bgs+=($C_MODEL)
fgs+=($C_FG)

# Section 5: Session cost
if [ "$session_cost" != "0" ] && [ "$session_cost" != "null" ]; then
    cost_formatted=$(printf "\$%.4f" "$session_cost")
    texts+=("$cost_formatted")
    bgs+=($C_COST)
    fgs+=($C_FG)
fi

# Section 6: Tokens breakdown
if [ "$total_tokens" -gt 0 ] 2>/dev/null; then
    in_fmt=$(fmt_tokens "$total_input")
    out_fmt=$(fmt_tokens "$total_output")
    texts+=("${in_fmt}in ${out_fmt}out")
    bgs+=($C_TOKENS)
    fgs+=($C_FG)
fi

# Section 7: Output style (optional)
if [ -n "$output_style" ] && [ "$output_style" != "default" ] && [ "$output_style" != "null" ]; then
    texts+=("$output_style")
    bgs+=($C_STYLE)
    fgs+=($C_FG)
fi

# Section 8: Vim mode (optional)
if [ -n "$vim_mode" ] && [ "$vim_mode" != "null" ]; then
    texts+=("$vim_mode")
    bgs+=($C_VIM)
    fgs+=($C_FG)
fi

# Render Powerline segments
count=${#texts[@]}
for ((i=0; i<count; i++)); do
    cur_bg=${bgs[$i]}
    cur_fg=${fgs[$i]}

    # Segment content
    printf "$(bg "$cur_bg")$(fg "$cur_fg") %s " "${texts[$i]}"

    # Separator arrow
    if [ $((i + 1)) -lt "$count" ]; then
        next_bg=${bgs[$((i + 1))]}
        printf "$(fg "$cur_bg")$(bg "$next_bg")%s" "$SEP"
    else
        printf "$(reset)$(fg "$cur_bg")%s$(reset)" "$SEP"
    fi
done
printf "\n"
