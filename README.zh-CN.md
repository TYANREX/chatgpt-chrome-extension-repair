# Codex 浏览器插件缓存修复工具（Windows）

[English](README.md) | 简体中文

这是一个可重复运行的修复脚本，用于解决 Codex 桌面应用已经更新，但本地
Chrome/Browser 插件缓存仍然指向旧版本，导致 Chrome 控制无法连接的问题。

## 功能

- 自动读取当前 Codex 桌面应用附带的 Chrome 和 Browser 插件版本。
- 检查 `%USERPROFILE%\.codex\plugins\cache\openai-bundled` 中的缓存版本。
- 缓存缺失或版本过旧时，从 Codex 安装目录复制官方内置插件。
- 替换前备份原有的 `latest` 目录联接。
- 将 `latest` 联接更新到当前官方插件版本。
- 对 `plugin.json` 和 `browser-client.mjs` 进行 SHA-256 完整性校验。
- 修复后重启浏览器控制辅助进程。
- 输出最终校验表，检查 Codex、插件、缓存和 Native Host 的状态。
- 如果仍有旧版 Codex 或 Chrome 控制进程运行，会明确提示完全重启应用。

脚本不会编辑 `browser-client.mjs`，也不会修改 Native Messaging Host。

## 使用方法

下载以下两个文件，并放在同一个文件夹中：

- `Repair-CodexBrowserPlugins.ps1`
- `Repair-CodexBrowserPlugins.cmd`

双击运行：

```text
Repair-CodexBrowserPlugins.cmd
```

也可以直接运行 PowerShell 脚本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Repair-CodexBrowserPlugins.ps1
```

如果脚本完成了修复，请完全退出 Codex 和 Chrome，再依次重新打开后测试浏览器控制。

## 运行要求

- Windows
- 已安装 OpenAI Codex 桌面应用
- PowerShell 5.1 或更高版本

## 校验结果说明

脚本运行结束后会显示以下项目：

- `Installed Codex`：当前安装的 Codex 版本。
- `Bundled plugins`：Codex 安装包内置的浏览器插件版本。
- `Chrome cache latest`：Chrome 插件缓存当前版本。
- `Browser cache latest`：Browser 插件缓存当前版本。
- `Native host`：Chrome 本机连接是否通过 `chrome\latest` 加载。

如果显示旧版进程仍在运行，请完全退出对应应用（包括系统托盘进程）后重新打开。

## 安全设计

脚本只允许目标位于 Codex 插件缓存目录内；更新前会保留带时间戳的旧 `latest`
联接，并在启用新版本前校验关键文件哈希。脚本不会下载或执行第三方插件文件。

