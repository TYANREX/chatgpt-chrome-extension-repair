# Codex Browser Plugin Cache Repair for Windows

English | [简体中文](README.zh-CN.md)

An idempotent repair script for a Codex desktop app issue where the bundled
Chrome/browser plugin version is newer than the version targeted by the local
plugin cache.

## What it does

- Detects the Chrome and browser plugin versions bundled with the installed
  Codex desktop app.
- Compares them with `%USERPROFILE%\.codex\plugins\cache\openai-bundled`.
- Copies the official bundled plugins when the cache is missing or outdated.
- Backs up existing `latest` junctions before replacing them.
- Recreates the `latest` junctions using the bundled plugin version.
- Verifies the official and cached hashes of `plugin.json` and
  `browser-client.mjs`.
- Restarts the browser-control helper processes after a repair.
- Prints a final validation table covering the installed Codex version,
  bundled plugin version, both cache targets, and native-host registration.
- Warns when an older Codex or Chrome helper process is still running and a
  full application restart is required.

The script does **not** edit `browser-client.mjs` or the native messaging host.

## Usage

Download both files, keep them in the same folder, and double-click:

```text
Repair-CodexBrowserPlugins.cmd
```

Alternatively, run the PowerShell script directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Repair-CodexBrowserPlugins.ps1
```

After a repair, fully restart Codex and Chrome before testing browser control.

## Requirements

- Windows
- The OpenAI Codex desktop app installed through its Windows package
- PowerShell 5.1 or later

## Safety

The script validates that its target is inside the Codex plugin cache, keeps
the previous `latest` junction as a timestamped backup, and hashes critical
files before activating the new cache version.

