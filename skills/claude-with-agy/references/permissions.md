# Headless permissions (the thing that breaks most runs)

In `-p` mode agy cannot ask you anything. Any tool call that would need approval is **auto-denied and the whole run aborts** (exit code still 0). So you must pre-approve exactly what the task needs.

## Where

User-level settings file (Windows):

```
C:\Users\<you>\.gemini\antigravity-cli\settings.json
```

```json
{
  "permissions": {
    "allow": [
      "command(git status)",
      "command(git diff --stat)",
      "command(npx tsc --noEmit)",
      "mcp(my-server/some_read_tool)"
    ]
  }
}
```

## Syntax learned the hard way

- Shell commands: `command(<exact string>)`. **Exact match**: not a prefix, not a glob. Any extra argument, `cd x;` prefix, `&&`, `|`, `2>&1`, `Tee-Object`, redirect or env prefix makes it a *different* command → denied → run aborted.
- MCP tools: `mcp(<server>/<tool>)`, one rule per tool. A tool you did not list (including write-capable ones like refactor/apply tools) aborts the run when the model happens to call it. Either list every read-only tool you want, or tell the agent in the prompt "use no MCP tools at all".
- Built-in file tools (view/read file, grep/search tool, replace/write file, list dir) do not need rules in `accept-edits` mode.
- Do not allow git write commands. Allow only read-only git (`git status`, `git status --short`, `git diff`, `git diff --stat`).
- The test command is the most important rule: copy it character by character from what you will put in the prompt, e.g.
  `command(& "C:\path\to\python.exe" -m pytest -q -p no:cacheprovider)`.
  Run it with the working directory set through the tool's cwd parameter, never with `cd`.
- Rules that never matched anything (e.g. `conda run -n env pytest …`) are dead weight; remove them.

## Claude Code side

- Claude Code's auto-mode classifier may block reading the agy config through a shell (`cat`, `type`). Use the **Read tool** on the settings file instead, and ask the user before editing it (it is their global config).
- Do not try to evade the classifier (wrapper scripts that inject `--dangerously-skip-permissions`, etc.). Allow-rules are the sanctioned path.

## Prompt-side discipline that avoids denials

Gemini Flash habitually reaches for shell search (`grep`, `findstr`, `Get-Content`, `ls`, `cat`) and chains commands. Each one is a denial → abort. The task header must say:

1. Only these shell commands exist: *(list them verbatim)*. Run each alone, exactly as written.
2. For reading/searching use the internal file tools; no shell for that.
3. Never chain, pipe, redirect or prefix (`cd`, `;`, `&&`, `|`, `2>&1`).
4. No background tasks, no task-manager tool; run commands in the foreground and wait.
5. No MCP tools (or only the listed ones).
