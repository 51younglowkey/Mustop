// Mustop：菜单栏定时暂停小工具，到点让网易云音乐暂停。
// 原理：通过辅助功能（Accessibility）按下网易云菜单栏「Controls/控制 → Pause/暂停」。
// 只在菜单项显示「暂停」（=正在播放）时才按，已经停着就什么都不做，不会误把音乐打开。

import AppKit
import ApplicationServices
import ServiceManagement

let neteaseBundleID = "com.netease.163music"
let controlsTitles: Set<String> = ["Controls", "控制"]
let pauseTitles: Set<String> = ["Pause", "暂停"]

enum PauseResult { case paused, alreadyStopped, notRunning, noPermission, menuNotFound }

func axChildren(_ el: AXUIElement) -> [AXUIElement] {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &v) == .success,
          let arr = v as? [AXUIElement] else { return [] }
    return arr
}

func axTitle(_ el: AXUIElement) -> String {
    var v: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &v)
    return (v as? String) ?? ""
}

func pauseNetease() -> PauseResult {
    guard AXIsProcessTrusted() else { return .noPermission }
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: neteaseBundleID).first
    else { return .notRunning }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var mb: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &mb) == .success,
          let menuBar = mb else { return .menuNotFound }
    for top in axChildren(menuBar as! AXUIElement) where controlsTitles.contains(axTitle(top)) {
        for menu in axChildren(top) {
            let items = axChildren(menu)
            if let pause = items.first(where: { pauseTitles.contains(axTitle($0)) }) {
                return AXUIElementPerformAction(pause, kAXPressAction as CFString) == .success
                    ? .paused : .menuNotFound
            }
            if !items.isEmpty { return .alreadyStopped }  // 菜单里是「播放」= 本来就停着
        }
    }
    return .menuNotFound
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var deadline: Date?
    var tick: Timer?

    var loginLaunch = false

    // 启动 Apple Event 只在这个阶段读得到
    func applicationWillFinishLaunching(_ n: Notification) { loginLaunch = launchedAsLoginItem() }

    func applicationDidFinishLaunching(_ n: Notification) {
        // 首次运行弹出系统的辅助功能授权提示（用户自己在系统设置里打开）
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        refresh()
        // 用户手动打开（不是开机自启）时，直接在鼠标处弹出菜单——菜单栏图标可能被菜单栏管理工具藏起来
        if !loginLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.popUpAtMouse() }
        }
    }

    // 已经在运行时再次双击 / Spotlight 打开：同样弹出菜单
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        popUpAtMouse()
        return false
    }

    func launchedAsLoginItem() -> Bool {
        guard let ev = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return ev.eventID == kAEOpenApplication &&
            ev.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func popUpAtMouse() {
        NSApp.activate(ignoringOtherApps: true)
        buildMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: 菜单

    func buildMenu() -> NSMenu {
        let m = NSMenu()
        if let d = deadline {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            m.addItem(disabled("将在 \(f.string(from: d)) 暂停网易云"))
            m.addItem(action("取消定时", #selector(cancelTimer)))
            m.addItem(.separator())
            m.addItem(disabled("改为…"))
        }
        for min in [15, 30, 45, 60, 90] {
            let it = action(min < 60 ? "\(min) 分钟" : (min == 60 ? "1 小时" : "1.5 小时"), #selector(pick(_:)))
            it.tag = min
            m.addItem(it)
        }
        m.addItem(action("自定义…", #selector(custom)))
        m.addItem(.separator())
        if !AXIsProcessTrusted() {
            m.addItem(action("⚠️ 未授权辅助功能，点此去设置", #selector(openAXSettings)))
        }
        let login = action("开机自动启动", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        m.addItem(login)
        m.addItem(action("退出", #selector(quit)))
        return m
    }

    func action(_ t: String, _ s: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: t, action: s, keyEquivalent: ""); it.target = self; return it
    }
    func disabled(_ t: String) -> NSMenuItem {
        let it = NSMenuItem(title: t, action: nil, keyEquivalent: ""); it.isEnabled = false; return it
    }

    // MARK: 计时

    @objc func pick(_ s: NSMenuItem) { start(minutes: Double(s.tag)) }

    @objc func custom() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "多少分钟后暂停？"
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.placeholderString = "例如 20"
        a.accessoryView = tf
        a.addButton(withTitle: "开始"); a.addButton(withTitle: "取消")
        a.window.initialFirstResponder = tf
        if a.runModal() == .alertFirstButtonReturn, let v = Double(tf.stringValue), v > 0 {
            start(minutes: v)
        }
    }

    func start(minutes: Double) {
        deadline = Date().addingTimeInterval(minutes * 60)
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.onTick() }
        RunLoop.main.add(tick!, forMode: .common)
        refresh()
    }

    @objc func cancelTimer() { tick?.invalidate(); tick = nil; deadline = nil; refresh() }

    func onTick() {
        guard let d = deadline else { return }
        if Date() >= d {
            let r = pauseNetease()
            cancelTimer()
            if r == .noPermission || r == .menuNotFound { warn(r) }
        } else { refresh() }
    }

    func warn(_ r: PauseResult) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "定时到了，但没能暂停网易云"
        a.informativeText = r == .noPermission
            ? "Mustop 还没有辅助功能权限。请到 系统设置 → 隐私与安全性 → 辅助功能（设备控制与数据访问）里打开它。"
            : "没找到网易云菜单栏里的「控制 → 暂停」，可能是网易云改版了。"
        a.runModal()
    }

    func refresh() {
        if let d = deadline {
            let left = max(0, Int(d.timeIntervalSinceNow.rounded(.up)))
            let h = left / 3600, m = (left % 3600) / 60, s = left % 60
            item.button?.title = h > 0 ? String(format: " %d:%02d:%02d", h, m, s) : String(format: " %d:%02d", m, s)
            item.button?.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Mustop")
        } else {
            item.button?.title = ""
            item.button?.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "Mustop")
        }
        item.menu = buildMenu()
    }

    @objc func openAXSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { NSSound.beep() }
        refresh()
    }

    @objc func quit() { NSApp.terminate(nil) }
}

// 命令行自检：`Mustop --pause-now` 立即尝试暂停一次并打印结果
if CommandLine.arguments.contains("--pause-now") {
    print(pauseNetease()); exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
