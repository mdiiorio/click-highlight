import Cocoa
import Metal
import MetalKit

class RippleMetalView: MTKView {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private let captureTexture: MTLTexture
    private var startTime: CFTimeInterval = 0
    let animDuration: CFTimeInterval = 1.8
    var onComplete: (() -> Void)?

    private struct Uniforms {
        var elapsed: Float
        var duration: Float
    }

    init(
        frame: NSRect,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        pipelineState: MTLRenderPipelineState,
        vertexBuffer: MTLBuffer,
        texture: MTLTexture,
        onComplete: @escaping () -> Void
    ) {
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.vertexBuffer = vertexBuffer
        self.captureTexture = texture
        self.onComplete = onComplete
        super.init(frame: frame, device: device)

        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        self.isPaused = false
        self.enableSetNeedsDisplay = false

        if let metalLayer = self.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
        }

        startTime = CACurrentMediaTime()
    }

    required init(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let elapsed = CACurrentMediaTime() - startTime
        if elapsed >= animDuration {
            isPaused = true
            onComplete?()
            return
        }

        guard let drawable = currentDrawable,
              let rpd = currentRenderPassDescriptor,
              let buf = commandQueue.makeCommandBuffer(),
              let enc = buf.makeRenderCommandEncoder(descriptor: rpd)
        else { return }

        enc.setRenderPipelineState(pipelineState)
        enc.setVertexBuffer(vertexBuffer, offset: 0, index: 1)
        enc.setFragmentTexture(captureTexture, index: 0)

        var u = Uniforms(elapsed: Float(elapsed), duration: Float(animDuration))
        enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)

        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        enc.endEncoding()
        buf.present(drawable)
        buf.commit()
    }
}
