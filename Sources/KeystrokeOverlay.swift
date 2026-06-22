import Cocoa

class KeystrokeOverlay {
    private var window: NSWindow?
    private var textLayer: CATextLayer?
    private var hideTimer: Timer?
    private let displayDuration: TimeInterval = 1.2

    func show(event: NSEvent) {
        let text = format(event)
        guard !text.isEmpty else { return }

        if window == nil { buildWindow() }

        textLayer?.string = text
        window?.alphaValue = 1
        window?.orderFrontRegardless()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    // MARK: - Private

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    private func buildWindow() {
        let size = NSSize(width: 340, height: 88)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        let w = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .screenSaver
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.alphaValue = 0

        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: size)
        root.backgroundColor = NSColor(white: 0.08, alpha: 0.82).cgColor
        root.cornerRadius = 18

        let scale = screen.backingScaleFactor
        let tl = CATextLayer()
        tl.frame = root.bounds.insetBy(dx: 20, dy: 10)
        tl.contentsScale = scale
        tl.font = NSFont.monospacedSystemFont(ofSize: 42, weight: .medium)
        tl.fontSize = 42
        tl.foregroundColor = NSColor.white.cgColor
        tl.alignmentMode = .center
        tl.truncationMode = .end
        tl.string = ""
        root.addSublayer(tl)

        let hostView = NSView(frame: NSRect(origin: .zero, size: size))
        hostView.wantsLayer = true
        hostView.layer = root

        w.contentView = hostView
        window = w
        textLayer = tl
    }

    private func format(_ event: NSEvent) -> String {
        var parts: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let specialKeys: [UInt16: String] = [
            36: "↩",  48: "⇥",   49: "␣",   51: "⌫",   53: "⎋",
            76: "↩",  // numpad enter
            123: "←", 124: "→",  125: "↓",  126: "↑",
            116: "⇞", 121: "⇟",  115: "↖",  119: "↘",
            122: "F1", 120: "F2",  99: "F3",  118: "F4",
             96: "F5",  97: "F6",  98: "F7",  100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]

        if let name = specialKeys[event.keyCode] {
            parts.append(name)
        } else if let ch = event.charactersIgnoringModifiers, !ch.isEmpty {
            // Skip non-printable control characters
            let scalar = ch.unicodeScalars.first!.value
            if scalar >= 32 && scalar != 127 {
                parts.append(ch.uppercased())
            }
        }

        return parts.joined(separator: " ")
    }
}
