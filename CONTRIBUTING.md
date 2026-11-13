# 贡献指南 · Contributing

欢迎使用中文或英文反馈问题和提交改进。InputPin 当前聚焦 Apple Silicon 上的微信输入法保持；扩展到其他输入法或平台前，建议先通过 Issue 讨论需求与验证方式。

## 报告问题

请提供 macOS 版本、芯片型号、微信输入法版本、复现步骤及预期和实际行为。可以附上 `--diagnose` 输出，并说明是否处于安全输入状态、是否同时运行其他输入法管理工具。公开前检查日志中的个人信息。

## 本地开发

需要 macOS 13+、Apple Silicon 和 Xcode Command Line Tools。

```sh
bash -n src/build.sh
bash src/build.sh
```

构建会执行签名与 Info.plist 校验。无需安装第三方依赖。不要提交 `outputs/`、`scratch/` 或本机配置。

涉及输入源行为的修改，应在真实图形会话中手动验证。集成测试会临时切换输入法，执行条件和命令见 [README](README.md#诊断与验证)。文档修改检查链接、命令和实际实现是否一致即可。

## 提交 Pull Request

- 说明解决的问题、最终行为与实际完成的验证。
- 保持改动聚焦；行为变化时同步更新文档。
- 区分已验证结果和待验证场景，不将原型测试结果当作当前版本结果。
- 保持本地运行与最小权限设计。新增权限、网络请求或依赖时，解释必要性。

## English

Issues and pull requests in English are welcome. Include your macOS version, Mac chip, WeType version, reproduction steps, and expected/actual behavior. Review diagnostic output before sharing it.

Build with `bash src/build.sh` on an Apple Silicon Mac with macOS 13+ and Xcode Command Line Tools. Keep changes focused, document behavior changes, and report only checks you actually ran. Input-source integration tests require an interactive desktop session and temporarily change the active input source; see the [English README](docs/README.en.md).
