import AppKit
import Combine
import CoreEngine
import ScreenCaptureKit

private func makeShapeCGPath(shape: OverlayShape, bounds: CGRect) -> CGPath {
    let path = CGMutablePath()
    let points = shape.polygonPoints(in: bounds, maxPoints: 64)
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

public final class CursorHighlightView: NSView {
    public let settings: AppSettings
    public var isMousePressed: Bool = false {
        didSet { needsDisplay = true }
    }
    public var clickScaleFactor: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }
    public var clickRotationRadians: CGFloat = 0.0 {
        didSet { needsDisplay = true }
    }
    public var isIdleHidden: Bool = false {
        didSet { needsDisplay = true }
    }

    public init(frame: NSRect, settings: AppSettings = .shared) {
        self.settings = settings
        super.init(frame: frame)
        self.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !isIdleHidden else { return }
        if settings.highlightShowOnlyOnClick && !isMousePressed {
            return
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: clickRotationRadians)
        context.scaleBy(x: clickScaleFactor, y: clickScaleFactor)
        context.translateBy(x: -center.x, y: -center.y)

        let baseSize = CGFloat(settings.highlightSize)
        let shapeBounds = CGRect(
            x: center.x - baseSize * 0.5,
            y: center.y - baseSize * 0.5,
            width: baseSize,
            height: baseSize
        )
        let path = makeShapeCGPath(shape: settings.highlightShape, bounds: shapeBounds)
        let activeColor = (isMousePressed ? settings.cursorClickHighlightColor : settings.highlightColor).nsColor

        if settings.highlightGlow {
            context.setShadow(
                offset: .zero,
                blur: 10.0,
                color: activeColor.withAlphaComponent(0.75).cgColor
            )
        }

        context.addPath(path)
        context.setFillColor(activeColor.withAlphaComponent(CGFloat(settings.highlightOpacity)).cgColor)
        context.fillPath()

        if settings.highlightBorderStyle != .none && settings.cursorHighlightBorderWidth > 0 {
            context.addPath(path)
            context.setStrokeColor(activeColor.cgColor)
            context.setLineWidth(CGFloat(settings.cursorHighlightBorderWidth))
            if settings.highlightBorderStyle == .dashed {
                context.setLineDash(phase: 0, lengths: [6, 4])
            }
            context.strokePath()
        }

        context.restoreGState()
    }
}

public final class CursorHighlightWindowController {
    public let settings: AppSettings
    public private(set) var panel: NSPanel?
    public private(set) var highlightView: CursorHighlightView?
    public private(set) var currentCursorPoint: CGPoint = NSEvent.mouseLocation

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var idleTimer: Timer?
    private var animationTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    public init(settings: AppSettings = .shared) {
        self.settings = settings
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowPosition(at: self?.currentCursorPoint ?? NSEvent.mouseLocation)
                self?.highlightView?.needsDisplay = true
            }
            .store(in: &cancellables)
    }

    deinit {
        hide()
    }

    public func toggle() {
        if settings.isHighlightingCursor {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        let padding: CGFloat = 60.0
        let dim = CGFloat(settings.highlightSize) + padding
        let rect = NSRect(x: 0, y: 0, width: dim, height: dim)

        if panel == nil {
            let p = NSPanel(
                contentRect: rect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.level = .screenSaver
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let view = CursorHighlightView(frame: rect, settings: settings)
            p.contentView = view
            panel = p
            highlightView = view
        }

        settings.isHighlightingCursor = true
        highlightView?.isIdleHidden = false
        updateWindowPosition(at: NSEvent.mouseLocation)
        panel?.orderFrontRegardless()
        startMonitoring()
        scheduleIdleTimer()
    }

    public func hide() {
        stopMonitoring()
        idleTimer?.invalidate()
        idleTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
        panel?.orderOut(nil)
        settings.isHighlightingCursor = false
    }

    public func updateWindowPosition(at screenPoint: CGPoint) {
        currentCursorPoint = screenPoint
        guard let panel else { return }
        let dim = CGFloat(settings.highlightSize) + 60.0
        let frame = NSRect(
            x: screenPoint.x - dim * 0.5,
            y: screenPoint.y - dim * 0.5,
            width: dim,
            height: dim
        )
        panel.setFrame(frame, display: true)
        highlightView?.frame = NSRect(origin: .zero, size: frame.size)
        highlightView?.isIdleHidden = false
        highlightView?.needsDisplay = true
    }

    public func simulateClickDown() {
        highlightView?.isMousePressed = true
        switch settings.highlightClickAnimation {
        case .scale:
            highlightView?.clickScaleFactor = 0.78
            highlightView?.clickRotationRadians = 0.0
        case .rotate:
            highlightView?.clickScaleFactor = 1.0
            highlightView?.clickRotationRadians = .pi / 6.0
        case .none:
            highlightView?.clickScaleFactor = 1.0
            highlightView?.clickRotationRadians = 0.0
        }
    }

    public func simulateClickUp() {
        highlightView?.isMousePressed = false
        highlightView?.clickScaleFactor = 1.0
        highlightView?.clickRotationRadians = 0.0
    }

    private func startMonitoring() {
        stopMonitoring()
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp
        ]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }

    private func stopMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        updateWindowPosition(at: NSEvent.mouseLocation)
        scheduleIdleTimer()
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            simulateClickDown()
        case .leftMouseUp, .rightMouseUp:
            simulateClickUp()
        default:
            break
        }
    }

    private func scheduleIdleTimer() {
        idleTimer?.invalidate()
        guard settings.highlightOffWhenInactive else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: settings.cursorIdleTimeout, repeats: false) { [weak self] _ in
            self?.highlightView?.isIdleHidden = true
        }
    }
}

