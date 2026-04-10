#!/usr/bin/env node
// Native Messaging Host for Power Automate Power Tool
// Bridges the Chrome/Edge extension to the local file system.
// Install with the one-liner at: https://websteris.github.io/pa-power-tool-extension/install.html

"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");

const TEMP_DIR = path.join(os.tmpdir(), "pa-power-tool");
const FLOW_FILE = path.join(TEMP_DIR, "current-flow.json");
const COMMAND_FILE = path.join(TEMP_DIR, "commands.json");
const STATUS_FILE = path.join(TEMP_DIR, "status.json");
const LOG_FILE = path.join(TEMP_DIR, "host.log");

// Ensure temp directory exists
if (!fs.existsSync(TEMP_DIR)) {
  fs.mkdirSync(TEMP_DIR, { recursive: true });
}

function log(msg) {
  const line = `${new Date().toISOString()} ${msg}\n`;
  try { fs.appendFileSync(LOG_FILE, line); } catch { /* ignore */ }
}

log(`host started  pid=${process.pid}  node=${process.version}`);

// ── Native Messaging protocol ──────────────────────────────────────────────
// Messages are length-prefixed: 4-byte LE uint32 + JSON payload

// Accumulate stdin bytes; parse complete messages as they arrive.
let accumBuf = Buffer.alloc(0);

process.stdin.on("data", (chunk) => {
  accumBuf = Buffer.concat([accumBuf, chunk]);
  while (true) {
    if (accumBuf.length < 4) break;
    const msgLen = accumBuf.readUInt32LE(0);
    if (accumBuf.length < 4 + msgLen) break;
    const payload = accumBuf.slice(4, 4 + msgLen);
    accumBuf = accumBuf.slice(4 + msgLen);
    try {
      handleMessage(JSON.parse(payload.toString("utf8")));
    } catch {
      // Ignore malformed messages
    }
  }
});

// Exit cleanly when Chrome closes the port (stdin EOF)
process.stdin.on("end", () => {
  log("stdin closed — exiting");
  process.exit(0);
});

// Prevent crashes if stdout closes before we finish writing
process.stdout.on("error", () => {
  log("stdout error — exiting");
  process.exit(0);
});

function sendMessage(msg) {
  const payload = Buffer.from(JSON.stringify(msg), "utf8");
  const header = Buffer.alloc(4);
  header.writeUInt32LE(payload.length, 0);
  process.stdout.write(Buffer.concat([header, payload]));
}

// ── File system ops ────────────────────────────────────────────────────────

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), "utf8");
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

// ── Message handler ────────────────────────────────────────────────────────

function handleMessage(msg) {
  if (!msg) return;
  if (msg.state !== undefined) {
    writeJson(STATUS_FILE, msg);
  }
  if (msg.definition !== undefined) {
    writeJson(FLOW_FILE, msg);
  }
}

// ── Command file watcher — poll every 500ms for script-written commands ───

let lastCommandMtime = 0;

function pollCommands() {
  try {
    const stat = fs.statSync(COMMAND_FILE);
    if (stat.mtimeMs > lastCommandMtime) {
      lastCommandMtime = stat.mtimeMs;
      const cmd = readJson(COMMAND_FILE);
      if (cmd && cmd.command) {
        sendMessage(cmd); // relay to extension
        fs.unlinkSync(COMMAND_FILE); // consume command
      }
    }
  } catch {
    // File doesn't exist yet — that's fine
  }
}

setInterval(pollCommands, 500);

// ── Announce ready — lets the extension settle immediately via onMessage ──
// Small delay so Chrome's port listeners are attached before we write.
setTimeout(() => {
  log("sending ready");
  sendMessage({ type: "ready" });
}, 50);
