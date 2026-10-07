# Codex Quota Monitor / Codex 额度监控

> A local dashboard for viewing Codex usage quotas on an Android tablet.
> 用于在 Android 平板上查看 Codex 用量额度的本地仪表盘。

![Codex Quota Monitor dashboard](docs/images/dashboard.png)

## What it does / 功能

- Live quota dashboard with a configurable refresh interval and remaining-time display. / 实时额度、可配置刷新间隔与剩余时间展示。
- Local history charts, activity log, and offline display of the last successful data. / 本地历史曲线、活动日志，以及离线时继续展示最后一次成功数据。
- Optional boot-time monitoring, screen wake lock, and a tablet-first landscape layout. / 可选开机监控、常亮和为横屏平板设计的界面。
- Optional read-only LAN web dashboard for viewing and taking screenshots from a computer. / 可选只读局域网 Web 仪表盘，方便在电脑查看和截图。
- Credentials are stored only in platform secure storage; diagnostic exports exclude them. / 凭据只保存到平台安全存储，诊断导出不包含凭据。

On Windows, the local history database is `codex_monitor.sqlite` and settings are `codex_monitor_settings.json` in the project root. If the app is moved without `pubspec.yaml`, it falls back to the runtime directory. Credentials remain in Windows secure storage and are not written to these files.
Windows 下，本地历史数据库为项目根目录的 `codex_monitor.sqlite`，设置为 `codex_monitor_settings.json`。如果应用被单独移出项目且找不到 `pubspec.yaml`，则使用运行目录；凭据仍保存在 Windows 安全存储中，不会写入这两个文件。

## Get started / 开始使用

Requires Flutter 3.44+, Android SDK, and Java 17. / 需要 Flutter 3.44+、Android SDK 和 Java 17。

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run

# Build a release APK / 构建正式 APK
flutter build apk --release
```

On first run, import the `auth.json` created by your own Codex CLI installation, or paste its content in the app. The release APK is at `build/app/outputs/flutter-apk/app-release.apk`.
首次运行时，导入你自己的 Codex CLI 生成的 `auth.json`，或在应用中粘贴其内容。正式 APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。

## Automated Android releases / 自动发布 Android 版本

Pushing a change to `main` or starting **Android release** from GitHub Actions increments the patch and Android build numbers in `pubspec.yaml`, builds a signed APK, commits the version change, and publishes a GitHub Release named `v<version>` with the APK attached. For example, `1.0.2+3` becomes `1.0.3+4`.

The workflow signs releases with the same persistent Android key used by the current tablet install, so later APKs can update the app without removing its data. The keystore and signing values are kept in GitHub Actions repository secrets and are never committed.

To view the complete dashboard from a computer, enable **允许局域网 Web 查看** in Settings, then open the displayed `http://<tablet-wifi-ip>:8787` address from a device on the same network. The server resumes with boot monitoring, exposes display data only, and never returns credentials, account IDs, headers, or raw API responses. Disable it when LAN access is not needed; the page intentionally has no login and is reachable by other devices on the same LAN.
如需在电脑查看完整仪表盘，请在设置中开启 **允许局域网 Web 查看**，然后从同一网络的设备打开页面中显示的 `http://<平板-Wi-Fi-IP>:8787`。服务器会随开机监控恢复，只提供展示数据，不返回凭据、账号 ID、请求头或原始 API 响应。不需要时请关闭；该页面没有登录，同一局域网中的其他设备也能访问。

## Security & compatibility / 安全与兼容性

`auth.json` is a login credential: never commit, upload, or share it. The optional dashboard is LAN-only and read-only; do not expose port 8787 to the public internet. This project uses an undocumented Codex/ChatGPT usage endpoint that may change without notice; it is independent and is not affiliated with OpenAI.
`auth.json` 属于登录凭据，请勿提交、上传或分享。可选仪表盘仅供局域网只读访问，请勿把 8787 端口暴露到公网。项目依赖未公开的 Codex/ChatGPT 用量接口，接口可能随时变动；本项目为独立项目，与 OpenAI 无隶属关系。

## License / 许可

Licensed under [MIT](LICENSE). You may use, modify, distribute, and use it commercially, subject to the license notice.
本项目采用 [MIT](LICENSE) 许可证，可自由使用、修改、分发及商用，但需保留许可证声明。
