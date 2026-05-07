#!/bin/bash
# Substitute placeholders + copy skills into ~/.claude/skills/
#
# Edit the values below before running.

set -euo pipefail

# ---- EDIT THESE ----
USER_NAME="Jane"
USER_EMAIL="j.doe@acme.com"
ORG_DOMAIN="acme.com"
VAULT_PATH="$HOME/MyVault"
SLACK_USER_ID="U0XXXXXXX"
ATLASSIAN_HOST="acme.atlassian.net"
JIRA_BOT_EMAIL="jira@acme.atlassian.net"
HOME_USER="$(whoami)"
# --------------------

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Substituting placeholders…"
cp -R "$REPO_ROOT/skills" "$TMP_DIR/skills"

# sed -i syntax differs between macOS and GNU. Use a portable approach.
SED_INPLACE=(-i '')
case "$(uname -s)" in
  Linux) SED_INPLACE=(-i) ;;
esac

find "$TMP_DIR/skills" -type f \( -name "*.md" -o -name "*.sh" -o -name "*.lua" \) | while read -r f; do
  sed "${SED_INPLACE[@]}" \
    -e "s|<<USER_NAME>>|$USER_NAME|g" \
    -e "s|<<USER_EMAIL>>|$USER_EMAIL|g" \
    -e "s|<<ORG_DOMAIN>>|$ORG_DOMAIN|g" \
    -e "s|<<VAULT_PATH>>|$VAULT_PATH|g" \
    -e "s|<<SLACK_USER_ID>>|$SLACK_USER_ID|g" \
    -e "s|<<ATLASSIAN_HOST>>|$ATLASSIAN_HOST|g" \
    -e "s|<<JIRA_BOT_EMAIL>>|$JIRA_BOT_EMAIL|g" \
    -e "s|<<HOME_USER>>|$HOME_USER|g" \
    "$f"
done

echo "Copying skills into $SKILLS_DST…"
mkdir -p "$SKILLS_DST"
for skill_dir in "$TMP_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  if [ -d "$SKILLS_DST/$skill_name" ]; then
    echo "  ⚠️  $skill_name already exists; skipping (move it aside if you want to overwrite)"
    continue
  fi
  cp -R "$skill_dir" "$SKILLS_DST/$skill_name"
  echo "  ✅ installed: /$skill_name"
done

cat <<EOF

Done.

Next steps:
  1. Verify a skill loaded: ls ~/.claude/skills/
  2. Try the easiest one: /daily-notes
  3. Adjust org-specific examples (teammate names, calendar filters) per SETUP.md Step 3
EOF
