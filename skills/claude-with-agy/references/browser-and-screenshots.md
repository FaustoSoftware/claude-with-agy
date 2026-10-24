# Browser, screenshots and UI checks with agy

**Status: verified end to end** with `agy -p` + `chrome-devtools-mcp` against a local Vite app: agy navigated, captured a 1920x1080 PNG, read the console, and its description matched the screenshot when checked by hand. Model used: `gemini-3.8-flash-low`.

## What does NOT work in `-p`

- agy's built-in browser tools (`open_browser_url`, `capture_browser_screenshot`, …) are listed in the `init` event but "not registered" in headless runs. The model falls back to reading source files, exit `0`.
- `read_url_content` is unavailable too.
- `/browser` is an interactive command. It starts a subagent that runs `chrome-devtools-mcp` with a forced `--autoConnect`, i.e. it **attaches to your own Chrome** (144+, remote debugging enabled at `chrome://inspect/#remote-debugging`). It cannot be configured (upstream issue google-antigravity/antigravity-cli#1217). Do not enable remote debugging on the Chrome where you are logged in just for this.

## How the Antigravity IDE does it (for reference)

Per a third-party reverse-engineering write-up (one Mac, preview build; not official): a normal Chrome launched with `--remote-debugging-port=9222` and a dedicated `--user-data-dir=~/.gemini/antigravity-browser-profile`, plus a bridge extension. Official docs only confirm "separate Chrome profile".

## Replicating it in the CLI: own MCP server, own Chrome

`chrome-devtools-mcp` **without** `--autoConnect`/`--browserUrl` launches its own Chrome with a persistent profile separate from your daily one (`--userDataDir`; `--isolated` = throw-away profile). Register it once:

```bash
agy mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest \
  --userDataDir=C:/Users/<you>/.gemini/antigravity-browser-profile \
  --viewport=1920x1080 --no-usage-statistics
```

Add `--headless` if you do not want a visible window. Remove with `agy mcp remove chrome-devtools`.

### Permissions (required, exact-match)

Headless mode auto-denies MCP tools that are not allow-listed. Add to `permissions.allow` in `C:\Users\<you>\.gemini\antigravity-cli\settings.json` (the run output names the exact denied tool, e.g. `mcp(chrome-devtools/list_pages)`):

```json
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
```

`execute_url(localhost)` is a separate permission: `navigate_page` is denied without it (found by testing; the denial message names it). It is per host, so it covers any port on localhost; add one per other host you need.

**`click`, `fill`, `press_key` and `wait_for` are required in practice** to navigate a real app (menus, tabs, forms, keyboard). They let agy **change data in the app under test** (vote, submit, delete): use test data only, and say in the prompt which buttons it may press and which not. Verified once: a read-only flow (home → click "Tablero" → `wait_for` → click first card → snapshot/screenshot, 2 clicks, 2 `wait_for`, exit 0) worked with `gemini-3.8-flash-medium` in ~2-3 min. It clicked the first card, not the "Ver caso" link it was told to use: prompts for flows need explicit targets.

### Tools covered, and the two that are kept out

The list above covers every `chrome-devtools` tool in its [tool reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md) except two. An agent that reaches for a tool that is not allow-listed gets it auto-denied and the whole run aborts (this happened with `press_key` before it was listed).

| Group | Tools | Risk |
|---|---|---|
| Pages | `list_pages`, `new_page`, `select_page`, `close_page`, `navigate_page`, `wait_for` | low |
| Observe | `take_screenshot`, `take_snapshot`, `list_console_messages`, `get_console_message`, `list_network_requests`, `get_network_request`, `get_css_styles` | low (network/console may show tokens or data of the app under test) |
| Act | `click`, `hover`, `press_key`, `type_text`, `fill`, `fill_form`, `handle_dialog`, `drag` | **can change data** in the app under test: test data only |
| Viewport | `resize_page`, `emulate` | low |
| Heavy | `performance_*`, `lighthouse_audit`, `screencast_*` | costly in tokens/time: ask for them explicitly |

**High risk, not in the main list** — add only for a task that truly needs them:

```json
"mcp(chrome-devtools/evaluate_script)",
"mcp(chrome-devtools/upload_file)"
```

`evaluate_script` runs arbitrary JavaScript inside the page (can read storage, cookies of that profile, call internal APIs); `upload_file` sends local files to the page. Clicks and typing do not need either.

A new host needs its own `execute_url(<host>)`. If a tool you did not expect is denied, the output names the exact rule (e.g. `mcp(chrome-devtools/press_key)`); add it only if you agree.

**Installing the skill does not add these.** `npx skills add` only copies skill files; it never edits agy's settings or MCP config. The user runs the registration and adds the rules once (`scripts/setup_agy_browser.sh` prints both). Claude Code may also be blocked by its own auto-mode guard from editing agy's `settings.json` — then hand the user the lines; do not work around the guard.

## Prompt to use

Narrow, one page per task: "Use the chrome-devtools MCP server: `navigate_page` to <url>, `take_screenshot` (report the saved path), `list_console_messages`. Report what you see and any console errors. Do not use run_command." Make sure the dev server is up first (`curl -s -o /dev/null -w %{http_code} http://localhost:5173/`).

## Fallback without MCP: Chrome headless via an allow-listed command

Works by hand (verified); one exact rule per URL/path. PowerShell does not wait for `chrome.exe`, so use `Start-Process -Wait`, absolute paths and a dedicated profile:

```powershell
$p=(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe').'(Default)'; Start-Process -Wait -FilePath $p -ArgumentList '--headless=new','--user-data-dir=C:\Users\<you>\.gemini\antigravity-browser-profile','--screenshot=C:\Users\<you>\.gemini\antigravity-shots\shot.png','--window-size=1920,1080','--virtual-time-budget=5000','--disable-gpu','http://localhost:5173/'; Test-Path 'C:\Users\<you>\.gemini\antigravity-shots\shot.png'
```

A version without `-Wait` (`& $chromePath ...`) ran without denial under agy but produced no file.

## Using Gemini Flash as the vision analyst (verified)

Claude can read images itself (the `Read` tool on a PNG shows it), but every image costs Claude tokens. Gemini Flash is multimodal, so agy can do the first visual pass and Claude only reads the result.

Checked once with a 1920x1080 screenshot: asked agy to open the PNG with its file tool (`read_file`, ~30k input tokens, one turn) and answer only from what it sees. It correctly reported a blue button, a pale-pink card, a floating bottom nav dock overlapping the content and a grey progress bar — all confirmed by Claude looking at the same image. Colors and overlap are not in the DOM text, so this was real vision, not the accessibility snapshot.

Suggested split:
- **agy:** navigate, click through, capture, describe layout/colors/overlaps/obvious defects, read the console, list differences against a short expected checklist written by Claude.
- **Claude:** reads the *report*; opens the PNG itself only for what matters (design decisions, anything the report flags, or when agy's claim looks off). Gemini's description is a claim: it is accurate on content and basic visuals, but do not take its design judgement ("looks good") as verification.
- Ask for observations ("what color / what overlaps / what is truncated"), not opinions.

## Where the screenshot ends up

`take_screenshot` with a `filePath` outside the workspace roots is **rejected** ("workspace roots" security restriction); agy then retries without a path and the image is stored in its own conversation folder:
`C:\Users\<you>\.gemini\antigravity-cli\brain\<conversation_id>\.system_generated\steps\<N>\media_0.png`.
So: do not rely on a custom path; ask agy to report the saved path in its answer (or find the newest `media_*.png` under `brain\<conversation_id>`; the id is in the `result` event). Copy it where you need it, then view it.

## What is verified (and what is not)

- **Full run verified (2026-10):** with the rules above plus `execute_url(localhost)`, agy called `list_pages`, `navigate_page`, `take_screenshot`, `take_snapshot` and `list_console_messages`, answered with the page content and console output, exit `0`, no `denied_actions`. The PNG was 1920x1080 and matched the description.
- Details below were found along the way:

- Verified: Vite answered 200; Chrome headless screenshot by hand (≈164 KB PNG); `agy mcp add` registers the server; agy calls it (`call_mcp_tool` → `chrome-devtools/list_pages`) and is denied until the rules exist.
- **Not verified:** form filling (`fill`), `--headless` mode, other models, and how well Gemini Flash judges *design quality* (it described content accurately, which is not the same).
- Whatever agy says it "saw" is a claim. For design decisions, look at the screenshot yourself (or in Claude's built-in browser) — see `audit-checklist.md`.
