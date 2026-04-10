# Power Automate Power Tool

A professional JSON editor for Microsoft Power Automate flows, built as a browser extension for Chrome and Edge.

Edit flow definitions with Monaco (VS Code's editor), save changes live via the Power Automate API, and automate your workflow with the CLI Bridge.

---

## Install the Extension

> **Coming soon** — submission to the Chrome Web Store and Microsoft Edge Add-ons store is in progress.

---

## CLI Bridge

The CLI Bridge is a native messaging host that lets scripts, Claude, and other tools read and write your flow definitions without copy-paste.

Once installed, files are written to a local temp directory:

| File | Description |
|---|---|
| `current-flow.json` | Full flow definition, updated on open and save |
| `status.json` | Live state, errors, last saved time |
| `commands.json` | Write a command here to control the extension |

### Install

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/websteris/pa-power-tool-extension/main/install.ps1 | iex"
```

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/websteris/pa-power-tool-extension/main/install.sh | bash -s <extension-id>
```

Your extension ID is shown in the extension's Help panel and on the Setup page (`chrome://extensions` or `edge://extensions` with Developer mode enabled).

Full installation guide: **[websteris.github.io/pa-power-tool-extension/install.html](https://websteris.github.io/pa-power-tool-extension/install.html)**

### Send commands

**PowerShell:**
```powershell
'{"command":"save"}' | Set-Content "$env:TEMP\pa-power-tool\commands.json"
```

**bash / zsh:**
```bash
echo '{"command":"save"}' > "$TMPDIR/pa-power-tool/commands.json"
```

**Available commands:**

| Command | Description |
|---|---|
| `getJson` | Write the current editor content to `current-flow.json` |
| `save` | Save the current flow to Power Automate |
| `run` | Run with last inputs |
| `reload` | Reload flow definition from the server |
| `setJson` | Replace the editor content (include `"json"` field) |
| `setJsonAndSave` | Replace content and immediately save |

---

## Requirements

- Node.js 16+ (for the CLI Bridge)
- Chrome 114+ or Microsoft Edge 114+

---

## License

[MIT](./LICENSE)
