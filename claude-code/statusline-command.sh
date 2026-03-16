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
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
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
USAGE_CACHE_TTL=120  # seconds
h5_pct=""
d7_pct=""

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
    local resp
    resp=$(curl -s --max-time 5 -H "Authorization: Bearer $access_token" -H "anthropic-beta: oauth-2025-04-20" "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || return 1
    local h5 d7
    h5=$(echo "$resp" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    d7=$(echo "$resp" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    [ -z "$h5" ] && [ -z "$d7" ] && return 1
    printf '{"ts":%d,"h5":%s,"d7":%s}\n' "$(date +%s)" "${h5:-0}" "${d7:-0}" > "$USAGE_CACHE"
    echo "$h5 $d7"
}

get_usage() {
    # Try cache first
    if [ -f "$USAGE_CACHE" ]; then
        local cached_ts now
        cached_ts=$(jq -r '.ts // 0' "$USAGE_CACHE" 2>/dev/null)
        now=$(date +%s)
        if [ $((now - cached_ts)) -lt "$USAGE_CACHE_TTL" ]; then
            jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
            return
        fi
    fi
    # Fetch fresh (background-safe: if it fails, use stale cache)
    local result
    result=$(fetch_usage_api 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result"
    elif [ -f "$USAGE_CACHE" ]; then
        jq -r '"\(.h5) \(.d7)"' "$USAGE_CACHE" 2>/dev/null
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

# Section 3: 5h/7d Usage (real percentages from Anthropic API)
if [ "$h5_pct" != "0" ] || [ "$d7_pct" != "0" ]; then
    h5_disp=$(printf "%.0f" "$h5_pct" 2>/dev/null || echo "0")
    d7_disp=$(printf "%.0f" "$d7_pct" 2>/dev/null || echo "0")
    texts+=("5h ${h5_disp}% 7d ${d7_disp}%")
    bgs+=($C_USAGE)
    fgs+=($C_FG)
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
    tot_fmt=$(fmt_tokens "$total_tokens")

    if [ "$cache_read" -gt 0 ] 2>/dev/null; then
        cache_fmt=$(fmt_tokens "$cache_read")
        texts+=("${in_fmt}in ${out_fmt}out ${cache_fmt}cache ${tot_fmt}total")
    else
        texts+=("${in_fmt}in ${out_fmt}out ${tot_fmt}total")
    fi
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
