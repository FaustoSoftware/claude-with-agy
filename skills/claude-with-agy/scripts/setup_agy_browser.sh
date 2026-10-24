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
      "mcp(chrome-devtools/select_page)",
      "mcp(chrome-devtools/close_page)",
      "mcp(chrome-devtools/navigate_page)",
      "mcp(chrome-devtools/wait_for)",
      "mcp(chrome-devtools/take_screenshot)",
      "mcp(chrome-devtools/take_snapshot)",
      "mcp(chrome-devtools/list_console_messages)",
      "mcp(chrome-devtools/get_console_message)",
      "mcp(chrome-devtools/list_network_requests)",
      "mcp(chrome-devtools/get_network_request)",
      "mcp(chrome-devtools/get_css_styles)",
      "mcp(chrome-devtools/click)",
      "mcp(chrome-devtools/hover)",
      "mcp(chrome-devtools/press_key)",
      "mcp(chrome-devtools/type_text)",
      "mcp(chrome-devtools/fill)",
      "mcp(chrome-devtools/fill_form)",
      "mcp(chrome-devtools/handle_dialog)",
      "mcp(chrome-devtools/drag)",
      "mcp(chrome-devtools/resize_page)",
      "mcp(chrome-devtools/emulate)",
      "mcp(chrome-devtools/performance_start_trace)",
      "mcp(chrome-devtools/performance_stop_trace)",
      "mcp(chrome-devtools/performance_analyze_insight)",
      "mcp(chrome-devtools/lighthouse_audit)",
      "mcp(chrome-devtools/screencast_start)",
      "mcp(chrome-devtools/screencast_stop)",
      "execute_url(localhost)",
      "execute_url(127.0.0.1)"

The action tools (click, press_key, type_text, fill...) let agy CHANGE DATA in the app under test: use test data only.
Not included on purpose (arbitrary JS / file upload); add only if a task needs them:
      "mcp(chrome-devtools/evaluate_script)",
      "mcp(chrome-devtools/upload_file)"

Add "--headless" to the server args (agy mcp add again) to avoid a visible window.
Remove with: agy mcp remove chrome-devtools
EOF
