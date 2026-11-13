# 验证记录

日期：2026-11-13。

## InputPin 初始版本

- `bash src/build.sh`：通过，生成 `outputs/InputPin.app`。
- 构建脚本内的 ad-hoc 签名、`codesign --verify --deep --strict` 和 Info.plist 校验：通过。
- `bash -n src/build.sh`：通过。
- 检查待发布文件：不包含原型的个人绝对路径、构建缓存或应用二进制。
- 本次未启动或安装新版，未重新执行会切换用户输入法的集成测试。

## 原型验证背景

迁移前的微信输入法锁定原型在 macOS 27.0、Apple Silicon、Swift 6.4 环境下，通过了真实图形会话测试：ABC 自动切回微信、暂停时保持 ABC、恢复锁定后切回微信。安装原型后确认登录项为 enabled，并观察到一次安全输入结束后自动恢复。

这些结果属于迁移前原型。InputPin 更改了应用名、可执行文件名和 bundle identifier，登录项及偏好设置独立，需要在安装后重新验证。

尚未验证：InputPin 图形会话行为、实际重启登录启动、睡眠唤醒、长期稳定性、其他 macOS 版本、跨机器分发。没有 Developer ID 公证。
