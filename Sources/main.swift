// WheelFlip — reverse scroll direction for mouse wheels only, leaving the
// trackpad (and Magic Mouse) on macOS "natural" scrolling.
//
// How it tells them apart: trackpad / Magic Mouse scroll events always carry a
// gesture phase (began/changed/ended) or a momentum phase. A mouse wheel's
// events have neither. Only phase-less events get flipped.

import AppKit
import ApplicationServices
import ServiceManagement

// MARK: - Settings

enum Settings {
    static let d = UserDefaults.standard
    static var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "enabled") }
    }
    static var vertical: Bool {
        get { d.object(forKey: "vertical") as? Bool ?? true }
        set { d.set(newValue, forKey: "vertical") }
    }
    static var horizontal: Bool {
        get { d.object(forKey: "horizontal") as? Bool ?? false }
        set { d.set(newValue, forKey: "horizontal") }
    }
}

// MARK: - Scroll logic

/// True when the event comes from a plain mouse wheel (not a trackpad / Magic Mouse).
func isMouseWheel(_ e: CGEvent) -> Bool {
    e.getIntegerValueField(.scrollWheelEventScrollPhase) == 0 &&
        e.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
}

func flip(_ e: CGEvent, vertical: Bool, horizontal: Bool) {
    // Integer, fixed-point and point deltas are each read by different apps, so flip all
    // three. Read them all first: setting the integer delta makes CoreGraphics recompute
    // the others, so reading after writing would flip them back.
    func flipAxis(_ delta: CGEventField, _ fixed: CGEventField, _ point: CGEventField) {
        let d = e.getIntegerValueField(delta), f = e.getDoubleValueField(fixed), p = e.getIntegerValueField(point)
        e.setIntegerValueField(delta, value: -d)
        e.setDoubleValueField(fixed, value: -f)
        e.setIntegerValueField(point, value: -p)
    }
    if vertical {
        flipAxis(.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1)
    }
    if horizontal {
        flipAxis(.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2)
    }
}

// MARK: - Event tap

final class ScrollTap {
    private(set) var tap: CFMachPort?
    // Cached so the callback doesn't hit UserDefaults on every scroll tick.
    var enabled = Settings.enabled, vertical = Settings.vertical, horizontal = Settings.horizontal

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, ctx in
                let me = Unmanaged<ScrollTap>.fromOpaque(ctx!).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = me.tap { CGEvent.tapEnable(tap: t, enable: true) }
                } else if type == .scrollWheel, me.enabled, isMouseWheel(event) {
                    flip(event, vertical: me.vertical, horizontal: me.horizontal)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }
}

// MARK: - Menu bar app

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem!
    private let scroll = ScrollTap()
    private var retry: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        updateIcon()

        if !UserDefaults.standard.bool(forKey: "loginItemConfigured") {
            UserDefaults.standard.set(true, forKey: "loginItemConfigured")
            if SMAppService.mainApp.status != .enabled { try? SMAppService.mainApp.register() }
        }

        // Modifying events needs Accessibility permission. Prompt once, then keep
        // retrying quietly until the user grants it in System Settings.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !(AXIsProcessTrustedWithOptions(opts) && scroll.start()) {
            retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                guard let self, AXIsProcessTrusted(), self.scroll.start() else { return }
                t.invalidate(); self.updateIcon()
            }
        }
    }

    private func updateIcon() {
        let name = !scroll.isRunning ? "exclamationmark.triangle" : Settings.enabled ? "computermouse.fill" : "computermouse"
        item.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "WheelFlip")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !scroll.isRunning {
            menu.addItem(disabled("Needs Accessibility permission"))
            menu.addItem(action("Open Accessibility Settings…", #selector(openAX)))
            menu.addItem(.separator())
        }
        menu.addItem(toggle("Reverse Mouse Wheel", Settings.enabled, #selector(toggleEnabled)))
        menu.addItem(toggle("    Vertical", Settings.vertical, #selector(toggleVertical)))
        menu.addItem(toggle("    Horizontal", Settings.horizontal, #selector(toggleHorizontal)))
        menu.addItem(disabled("Trackpad & Magic Mouse are never changed"))
        menu.addItem(.separator())
        menu.addItem(toggle("Launch at Login", SMAppService.mainApp.status == .enabled, #selector(toggleLogin)))
        menu.addItem(action("Quit WheelFlip", #selector(quit), "q"))
    }

    private func disabled(_ t: String) -> NSMenuItem {
        let i = NSMenuItem(title: t, action: nil, keyEquivalent: ""); i.isEnabled = false; return i
    }
    private func action(_ t: String, _ s: Selector, _ k: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: t, action: s, keyEquivalent: k); i.target = self; return i
    }
    private func toggle(_ t: String, _ on: Bool, _ s: Selector) -> NSMenuItem {
        let i = action(t, s); i.state = on ? .on : .off; return i
    }

    @objc private func toggleEnabled() { Settings.enabled.toggle(); scroll.enabled = Settings.enabled; updateIcon() }
    @objc private func toggleVertical() { Settings.vertical.toggle(); scroll.vertical = Settings.vertical }
    @objc private func toggleHorizontal() { Settings.horizontal.toggle(); scroll.horizontal = Settings.horizontal }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func openAX() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func toggleLogin() {
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
        else { try? SMAppService.mainApp.register() }
    }
}

// MARK: - Self-test (no permissions needed): `WheelFlip --selftest`

if CommandLine.arguments.contains("--selftest") {
    func make(phase: Int64, momentum: Int64) -> CGEvent {
        let e = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 3, wheel2: 1, wheel3: 0)!
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        return e
    }
    var ok = true
    func check(_ name: String, _ cond: Bool) { print((cond ? "PASS " : "FAIL ") + name); ok = ok && cond }

    let wheel = make(phase: 0, momentum: 0)
    check("mouse wheel detected", isMouseWheel(wheel))
    flip(wheel, vertical: true, horizontal: false)
    check("vertical flipped (all 3 fields)", wheel.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3
        && wheel.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) < 0
        && wheel.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) < 0)
    check("horizontal untouched", wheel.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 1)
    check("trackpad gesture ignored", !isMouseWheel(make(phase: 2, momentum: 0)))
    check("trackpad momentum ignored", !isMouseWheel(make(phase: 0, momentum: 2)))
    exit(ok ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
