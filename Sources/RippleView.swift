import Cocoa
import QuartzCore

class RippleView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func animate(completion: @escaping () -> Void) {
        guard let layer else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = min(bounds.width, bounds.height) / 2

        let ring = CAShapeLayer()
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.systemYellow.withAlphaComponent(0.85).cgColor
        ring.lineWidth = 2.5
        ring.path = circlePath(center: center, radius: maxRadius)
        layer.addSublayer(ring)

        let dot = CAShapeLayer()
        dot.fillColor = NSColor.systemYellow.withAlphaComponent(0.6).cgColor
        dot.strokeColor = nil
        dot.path = circlePath(center: center, radius: 5)
        layer.addSublayer(dot)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            ring.removeFromSuperlayer()
            dot.removeFromSuperlayer()
            completion()
        }

        let duration: CFTimeInterval = 0.45

        let ringExpand = CABasicAnimation(keyPath: "path")
        ringExpand.fromValue = circlePath(center: center, radius: 2)
        ringExpand.toValue = circlePath(center: center, radius: maxRadius)
        ringExpand.duration = duration
        ringExpand.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let ringFade = CABasicAnimation(keyPath: "opacity")
        ringFade.fromValue = 1.0
        ringFade.toValue = 0.0
        ringFade.duration = duration
        ringFade.timingFunction = CAMediaTimingFunction(name: .easeIn)

        ring.add(ringExpand, forKey: "path")
        ring.add(ringFade, forKey: "opacity")
        ring.opacity = 0

        let dotFade = CABasicAnimation(keyPath: "opacity")
        dotFade.fromValue = 1.0
        dotFade.toValue = 0.0
        dotFade.beginTime = CACurrentMediaTime() + 0.08
        dotFade.duration = duration * 0.55

        dot.add(dotFade, forKey: "opacity")
        dot.opacity = 0

        CATransaction.commit()
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }
}
