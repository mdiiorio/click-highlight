import Cocoa
import Metal
import MetalKit
import ScreenCaptureKit

class RippleWindowController {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer
    private var activeWindows: [NSWindow] = []

    private static let captureSize: CGFloat = 600

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
        float2 texCoord [[attribute(1)]];
    };
    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };
    struct Uniforms {
        float elapsed;
        float duration;
    };

    vertex VertexOut rippleVertex(VertexIn in [[stage_in]]) {
        VertexOut out;
        out.position = float4(in.position, 0.0, 1.0);
        out.texCoord = in.texCoord;
        return out;
    }

    fragment float4 rippleFragment(
        VertexOut in [[stage_in]],
        texture2d<float> tex [[texture(0)]],
        constant Uniforms &u [[buffer(0)]]
    ) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 uv = in.texCoord;
        float2 delta = uv - float2(0.5);
        float dist = length(delta);
        float2 dir = dist > 0.001 ? normalize(delta) : float2(0.0);

        float amplitude = 0.04
            * exp(-dist * 5.0)
            * exp(-u.elapsed * 2.2);

        float phase = dist * 32.0 - u.elapsed * 4.8;
        float2 offset = dir * sin(phase) * amplitude;

        float4 color = tex.sample(s, saturate(uv + offset));

        float timeFade = 1.0 - smoothstep(0.62, 1.0, u.elapsed / u.duration);
        // Circular mask so overlay has soft round edges instead of a hard square
        float radialFade = 1.0 - smoothstep(0.40, 0.50, dist);
        float fade = timeFade * radialFade;

        // Premultiplied alpha output
        return float4(color.rgb * fade, fade);
    }
    """

    init?() {
        guard let dev = MTLCreateSystemDefaultDevice(),
              let queue = dev.makeCommandQueue(),
              let ps = Self.buildPipeline(device: dev),
              let vb = Self.buildVertexBuffer(device: dev)
        else { return nil }
        device = dev
        commandQueue = queue
        pipelineState = ps
        vertexBuffer = vb

        // Pre-warm SCKit at launch so the permission dialog appears now, not on first click
        Task { _ = try? await SCShareableContent.current }
    }

    func showRipple(at location: NSPoint) {
        Task { @MainActor in
            guard let (image, frame) = await self.captureRegion(around: location),
                  let texture = self.makeTexture(from: image)
            else { return }

            let window = self.makeOverlayWindow(frame: frame)
            let metalView = RippleMetalView(
                frame: NSRect(origin: .zero, size: frame.size),
                device: self.device,
                commandQueue: self.commandQueue,
                pipelineState: self.pipelineState,
                vertexBuffer: self.vertexBuffer,
                texture: texture
            ) { [weak self, weak window] in
                guard let window else { return }
                window.orderOut(nil)
                self?.activeWindows.removeAll { $0 === window }
            }
            window.contentView = metalView
            window.orderFrontRegardless()
            self.activeWindows.append(window)
        }
    }

    // MARK: - Private

    private func captureRegion(around point: NSPoint) async -> (image: CGImage, frame: NSRect)? {
        let size = Self.captureSize
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main!
        let scale = screen.backingScaleFactor
        let halfSize = size / 2

        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let content = try? await SCShareableContent.current,
              let scDisplay = content.displays.first(where: { $0.displayID == displayID })
        else { return nil }

        // Convert click to display-local coordinates.
        // SCKit sourceRect uses bottom-left origin per display, matching NSScreen.frame convention.
        let localX = point.x - screen.frame.minX
        let localY = point.y - screen.frame.minY
        let sourceRect = CGRect(
            x: max(0, localX - halfSize),
            y: max(0, localY - halfSize),
            width: size,
            height: size
        )

        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(size * scale)
        config.height = Int(size * scale)
        config.showsCursor = false

        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return nil }

        let windowFrame = NSRect(
            x: point.x - halfSize,
            y: point.y - halfSize,
            width: size,
            height: size
        )
        return (image, windowFrame)
    }

    private func makeTexture(from image: CGImage) -> MTLTexture? {
        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(cgImage: image, options: [
            .origin: MTKTextureLoader.Origin.topLeft,
            .SRGB: false,
        ])
    }

    private func makeOverlayWindow(frame: NSRect) -> NSWindow {
        let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        return w
    }

    private static func buildPipeline(device: MTLDevice) -> MTLRenderPipelineState? {
        guard let library = try? device.makeLibrary(source: shaderSource, options: nil),
              let vertFn = library.makeFunction(name: "rippleVertex"),
              let fragFn = library.makeFunction(name: "rippleFragment")
        else { return nil }

        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float2; vd.attributes[0].offset = 0;  vd.attributes[0].bufferIndex = 1
        vd.attributes[1].format = .float2; vd.attributes[1].offset = 8;  vd.attributes[1].bufferIndex = 1
        vd.layouts[1].stride = 16

        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vertFn
        pd.fragmentFunction = fragFn
        pd.vertexDescriptor = vd
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        pd.colorAttachments[0].isBlendingEnabled = true
        // Premultiplied-alpha blend
        pd.colorAttachments[0].sourceRGBBlendFactor = .one
        pd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pd.colorAttachments[0].sourceAlphaBlendFactor = .one
        pd.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: pd)
    }

    private static func buildVertexBuffer(device: MTLDevice) -> MTLBuffer? {
        // Full-screen quad: NDC position + UV coords
        // NDC top-left (-1,+1) → UV (0,0) matches CGImage/Metal texture top-left origin
        let verts: [Float] = [
            -1,  1,  0, 0,
             1,  1,  1, 0,
            -1, -1,  0, 1,
             1, -1,  1, 1,
        ]
        return device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<Float>.stride, options: [])
    }
}
