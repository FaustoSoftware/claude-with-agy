#!/usr/bin/env bash
# One-time setup so headless agy can open its own Chrome (chrome-devtools MCP).
# Registers the MCP server and PRINTS the allow-rules to paste into settings.json.
# It does not edit settings.json: permissions are the user's decision.
#
# Usage: setup_agy_browser.sh [viewport]     (default 1920x1080)

set -eu
VIEWPORT="${1:-1920x1080}"
PROFILE="${AGY_BROWSER_PROFILE:-$HOME/.gemini/antigravity-browser-profile}"

agy mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest \
  --userDataDir="$PROFILE" --viewport="$VIEWPORT" --no-usage-statistics

cat <<EOF

Registered. Now add these lines to "permissions.allow" in
  $HOME/.gemini/antigravity-cli/settings.json
(mind the commas):

      "mcp(chrome-devtools/list_pages)",
      "mcp(chrome-devtools/new_page)",
      "mcp(chrome-devtools/navigate_page)",
      "mcp(chrome-devtools/take_screenshot)",
      "mcp(chrome-devtools/take_snapshot)",
      "mcp(chrome-devtools/list_console_messages)",
      "execute_url(localhost)",
      "mcp(chrome-devtools/click)",
      "mcp(chrome-devtools/fill)",
      "mcp(chrome-devtools/wait_for)"

click/fill/wait_for let agy CHANGE DATA in the app under test: use test data only.

Add "--headless" to the server args (agy mcp add again) to avoid a visible window.
Remove with: agy mcp remove chrome-devtools
EOF
