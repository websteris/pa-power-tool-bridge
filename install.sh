#!/bin/bash
# Power Automate Power Tool - CLI Bridge Installer (macOS/Linux)
# Downloads and installs the native messaging host that bridges the extension
# to local files for scripting and AI integration.
#
# One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/websteris/pa-power-tool-extension/main/install.sh | bash -s <extension-id>

set -e

REPO="https://raw.githubusercontent.com/websteris/pa-power-tool-extension/main"
INSTALL_DIR="$HOME/.local/share/pa-power-tool"
HOST_NAME="com.powerautomate.powertool.host"
HOST_CJS="$INSTALL_DIR/host.cjs"
HOST_SH="$INSTALL_DIR/host.sh"
EXTENSION_ID="${1:-}"

# ── Extension ID ───────────────────────────────────────────────────────────────

if [ -z "$EXTENSION_ID" ]; then
  echo ""
  echo "Find your extension ID at chrome://extensions or edge://extensions"
  echo "(enable Developer mode and look for the ID below the extension name)"
  echo ""
  read -rp "Enter extension ID: " EXTENSION_ID
fi

if [ -z "$EXTENSION_ID" ]; then
  echo "Error: Extension ID is required." >&2
  exit 1
fi

# ── Check Node.js ──────────────────────────────────────────────────────────────

echo ""
echo "Checking requirements..."

if command -v node &>/dev/null; then
  NODE_VERSION=$(node --version 2>/dev/null)
  NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\)\..*/\1/')
  if [ -n "$NODE_MAJOR" ] && [ "$NODE_MAJOR" -lt 16 ] 2>/dev/null; then
    echo "  Warning: Node.js $NODE_VERSION found — v16 or later is recommended."
    echo "  Download a newer version from: https://nodejs.org"
  else
    echo "  Node.js $NODE_VERSION  OK  ($(command -v node))"
  fi
else
  echo "  Warning: Node.js not found on current PATH."
  echo "  host.sh will search common install locations at runtime."
  echo "  If the bridge fails to connect, install Node.js from: https://nodejs.org"
fi

# ── Create install directory ───────────────────────────────────────────────────

echo ""
echo "Installing to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# ── Download host.cjs ──────────────────────────────────────────────────────────

echo "  Downloading host.cjs..."
if command -v curl &>/dev/null; then
  curl -fsSL "$REPO/host.cjs" -o "$HOST_CJS"
elif command -v wget &>/dev/null; then
  wget -q "$REPO/host.cjs" -O "$HOST_CJS"
else
  echo "Error: curl or wget is required." >&2
  exit 1
fi
echo "  Downloaded:  $HOST_CJS"

# ── Write host.sh ──────────────────────────────────────────────────────────────

cat > "$HOST_SH" << 'HOSTEOF'
#!/bin/bash
# Power Automate Power Tool - Native Messaging Host launcher (macOS/Linux)
# Searches for node in multiple locations since Chrome/Edge may not inherit
# the full user PATH when launching the host process.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_JS="$SCRIPT_DIR/host.cjs"

find_node() {
  if command -v node &>/dev/null; then command -v node; return; fi

  local NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh" --no-use 2>/dev/null
    if command -v node &>/dev/null; then command -v node; return; fi
  fi

  for p in /opt/homebrew/bin/node /usr/local/bin/node /usr/bin/node /usr/bin/nodejs; do
    [ -x "$p" ] && echo "$p" && return
  done

  [ -x "$HOME/.volta/bin/node" ] && echo "$HOME/.volta/bin/node" && return

  for p in \
    "$HOME/.local/share/fnm/aliases/default/bin/node" \
    "$HOME/.fnm/aliases/default/bin/node"; do
    [ -x "$p" ] && echo "$p" && return
  done

  [ -f "$HOME/.asdf/shims/node" ] && echo "$HOME/.asdf/shims/node" && return
}

NODE_PATH="$(find_node)"

if [ -z "$NODE_PATH" ]; then
  echo "Error: node not found. Install Node.js from https://nodejs.org" >&2
  exit 1
fi

exec "$NODE_PATH" "$HOST_JS"
HOSTEOF

chmod +x "$HOST_SH"
echo "  Created:     $HOST_SH"

# ── Write native messaging manifest and register ───────────────────────────────

MANIFEST_JSON=$(cat << EOF
{
  "name": "$HOST_NAME",
  "description": "Power Automate Power Tool native messaging host",
  "path": "$HOST_SH",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
EOF
)

install_for_browser() {
  local DIR="$1"
  local BROWSER="$2"
  if [ -d "$(dirname "$DIR")" ]; then
    mkdir -p "$DIR"
    echo "$MANIFEST_JSON" > "$DIR/$HOST_NAME.json"
    echo "  Registered:  $DIR/$HOST_NAME.json ($BROWSER)"
  else
    echo "  Skipped $BROWSER (not installed)"
  fi
}

if [[ "$OSTYPE" == "darwin"* ]]; then
  install_for_browser "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts" "Chrome"
  install_for_browser "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts" "Edge"
  install_for_browser "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts" "Brave"
else
  install_for_browser "$HOME/.config/google-chrome/NativeMessagingHosts" "Chrome"
  install_for_browser "$HOME/.config/microsoft-edge/NativeMessagingHosts" "Edge"
  install_for_browser "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts" "Brave"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

TEMP_PATH="${TMPDIR:-/tmp}/pa-power-tool"

echo ""
echo "CLI Bridge installed successfully."
echo "The extension will connect automatically within a few seconds."
echo ""
echo "Bridge files will be written to:"
echo "  $TEMP_PATH"
echo ""
echo "  status.json       — live state + any errors"
echo "  current-flow.json — full flow definition"
echo "  commands.json     — write here to send commands to the extension"
echo ""
