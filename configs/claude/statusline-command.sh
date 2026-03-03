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

# 5h/7d rolling usage from usage-parser-cache
CACHE_FILE="$HOME/.claude/.usage-parser-cache.json"
usage_5h=0
usage_7d=0
if [ -f "$CACHE_FILE" ]; then
    now=$(date +%s)
    h5_cutoff=$((now - 18000))
    d7_cutoff=$((now - 604800))
    read usage_5h usage_7d < <(jq -r --argjson h5 "$h5_cutoff" --argjson d7 "$d7_cutoff" '
        [.files | to_entries[] | {mtime: .value.mtime, out: ([.value.models | to_entries[]? | .value.outputTokens // 0] | add // 0)}] |
        reduce .[] as $e ({h5: 0, d7: 0};
            if $e.mtime > $d7 then
                .d7 += $e.out |
                if $e.mtime > $h5 then .h5 += $e.out else . end
            else . end
        ) | "\(.h5) \(.d7)"
    ' "$CACHE_FILE" 2>/dev/null)
    usage_5h=${usage_5h:-0}
    usage_7d=${usage_7d:-0}
fi

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

# Section 3: 5h/7d Usage
if [ "$usage_5h" -gt 0 ] 2>/dev/null || [ "$usage_7d" -gt 0 ] 2>/dev/null; then
    h5_fmt=$(fmt_tokens "$usage_5h")
    d7_fmt=$(fmt_tokens "$usage_7d")
    texts+=("5h ${h5_fmt} 7d ${d7_fmt}")
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
