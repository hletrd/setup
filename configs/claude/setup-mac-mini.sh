#!/bin/sh
# Setup Claude Code aliases (c, cb, cbl) and proxy.worv.ai auth token on Mac minis.
# `cb`  routes Claude Code through the self-hosted proxy and pins the model
#       env vars to the gpt-6.0[1m] / gpt-6.0-spark[1m] placeholders so
#       Claude Code renders a 1 M context window.
# `cbl` is the same proxy without the [1m] suffix, for backends whose
#       positional ceiling is much smaller than 1 M (e.g. Kimi-K2.6-NVFP4 at
#       32 K) — keeps Claude Code's local context budget aligned with what
#       the model can actually consume.
# The proxy rewrites every model ID to whichever backend is currently live.
# Usage: ./setup-mac-mini.sh <api_key>
# Example: ./setup-mac-mini.sh YOUR_API_KEY_HERE

set -e

API_KEY="${1:?Usage: $0 <api_key>}"
ZSHRC="$HOME/.zshrc"

if [ ! -f "$ZSHRC" ]; then
    printf "Error: %s not found\n" "$ZSHRC" >&2
    exit 1
fi

# Always create a backup first
cp "$ZSHRC" "$ZSHRC.bak"
printf "Backup saved to %s.bak\n" "$ZSHRC"

# If the cb block already exists, just update the API key in-place
if grep -q 'claude_with_proxy_env' "$ZSHRC"; then
    sed -i '' "s|ANTHROPIC_AUTH_TOKEN=\"[^\"]*\"|ANTHROPIC_AUTH_TOKEN=\"$API_KEY\"|" "$ZSHRC"
    printf "Updated existing proxy API key.\n"
    # Append cbl block if it's missing (idempotent for already-set-up minis)
    if ! grep -q 'claude_with_proxy_env_local' "$ZSHRC"; then
        CBL_BLOCK="
# \`cbl\` = same proxy as \`cb\` but without the [1m] context-window suffix.
# Use this when the live backend's positional ceiling is much smaller than
# 1 M (e.g. Kimi-K2.6-NVFP4 at 32 K) so Claude Code's local context budget
# stays aligned with what the model can actually consume.
claude_with_proxy_env_local() {
    BASH_ENV=\"\" \\
    ENV=\"\" \\
    ANTHROPIC_DEFAULT_HAIKU_MODEL=\"gpt-6.0-spark\" \\
    ANTHROPIC_DEFAULT_SONNET_MODEL=\"gpt-6.0\" \\
    ANTHROPIC_DEFAULT_OPUS_MODEL=\"gpt-6.0\" \\
    ANTHROPIC_AUTH_TOKEN=\"$API_KEY\" \\
    ANTHROPIC_BASE_URL=\"https://proxy.worv.ai\" \\
    API_TIMEOUT_MS=\"3000000\" \\
    command claude --dangerously-skip-permissions \"\$@\"
}
alias cbl=claude_with_proxy_env_local
"
        printf '%s' "$CBL_BLOCK" >> "$ZSHRC"
        printf "Appended cbl alias.\n"
    fi
else
    # Block doesn't exist yet — append before Zoxide or at end
    CLAUDE_BLOCK='# Claude Code aliases
alias claude="claude --dangerously-skip-permissions"
alias c="claude"

# Self-hosted backend via proxy.worv.ai. Single consolidated alias `cb`
# routes Claude Code to whichever model is currently live on the proxy
# (1 M native context). The proxy rewrites every model ID to the live
# served-model-name; the [1m] suffix tells Claude Code to render a 1 M
# context window.
claude_with_proxy_env() {
    ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-6.0-spark[1m]" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-6.0[1m]" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-6.0[1m]" \
    ANTHROPIC_AUTH_TOKEN="__API_KEY__" \
    ANTHROPIC_BASE_URL="https://proxy.worv.ai" \
    API_TIMEOUT_MS="3000000" \
    CLAUDE_CODE_ATTRIBUTION_HEADER="0" \
    command claude --dangerously-skip-permissions "$@"
}
alias cb=claude_with_proxy_env

# `cbl` = same proxy, but without the [1m] context-window suffix. Use this
# when the live backend ships a smaller positional ceiling than 1 M (e.g.
# Kimi-K2.6-NVFP4 at 32 K) so Claude Code'"'"'s local context budget tracks
# what the model can actually consume.
claude_with_proxy_env_local() {
    ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-6.0-spark" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-6.0" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-6.0" \
    ANTHROPIC_AUTH_TOKEN="__API_KEY__" \
    ANTHROPIC_BASE_URL="https://proxy.worv.ai" \
    API_TIMEOUT_MS="3000000" \
    CLAUDE_CODE_ATTRIBUTION_HEADER="0" \
    command claude --dangerously-skip-permissions "$@"
}
alias cbl=claude_with_proxy_env_local'

    # Substitute the actual key
    CLAUDE_BLOCK=$(printf '%s' "$CLAUDE_BLOCK" | sed "s|__API_KEY__|$API_KEY|")

    # Write block to temp file
    BLOCKFILE=$(mktemp)
    trap 'rm -f "$BLOCKFILE"' EXIT
    printf '%s\n' "$CLAUDE_BLOCK" > "$BLOCKFILE"

    if grep -q '^# Zoxide' "$ZSHRC"; then
        # Insert before Zoxide section
        OUTFILE=$(mktemp)
        trap 'rm -f "$BLOCKFILE" "$OUTFILE"' EXIT
        while IFS= read -r line; do
            case "$line" in
                "# Zoxide"*)
                    cat "$BLOCKFILE" >> "$OUTFILE"
                    printf '\n' >> "$OUTFILE"
                    ;;
            esac
            printf '%s\n' "$line" >> "$OUTFILE"
        done < "$ZSHRC"
        cp "$OUTFILE" "$ZSHRC"
    else
        # Append at end
        printf '\n' >> "$ZSHRC"
        cat "$BLOCKFILE" >> "$ZSHRC"
        printf '\n' >> "$ZSHRC"
    fi
    printf "Inserted Claude Code + proxy block.\n"
fi

# Verify the result has more than just the block
LINE_COUNT=$(wc -l < "$ZSHRC" | tr -d ' ')
if [ "$LINE_COUNT" -lt 20 ]; then
    printf "WARNING: .zshrc looks too short (%s lines). Restoring backup.\n" "$LINE_COUNT" >&2
    cp "$ZSHRC.bak" "$ZSHRC"
    exit 1
fi

printf "Done. Run 'source ~/.zshrc' or open a new shell.\n"
printf "Aliases set: c=claude, cb=claude_with_proxy_env, cbl=claude_with_proxy_env_local (proxy.worv.ai)\n"
