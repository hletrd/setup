#!/bin/sh
# Setup Claude Code aliases (c, cg) and API key on Mac minis
# Usage: ./setup-mac-mini.sh <api_key>
# Example: ./setup-mac-mini.sh YOUR_API_KEY_HERE

set -e

API_KEY="${1:?Usage: $0 <api_key>}"
ZSHRC="$HOME/.zshrc"

if [ ! -f "$ZSHRC" ]; then
    printf "Error: %s not found\n" "$ZSHRC" >&2
    exit 1
fi

CLAUDE_BLOCK="# Claude Code aliases
alias claude=\"claude --dangerously-skip-permissions\"
alias c=\"claude\"

# GLM-based Claude Code
claude_with_glm_env() {
    ANTHROPIC_DEFAULT_HAIKU_MODEL=\"glm-4.7\" \\
    ANTHROPIC_DEFAULT_SONNET_MODEL=\"glm-5.1\" \\
    ANTHROPIC_DEFAULT_OPUS_MODEL=\"glm-5.1\" \\
    ANTHROPIC_AUTH_TOKEN=\"$API_KEY\" \\
    ANTHROPIC_BASE_URL=\"https://api.z.ai/api/anthropic\" \\
    API_TIMEOUT_MS=\"3000000\" \\
    command claude --dangerously-skip-permissions \"\$@\"
}
alias claude-glm='claude_with_glm_env'
alias cg='claude_with_glm_env'"

# Remove any existing claude alias/function block
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Remove old claude_with_glm_env function block and related aliases
sed '/^# GLM-based Claude Code/,/^}/d' "$ZSHRC" | \
    sed '/^alias claude=/d; /^alias c="claude"/d; /^alias claude-glm=/d; /^alias cg=/d' | \
    sed '/^# Claude Code aliases/d' > "$TMPFILE"

# Find insertion point: before "# Zoxide" section, or before last line
if grep -q '^# Zoxide' "$TMPFILE"; then
    # Insert before Zoxide block
    awk -v block="$CLAUDE_BLOCK" '
        /^# Zoxide/ { print block; print ""; }
        { print }
    ' "$TMPFILE" > "$ZSHRC"
else
    # Append at end
    printf '\n%s\n' "$CLAUDE_BLOCK" >> "$TMPFILE"
    cp "$TMPFILE" "$ZSHRC"
fi

printf "Done. Run 'source ~/.zshrc' or open a new shell.\n"
printf "Aliases set: c=claude, cg=claude-glm (with GLM API)\n"
