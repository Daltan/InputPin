# InputPin

**Keep your preferred input method in place.**

一个轻量的 macOS 菜单栏工具，自动将输入法切回微信输入法，减少输入时意外跳到 ABC 的情况。目前支持锁定微信输入法。

## 功能

- 监听输入源和前台应用变化，配合一秒定时检查自动纠正。
- 菜单栏暂停与恢复，暂停状态跨重启保存。
- 首次启动尝试启用登录启动，支持在菜单中关闭。
- 安全输入期间暂缓切换，结束后恢复；保留微信输入法内部中英文切换。
- 无需辅助功能或键盘监控权限，不读取输入内容，不联网。

## 构建与使用

需要 Apple Silicon Mac、macOS 13 或更新版本，以及 Xcode Command Line Tools。请先安装微信输入法，并在系统输入法设置中启用。

```sh
xcode-select --install # 已安装开发工具时跳过
bash src/build.sh
```

生成的应用位于 `outputs/InputPin.app`。将它复制到“应用程序”目录后打开。菜单栏显示“微”和状态图标，可暂停、恢复或调整登录启动；若系统要求批准，请在系统设置中允许登录项。

构建使用本地 ad-hoc 签名，尚未提供 Developer ID 签名、公证或预编译发行包。当前构建目标为 arm64，Intel Mac 尚未支持。

如果之前安装了“微信输入法锁定”原型，请先关闭原型的登录启动并退出，再使用 InputPin，避免两个实例同时纠正输入法。InputPin 使用独立的应用标识，设置不会自动迁移。

## 诊断与验证

```sh
outputs/InputPin.app/Contents/MacOS/InputPin --diagnose
outputs/InputPin.app/Contents/MacOS/InputPin --integration-test
```

集成测试需要已登录的图形会话、已启用的微信输入法和 ABC，以及关闭安全输入。请先退出所有输入法锁定实例；测试会临时切换输入源，约需 5 秒，不注册登录项。诊断输出包含输入源和登录项状态，不包含输入内容。

原型已在 macOS 27 / Apple Silicon 上验证 ABC 自动恢复、暂停、恢复锁定，以及一次安全输入结束后的恢复。InputPin 的验证范围见 [VALIDATION.md](VALIDATION.md)。

## 使用边界

应用通过切换后纠正保持微信输入法，存在短暂切换窗口。系统登录界面、密码框或禁止第三方输入法的场景无法保证锁定。重启自动启动、睡眠唤醒和长期稳定性仍需实际使用验证。

卸载前先在菜单中关闭登录启动，退出应用，再将应用移入废纸篓。

## 开发

核心逻辑在 `src/main.swift`，使用 Cocoa、Carbon Text Input Sources 和 ServiceManagement；构建脚本为 `src/build.sh`，无第三方依赖。

欢迎通过 Issues 报告复现步骤、macOS 版本和诊断结果，通过 Pull Requests 贡献改进。本项目为独立社区工具，与腾讯或微信无关联。

## 许可

[MIT License](LICENSE)
