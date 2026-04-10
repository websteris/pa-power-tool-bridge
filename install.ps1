# Power Automate Power Tool - CLI Bridge Installer (Windows)
# Downloads and installs the native messaging host that bridges the extension
# to local files for scripting and AI integration.
#
# One-liner install:
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/websteris/pa-power-tool-extension/main/install.ps1 | iex"

param([string]$ExtensionId = "")

$Repo        = "https://raw.githubusercontent.com/websteris/pa-power-tool-extension/main"
$InstallDir  = "$env:LOCALAPPDATA\pa-power-tool"
$HostName    = "com.powerautomate.powertool.host"
$HostCjs     = "$InstallDir\host.cjs"
$HostBat     = "$InstallDir\host.bat"
$ManifestPath = "$InstallDir\manifest.json"

# ── Extension ID ──────────────────────────────────────────────────────────────

if (-not $ExtensionId) {
  Write-Host ""
  Write-Host "Find your extension ID at chrome://extensions or edge://extensions"
  Write-Host "(enable Developer mode and look for the ID below the extension name)"
  Write-Host ""
  $ExtensionId = Read-Host "Enter extension ID"
}

if (-not $ExtensionId) {
  Write-Error "Extension ID is required."
  exit 1
}

if ($ExtensionId -notmatch '^[a-z]{32}$') {
  Write-Warning "Extension ID '$ExtensionId' looks unusual (expected 32 lowercase letters)."
  Write-Warning "Verify it at chrome://extensions or edge://extensions with Developer mode on."
  $confirm = Read-Host "Continue anyway? (y/N)"
  if ($confirm -notmatch '^[Yy]') { exit 1 }
}

# ── Check Node.js ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Checking requirements..." -ForegroundColor Cyan

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
  try {
    $nodeVersion = & node --version 2>$null
    $major = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($major -lt 16) {
      Write-Warning "  Node.js $nodeVersion found — v16 or later is recommended."
      Write-Warning "  Download a newer version from: https://nodejs.org"
    } else {
      Write-Host "  Node.js $nodeVersion  OK  ($($nodeCmd.Source))" -ForegroundColor Green
    }
  } catch {
    Write-Host "  Node.js found at $($nodeCmd.Source)"
  }
} else {
  Write-Host ""
  Write-Warning "  Node.js not found on current PATH."
  Write-Warning "  host.bat will search common install locations at runtime."
  Write-Warning "  If the bridge fails to connect, install Node.js from: https://nodejs.org"
}

# ── Create install directory ──────────────────────────────────────────────────

Write-Host ""
Write-Host "Installing to: $InstallDir" -ForegroundColor Cyan

if (-not (Test-Path $InstallDir)) {
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# ── Download host.cjs ─────────────────────────────────────────────────────────

Write-Host "  Downloading host.cjs..."
try {
  Invoke-WebRequest -Uri "$Repo/host.cjs" -OutFile $HostCjs -UseBasicParsing -ErrorAction Stop
  Write-Host "  Downloaded:  $HostCjs" -ForegroundColor Green
} catch {
  Write-Error "Failed to download host.cjs: $_"
  exit 1
}

# ── Write host.bat ────────────────────────────────────────────────────────────

$hostBatContent = @'
@echo off
:: Power Automate Power Tool - Native Messaging Host launcher (Windows)
:: Searches for node.exe in multiple locations since Chrome/Edge may not
:: inherit the full user PATH when launching the host process.

set "HOST_JS=%~dp0host.cjs"

where node >nul 2>nul
if %errorlevel% equ 0 ( node "%HOST_JS%" & exit /b %errorlevel% )

if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" (
  "%LOCALAPPDATA%\Programs\nodejs\node.exe" "%HOST_JS%"
  exit /b %errorlevel%
)

if exist "%ProgramFiles%\nodejs\node.exe" (
  "%ProgramFiles%\nodejs\node.exe" "%HOST_JS%"
  exit /b %errorlevel%
)
if exist "%ProgramFiles(x86)%\nodejs\node.exe" (
  "%ProgramFiles(x86)%\nodejs\node.exe" "%HOST_JS%"
  exit /b %errorlevel%
)

if exist "%APPDATA%\nvm" (
  for /f "delims=" %%v in ('dir /b /o-n "%APPDATA%\nvm" 2^>nul') do (
    if exist "%APPDATA%\nvm\%%v\node.exe" (
      "%APPDATA%\nvm\%%v\node.exe" "%HOST_JS%"
      exit /b %errorlevel%
    )
  )
)

if exist "%LOCALAPPDATA%\Volta\bin\node.exe" (
  "%LOCALAPPDATA%\Volta\bin\node.exe" "%HOST_JS%"
  exit /b %errorlevel%
)

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "& { $n = Get-Command node -ErrorAction SilentlyContinue; if ($n) { $n.Source } }"`) do (
  if exist "%%i" (
    "%%i" "%HOST_JS%"
    exit /b %errorlevel%
  )
)

echo node.exe not found. Install Node.js from https://nodejs.org 1>&2
exit /b 1
'@

$hostBatContent | Set-Content $HostBat -Encoding ASCII
Write-Host "  Created:     $HostBat" -ForegroundColor Green

# ── Write native messaging manifest ──────────────────────────────────────────

$manifest = [ordered]@{
  name            = $HostName
  description     = "Power Automate Power Tool native messaging host"
  path            = $HostBat
  type            = "stdio"
  allowed_origins = @("chrome-extension://$ExtensionId/")
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
Write-Host "  Created:     $ManifestPath" -ForegroundColor Green

# ── Register in Windows Registry for Chrome and Edge ─────────────────────────

$regPaths = @(
  "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName",
  "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\$HostName"
)

foreach ($rp in $regPaths) {
  $parent = Split-Path $rp
  if (-not (Test-Path $parent)) { New-Item -Path $parent -Force | Out-Null }
  New-Item -Path $rp -Force | Out-Null
  Set-ItemProperty -Path $rp -Name "(default)" -Value $ManifestPath
  Write-Host "  Registered:  $rp" -ForegroundColor Green
}

# ── Done ──────────────────────────────────────────────────────────────────────

$tempPath = Join-Path $env:TEMP "pa-power-tool"
Write-Host ""
Write-Host "CLI Bridge installed successfully." -ForegroundColor Green
Write-Host "The extension will connect automatically within a few seconds."
Write-Host ""
Write-Host "Bridge files will be written to:"
Write-Host "  $tempPath"
Write-Host ""
Write-Host "  status.json       - live state + any errors"
Write-Host "  current-flow.json - full flow definition"
Write-Host "  commands.json     - write here to send commands to the extension"
Write-Host ""
