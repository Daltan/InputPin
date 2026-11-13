import Cocoa
import Carbon
import ServiceManagement

let appID = "io.github.daltan.InputPin"
let weTypeID = "com.tencent.inputmethod.wetype"

func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
}
func sourceID(_ source: TISInputSource) -> String {
    property(source, kTISPropertyInputSourceID) ?? ""
}
func currentSource() -> TISInputSource {
    TISCopyCurrentKeyboardInputSource().takeRetainedValue()
}
func sources() -> [TISInputSource] {
    let all = TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
    return all.filter {
        (property($0, kTISPropertyInputSourceCategory) as String?) == (kTISCategoryKeyboardInputSource as String)
        && (property($0, kTISPropertyInputSourceIsSelectCapable) as Bool?) == true
    }
}
func isWeType(_ source: TISInputSource) -> Bool {
    let bundle: String = property(source, kTISPropertyBundleID) ?? ""
    return bundle == weTypeID || sourceID(source) == weTypeID || sourceID(source).hasPrefix(weTypeID + ".")
}
func sourceName(_ source: TISInputSource) -> String {
    property(source, kTISPropertyLocalizedName) ?? sourceID(source)
}

// Diagnostic modes never register a login item or start a second lock process.
if CommandLine.arguments.contains("--diagnose") {
    print("loginItemStatus=\(SMAppService.mainApp.status.rawValue) (0=notRegistered, 1=enabled, 2=requiresApproval, 3=notFound)")
    print("current=\(sourceID(currentSource())) secureInput=\(IsSecureEventInputEnabled())")
    for source in sources() {
        print("\(sourceID(source))\t\(sourceName(source))\twechat=\(isWeType(source))")
    }
    exit(0)
}
if let index = CommandLine.arguments.firstIndex(of: "--select"), CommandLine.arguments.count > index + 1 {
    let id = CommandLine.arguments[index + 1]
    guard let source = sources().first(where: { sourceID($0) == id }) else {
        fputs("Input source unavailable\n", stderr); exit(2)
    }
    let result = TISSelectInputSource(source)
    print("select=\(result)")
    exit(result == noErr ? 0 : 1)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let initialSource = currentSource()
    private var item: NSStatusItem!
    private let menu = NSMenu()
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var target: TISInputSource?
    private var lastAttempt = Date.distantPast
    private var nextAttempt = Date.distantPast
    private var failures = 0
    private var corrections = 0
    private var sessionActive = true
    private var sleeping = false
    private var message = "正在检查输入法"
    private var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "lockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "lockEnabled") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: appID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        UserDefaults.standard.register(defaults: ["lockEnabled": true])
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = menu
        menu.delegate = self
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(sourceChanged), name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil)
        distributed.addObserver(self, selector: #selector(sourcesChanged), name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String), object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(sourceChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionOn), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionOff), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        refreshTarget()
        timer = Timer(timeInterval: 1.0, target: self, selector: #selector(check), userInfo: nil, repeats: true)
        timer?.tolerance = 0.2
        RunLoop.main.add(timer!, forMode: .common)
        // Long-term protection is requested; register once, respect later opt-outs.
        if !CommandLine.arguments.contains("--integration-test") && !UserDefaults.standard.bool(forKey: "loginConfigured") {
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "loginConfigured")
            } catch { showError("开机启动未开启", error.localizedDescription) }
        }
        check()
        if CommandLine.arguments.contains("--integration-test") { runIntegrationTest() }
    }

    func runIntegrationTest() {
        let original = initialSource
        let wasEnabled = enabled
        guard !IsSecureEventInputEnabled(), target != nil,
              let abc = sources().first(where: { sourceID($0) == "com.apple.keylayout.ABC" }) else {
            fputs("SKIP: secure input enabled or required source missing\n", stderr); exit(2)
        }
        func finish(_ success: Bool, _ detail: String) {
            timer?.invalidate(); pending?.cancel()
            enabled = wasEnabled
            _ = TISSelectInputSource(original)
            print("\(success ? "PASS" : "FAIL"): \(detail)")
            exit(success ? 0 : 1)
        }
        enabled = true
        let selected = TISSelectInputSource(abc)
        guard selected == noErr, sourceID(currentSource()) == sourceID(abc) else {
            finish(false, "Cannot select ABC for test"); return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [self] in
            guard isWeType(currentSource()) else { finish(false, "ABC was not corrected"); return }
            print("PASS: ABC automatically restored to WeType")
            enabled = false
            guard TISSelectInputSource(abc) == noErr else { finish(false, "Cannot select ABC while paused"); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [self] in
                guard sourceID(currentSource()) == sourceID(abc) else { finish(false, "Pause did not preserve ABC"); return }
                print("PASS: Pause preserves ABC across timer checks")
                enabled = true; nextAttempt = .distantPast; check()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    finish(isWeType(currentSource()), "Resume restores WeType")
                }
            }
        }
    }

    func refreshTarget() {
        let available = sources().filter(isWeType)
        let current = currentSource()
        target = available.first(where: { sourceID($0) == sourceID(current) }) ?? available.first
    }
    @objc func sourcesChanged() { refreshTarget(); failures = 0; nextAttempt = .distantPast; sourceChanged() }
    @objc func sourceChanged() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.check() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
    @objc func sleep() { sleeping = true }
    @objc func woke() { sleeping = false; sourcesChanged() }
    @objc func sessionOff() { sessionActive = false }
    @objc func sessionOn() { sessionActive = true; sourcesChanged() }

    @objc func check() {
        guard enabled else { updateStatus("已暂停锁定", symbol: "pause.circle"); return }
        guard sessionActive && !sleeping else { updateStatus("等待会话恢复", symbol: "moon"); return }
        guard !IsSecureEventInputEnabled() else { updateStatus("安全输入中，结束后恢复锁定", symbol: "lock.shield"); return }
        let current = currentSource()
        if isWeType(current) {
            failures = 0; nextAttempt = .distantPast
            updateStatus("微信输入法已锁定", symbol: "lock.fill"); return
        }
        guard Date() >= nextAttempt else { return }
        if target == nil { refreshTarget() }
        guard let target else {
            nextAttempt = Date().addingTimeInterval(5)
            updateStatus("未找到已启用的微信输入法", symbol: "exclamationmark.triangle"); return
        }
        guard Date().timeIntervalSince(lastAttempt) >= 0.4 else { return }
        lastAttempt = Date()
        let result = TISSelectInputSource(target)
        if result == noErr && isWeType(currentSource()) {
            corrections += 1; failures = 0; nextAttempt = .distantPast
            updateStatus("微信输入法已锁定", symbol: "lock.fill")
        } else {
            failures += 1
            nextAttempt = Date().addingTimeInterval(min(30, pow(2, Double(min(failures, 5)))))
            refreshTarget()
            updateStatus("等待系统允许切换（\(result)）", symbol: "arrow.clockwise")
        }
    }
    func updateStatus(_ text: String, symbol: String) {
        guard message != text || item.button?.image == nil else { return }
        message = text
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        item.button?.title = "微"
        item.button?.toolTip = "InputPin · \(text)"
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        add("InputPin", nil)
        add(message, nil)
        add("当前：\(sourceName(currentSource()))", nil)
        add("本次已纠正 \(corrections) 次", nil)
        menu.addItem(.separator())
        add(enabled ? "暂停锁定" : "恢复锁定", #selector(toggleLock))
        let login = SMAppService.mainApp.status
        let loginItem = add(login == .requiresApproval ? "开机启动：等待系统批准…" : "开机启动", #selector(toggleLogin))
        loginItem.state = login == .enabled ? .on : (login == .requiresApproval ? .mixed : .off)
        add("打开输入法设置…", #selector(openSettings))
        menu.addItem(.separator())
        add("使用说明…", #selector(showHelp))
        add("退出", #selector(quit))
    }
    @discardableResult func add(_ title: String, _ action: Selector?) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self; entry.isEnabled = action != nil; menu.addItem(entry); return entry
    }
    @objc func toggleLock() { enabled.toggle(); failures = 0; nextAttempt = .distantPast; check() }
    @objc func toggleLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try SMAppService.mainApp.register()
            }
            UserDefaults.standard.set(true, forKey: "loginConfigured")
        } catch { showError("无法修改开机启动", error.localizedDescription) }
    }
    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }
    @objc func showHelp() {
        showError("InputPin", "应用运行时会自动切回微信输入法。微信内部的中英文切换不受影响。\n\n密码框、安全输入和系统登录界面可能限制第三方输入法；安全输入结束后自动恢复。\n\n菜单可暂停锁定或关闭开机启动。退出后停止保护，下一次登录仍按开机启动设置运行。\n\n无需辅助功能或键盘监控权限，不读取或记录输入内容。")
    }
    func showError(_ title: String, _ detail: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail; alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate(); pending?.cancel()
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
