import Cocoa
import QuartzCore

class RippleView: NSView {
    private let ringCount = 3
    private let maxRadius: CGFloat = 110
    private let stagger: CFTimeInterval = 0.13
    private let ringDuration: CFTimeInterval = 0.8

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

        addDot(to: layer, center: center)

        for i in 0..<ringCount {
            addRing(
                to: layer,
                center: center,
                delay: stagger * CFTimeInterval(i),
                opacity: Float(0.85 - Double(i) * 0.2),
                lineWidth: 2.5 - CGFloat(i) * 0.5
            )
        }

        let total = ringDuration + stagger * CFTimeInterval(ringCount - 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.05) {
            completion()
        }
    }

    private func addDot(to layer: CALayer, center: CGPoint) {
        let dot = CAShapeLayer()
        dot.fillColor = NSColor.white.withAlphaComponent(0.9).cgColor
        dot.path = circlePath(center: center, radius: 4)
        layer.addSublayer(dot)

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.0
        anim.duration = 0.25
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        dot.add(anim, forKey: nil)
    }

    private func addRing(to layer: CALayer, center: CGPoint, delay: CFTimeInterval,
                         opacity: Float, lineWidth: CGFloat) {
        let ring = CAShapeLayer()
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.white.cgColor
        ring.lineWidth = lineWidth
        ring.opacity = 0
        ring.path = circlePath(center: center, radius: maxRadius)
        layer.addSublayer(ring)

        let start = CACurrentMediaTime() + delay

        let expand = CABasicAnimation(keyPath: "path")
        expand.fromValue = circlePath(center: center, radius: 1)
        expand.toValue   = circlePath(center: center, radius: maxRadius)
        expand.beginTime = start
        expand.duration  = ringDuration
        expand.timingFunction = CAMediaTimingFunction(name: .linear)
        expand.fillMode = .both
        expand.isRemovedOnCompletion = false
        ring.add(expand, forKey: nil)

        // Hold opacity then fade over the final 55%
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values   = [0, opacity, opacity, 0]
        fade.keyTimes = [0, 0.05, 0.45, 1.0]
        fade.beginTime = start
        fade.duration  = ringDuration
        fade.fillMode  = .both
        fade.isRemovedOnCompletion = false
        ring.add(fade, forKey: nil)
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ), transform: nil)
    }
}
