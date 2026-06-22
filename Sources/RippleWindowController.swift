import Cocoa

class RippleWindowController {
    private var activeWindows: [NSWindow] = []
    private let windowSize: CGFloat = 240

    func showRipple(at location: NSPoint) {
        let frame = NSRect(
            x: location.x - windowSize / 2,
            y: location.y - windowSize / 2,
            width: windowSize,
            height: windowSize
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        let view = RippleView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = view
        window.orderFrontRegardless()
        activeWindows.append(window)

        view.animate { [weak self, weak window] in
            guard let window else { return }
            window.orderOut(nil)
            self?.activeWindows.removeAll { $0 === window }
        }
    }
}