public final class CursorSpotlightView: NSView {
    public let settings: AppSettings
    public var cursorInView: CGPoint = .zero {
        didSet { needsDisplay = true }
    }

    public init(frame: NSRect, settings: AppSettings = .shared) {
        self.settings = settings
        super.init(frame: frame)
        self.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()

        let size = CGFloat(settings.spotlightSize)
        let apertureBounds = CGRect(
            x: cursorInView.x - size * 0.5,
            y: cursorInView.y - size * 0.5,
            width: size,
            height: size
        )
        let cutoutPath = makeShapeCGPath(shape: settings.spotlightShape, bounds: apertureBounds)

        let combined = CGMutablePath()
        combined.addRect(bounds)
        combined.addPath(cutoutPath)

        context.addPath(combined)
        context.setFillColor(NSColor.black.withAlphaComponent(CGFloat(settings.spotlightOpacity)).cgColor)
        context.drawPath(using: .eoFill)

        if settings.spotlightBorderWidth > 0 {
            context.addPath(cutoutPath)
            context.setStrokeColor(settings.spotlightBorderColor.nsColor.cgColor)
            context.setLineWidth(CGFloat(settings.spotlightBorderWidth))
            context.strokePath()
        }

        context.restoreGState()
    }
}

public final class CursorSpotlightWindowController {
    public let settings: AppSettings
    public private(set) var panel: NSPanel?
    public private(set) var spotlightView: CursorSpotlightView?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    public init(settings: AppSettings = .shared) {
        self.settings = settings
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.spotlightView?.needsDisplay = true }
            .store(in: &cancellables)
    }

    deinit {
        hide()
    }

    public func toggle() {
        if settings.isSpotlightingCursor {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        if panel == nil {
            let p = NSPanel(
                contentRect: screenFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.level = .screenSaver
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let view = CursorSpotlightView(frame: NSRect(origin: .zero, size: screenFrame.size), settings: settings)
            p.contentView = view
            panel = p
            spotlightView = view
        }

        panel?.setFrame(screenFrame, display: true)
        spotlightView?.frame = NSRect(origin: .zero, size: screenFrame.size)
        updateCursorPosition(NSEvent.mouseLocation)
        panel?.orderFrontRegardless()
        settings.isSpotlightingCursor = true
        startMonitoring()
    }

    public func hide() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        panel?.orderOut(nil)
        settings.isSpotlightingCursor = false
    }

    public func updateCursorPosition(_ screenPoint: CGPoint) {
        guard let panel, let spotlightView else { return }
        let localPoint = CGPoint(
            x: screenPoint.x - panel.frame.origin.x,
            y: screenPoint.y - panel.frame.origin.y
        )
        spotlightView.cursorInView = localPoint
    }

    private func startMonitoring() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.updateCursorPosition(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.updateCursorPosition(NSEvent.mouseLocation)
            return event
        }
    }
}

