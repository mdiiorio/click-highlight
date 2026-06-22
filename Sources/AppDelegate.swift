import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventMonitor: Any?
    private var keyboardMonitor: Any?
    private let rippleController = RippleWindowController()
    private let keystrokeOverlay = KeystrokeOverlay()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        requestInputMonitoringIfNeeded()
        setupMenuBar()
        setupEventMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        [eventMonitor, keyboardMonitor].compactMap { $0 }.forEach { NSEvent.removeMonitor($0) }
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func requestInputMonitoringIfNeeded() {
        CGRequestListenEventAccess()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click", accessibilityDescription: nil)
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Click Highlight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.rippleController.showRipple(at: NSEvent.mouseLocation)
        }
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.keystrokeOverlay.show(event: event)
        }
    }
}
