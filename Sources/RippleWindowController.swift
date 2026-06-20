import Cocoa

class RippleWindowController {
    private var activeWindows: [NSWindow] = []

    func showRipple(at location: NSPoint) {
        let size: CGFloat = 80
        let frame = NSRect(
            x: location.x - size / 2,
            y: location.y - size / 2,
            width: size,
            height: size
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        let rippleView = RippleView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = rippleView
        window.orderFrontRegardless()
        activeWindows.append(window)

        rippleView.animate { [weak self, weak window] in
            guard let window else { return }
            window.orderOut(nil)
            self?.activeWindows.removeAll { $0 === window }
        }
    }
}