public final class ScreenCaptureManager: NSObject, SCStreamOutput, SCStreamDelegate {
    public private(set) var latestFrame: CGImage?
    private var stream: SCStream?
    private let videoQueue = DispatchQueue(label: "presentify.screencapture.queue")

    public func startStream(excludingWindowID: CGWindowID?) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, _ in
            guard let self, let content, let display = content.displays.first else { return }
            let excludedWindows = content.windows.filter { window in
                guard let excludingWindowID else { return false }
                return window.windowID == excludingWindowID
            }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.showsCursor = false

            let scStream = SCStream(filter: filter, configuration: config, delegate: self)
            try? scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.videoQueue)
            scStream.startCapture(completionHandler: nil)
            self.stream = scStream
        }
    }

    public func stopStream() {
        stream?.stopCapture(completionHandler: nil)
        stream = nil
        latestFrame = nil
    }

    public func captureRegionAround(
        screenPoint: CGPoint,
        captureSize: CGSize,
        excludingWindowID: CGWindowID?
    ) -> CGImage? {
        guard let mainScreen = NSScreen.main else { return nil }
        let screenHeight = mainScreen.frame.height
        let flippedY = screenHeight - screenPoint.y
        let captureRect = CGRect(
            x: screenPoint.x - captureSize.width * 0.5,
            y: flippedY - captureSize.height * 0.5,
            width: max(4.0, captureSize.width),
            height: max(4.0, captureSize.height)
        )

        if let excluded = excludingWindowID, excluded != 0 {
            return CGWindowListCreateImage(
                captureRect,
                .optionOnScreenBelowWindow,
                excluded,
                [.bestResolution]
            )
        }
        return CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }

    public func captureScreenRect(_ screenRect: CGRect, excludingWindowID: CGWindowID?) -> CGImage? {
        let isNonSpecialRect = !screenRect.isNull && !screenRect.isInfinite
        let hasFiniteOrigin = screenRect.origin.x.isFinite && screenRect.origin.y.isFinite
        let hasFiniteSize = screenRect.size.width.isFinite && screenRect.size.height.isFinite
        guard isNonSpecialRect && hasFiniteOrigin else { return nil }
        guard hasFiniteSize else { return nil }

        let standardized = screenRect.standardized
        let hasStandardOrigin = standardized.origin.x.isFinite && standardized.origin.y.isFinite
        let hasStandardSize = standardized.size.width.isFinite && standardized.size.height.isFinite
        guard hasStandardOrigin && hasStandardSize else { return nil }

        let screensUnion = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let clipped = screensUnion.isNull ? standardized : standardized.intersection(screensUnion)
        let isValidClipped = !clipped.isNull && !clipped.isInfinite
        let hasMinimumSize = clipped.width >= 2.0 && clipped.height >= 2.0
        let isWithinMaxSize = clipped.width <= 8192.0 && clipped.height <= 8192.0
        guard isValidClipped && hasMinimumSize else { return nil }
        guard isWithinMaxSize else { return nil }

        guard let referenceHeight = NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height else {
            return nil
        }

        let quartzRect = CGRect(
            x: clipped.origin.x,
            y: referenceHeight - clipped.maxY,
            width: clipped.width,
            height: clipped.height
        )
        if let excluded = excludingWindowID, excluded != 0 {
            return CGWindowListCreateImage(
                quartzRect,
                .optionOnScreenBelowWindow,
                excluded,
                [.bestResolution]
            )
        }
        return CGWindowListCreateImage(
            quartzRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        if let cgImg = context.createCGImage(ciImage, from: ciImage.extent) {
            latestFrame = cgImg
        }
    }
}

public final class CursorZoomView: NSView {
    public let settings: AppSettings
    public var capturedImage: CGImage? {
        didSet { needsDisplay = true }
    }
    public var cursorInScreen: CGPoint = .zero {
        didSet { needsDisplay = true }
    }

    public init(frame: NSRect, settings: AppSettings = .shared) {
        self.settings = settings
        super.init(frame: frame)
        self.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()

        if settings.zoomFullScreen {
            if let img = capturedImage {
                context.interpolationQuality = .high
                context.draw(img, in: bounds)
            } else {
                context.setFillColor(NSColor.windowBackgroundColor.cgColor)
                context.fill(bounds)
            }
            context.restoreGState()
            return
        }

        if settings.zoomDimBackground {
            context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
            context.fill(bounds)
        }

        let size = CGFloat(settings.zoomSize)
        let lensBounds = CGRect(
            x: cursorInScreen.x - size * 0.5,
            y: cursorInScreen.y - size * 0.5,
            width: size,
            height: size
        )
        let clipPath = makeShapeCGPath(shape: settings.zoomShape, bounds: lensBounds)

        context.saveGState()
        context.addPath(clipPath)
        context.clip()
        if let img = capturedImage {
            context.interpolationQuality = .high
            context.draw(img, in: lensBounds)
        } else {
            context.setFillColor(NSColor.darkGray.withAlphaComponent(0.35).cgColor)
            context.fill(lensBounds)
        }
        context.restoreGState()

        if settings.zoomBorderWidth > 0 {
            context.addPath(clipPath)
            context.setStrokeColor(settings.zoomBorderColor.nsColor.cgColor)
            context.setLineWidth(CGFloat(settings.zoomBorderWidth))
            context.strokePath()
        }

        context.restoreGState()
    }
}

public final class CursorZoomWindowController {
    public let settings: AppSettings
    public let shortcutManager: ShortcutManager
    public let captureManager: ScreenCaptureManager
    public private(set) var panel: NSPanel?
    public private(set) var zoomView: CursorZoomView?

    private var refreshTimer: Timer?
    private var keyMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared,
        captureManager: ScreenCaptureManager = ScreenCaptureManager()
    ) {
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.captureManager = captureManager

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshMagnifiedFrame() }
            .store(in: &cancellables)
    }

    deinit {
        hide()
    }

    public func toggle() {
        if settings.isZoomingCursor {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        if panel == nil {
            let p = NSPanel(
                contentRect: screenFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.level = .screenSaver
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let view = CursorZoomView(frame: NSRect(origin: .zero, size: screenFrame.size), settings: settings)
            p.contentView = view
            panel = p
            zoomView = view
        }

        panel?.setFrame(screenFrame, display: true)
        zoomView?.frame = NSRect(origin: .zero, size: screenFrame.size)
        settings.isZoomingCursor = true
        panel?.orderFrontRegardless()

        let windowID = panel.map { CGWindowID($0.windowNumber) }
        captureManager.startStream(excludingWindowID: windowID)
        refreshMagnifiedFrame()

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.refreshMagnifiedFrame()
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleCursorShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
                return nil
            }
            return event
        }
    }

    public func hide() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        captureManager.stopStream()
        panel?.orderOut(nil)
        settings.isZoomingCursor = false
    }

    @discardableResult
    public func handleCursorShortcut(keyCode: UInt16, modifiers: UInt) -> Bool {
        guard let command = shortcutManager.matchCursorCommand(
            keyCode: keyCode,
            modifiers: modifiers,
            isZoomActive: settings.isZoomingCursor
        ) else {
            return false
        }

        switch command {
        case .decreaseCursorSize:
            settings.decreaseCursorSize()
        case .increaseCursorSize:
            settings.increaseCursorSize()
        case .decreaseZoomLevel:
            settings.decreaseZoomLevel()
        case .increaseZoomLevel:
            settings.increaseZoomLevel()
        case .toggleZoomFullScreen:
            settings.zoomFullScreen.toggle()
        default:
            return false
        }
        refreshMagnifiedFrame()
        return true
    }

    public func refreshMagnifiedFrame(at point: CGPoint = NSEvent.mouseLocation) {
        guard let zoomView else { return }
        let localPoint = CGPoint(
            x: point.x - (panel?.frame.origin.x ?? 0),
            y: point.y - (panel?.frame.origin.y ?? 0)
        )
        zoomView.cursorInScreen = localPoint

        let scale = max(1.25, settings.zoomLevel)
        let targetWidth = settings.zoomFullScreen ? Double(zoomView.bounds.width) : settings.zoomSize
        let targetHeight = settings.zoomFullScreen ? Double(zoomView.bounds.height) : settings.zoomSize
        let captureSize = CGSize(width: targetWidth / scale, height: targetHeight / scale)
        let windowID = panel.map { CGWindowID($0.windowNumber) }

        if Bundle.main.bundleURL.pathExtension == "app" {
            zoomView.capturedImage = captureManager.captureRegionAround(
                screenPoint: point,
                captureSize: captureSize,
                excludingWindowID: windowID
            )
        } else {
            zoomView.needsDisplay = true
        }
    }
}
