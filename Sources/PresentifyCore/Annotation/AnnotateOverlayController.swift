import AppKit
import Combine
import CoreEngine
import CoreImage
import SwiftUI

public final class AnnotatePanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.acceptsMouseMovedEvents = true
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { false }

    override public func resignKey() {
        super.resignKey()
        (contentView as? AnnotateCanvasView)?.cancelActiveInteraction()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let canvas = contentView as? AnnotateCanvasView,
           canvas.handleKeyCommand(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    public func updateBackground(from settings: AppSettings) {
        if settings.isWhiteboardActive {
            backgroundColor = settings.annotateWhiteboardColor.nsColor.withAlphaComponent(CGFloat(settings.whiteboardOpacity))
        } else if settings.dimScreenOnAnnotate {
            backgroundColor = NSColor.black.withAlphaComponent(CGFloat(settings.dimScreenOpacity))
        } else {
            backgroundColor = .clear
        }
    }
}

public enum BackdropBlurBorderStyle: Equatable, Sendable {
    case committed
    case draft
}

public enum BackdropGlassTier: String, CaseIterable, Equatable, Sendable {
    case ultraThin
    case thin
    case regular
    case thick
    case ultraThick

    public static func from(opacity: Double) -> BackdropGlassTier {
        let clamped = opacity.isFinite ? min(max(opacity, 0.10), 1.00) : 0.55
        if clamped < 0.28 {
            return .ultraThin
        }
        if clamped < 0.48 {
            return .thin
        }
        if clamped < 0.68 {
            return .regular
        }
        if clamped < 0.86 {
            return .thick
        }
        return .ultraThick
    }
}

public struct BackdropBlurAppearance: Equatable, Sendable {
    public static let standard = BackdropBlurAppearance()

    public var borderStyle: BackdropBlurBorderStyle = .committed
    public var opacityLevel: Double = 0.55
    public var tintColor: RGBColor? = nil
}

private struct BackdropBlurSurfaceView: View {
    let appearance: BackdropBlurAppearance

    private var clampedOpacity: Double {
        appearance.opacityLevel.isFinite ? min(max(appearance.opacityLevel, 0.10), 1.00) : 0.55
    }

    private var glassMaterial: Material {
        switch BackdropGlassTier.from(opacity: clampedOpacity) {
        case .ultraThin: return .ultraThinMaterial
        case .thin: return .thinMaterial
        case .regular: return .regularMaterial
        case .thick: return .thickMaterial
        case .ultraThick: return .ultraThickMaterial
        }
    }

    private var veilColor: Color {
        if let tint = appearance.tintColor {
            return tint.swiftUIColor.opacity(0.12 + clampedOpacity * 0.78)
        }
        return Color.white.opacity(max(0.0, (clampedOpacity - 0.65) * 0.85))
    }

    private var borderColor: Color {
        switch appearance.borderStyle {
        case .committed:
            return (appearance.tintColor?.swiftUIColor ?? SettingsView.themeLightBlue).opacity(0.38)
        case .draft:
            return SettingsView.themeBlue
        }
    }

    private var borderWidth: CGFloat {
        appearance.borderStyle == .draft ? 1.5 : 1.0
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        shape
            .fill(Color.clear)
            .background(glassMaterial, in: shape)
            .overlay {
                shape.fill(veilColor)
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: borderWidth)
            }
    }
}

public final class BackdropBlurRegionView: NSView {
    public private(set) var blurAppearance: BackdropBlurAppearance
    private let hostingView: NSHostingView<BackdropBlurSurfaceView>

    public var borderStyle: BackdropBlurBorderStyle {
        blurAppearance.borderStyle
    }

    public var borderWidth: CGFloat {
        blurAppearance.borderStyle == .draft ? 1.5 : 1.0
    }

    public var glassTier: BackdropGlassTier {
        BackdropGlassTier.from(opacity: blurAppearance.opacityLevel)
    }

    public var opacityLevel: Double {
        blurAppearance.opacityLevel
    }

    public var tintColor: RGBColor? {
        blurAppearance.tintColor
    }

    public init(frame frameRect: NSRect, appearance: BackdropBlurAppearance = .standard) {
        let sanitized = Self.sanitize(appearance)
        self.blurAppearance = sanitized
        self.hostingView = NSHostingView(rootView: BackdropBlurSurfaceView(appearance: sanitized))
        super.init(frame: frameRect)
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.sizingOptions = []
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override public func layout() {
        super.layout()
        hostingView.frame = bounds
    }

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        hostingView.frame = bounds
    }

    public func applyAppearance(_ newAppearance: BackdropBlurAppearance) {
        let sanitized = Self.sanitize(newAppearance)
        guard sanitized != blurAppearance else { return }
        blurAppearance = sanitized
        hostingView.rootView = BackdropBlurSurfaceView(appearance: sanitized)
    }

    public func applyBorderStyle(_ style: BackdropBlurBorderStyle) {
        var updated = blurAppearance
        updated.borderStyle = style
        applyAppearance(updated)
    }

    private static func sanitize(_ raw: BackdropBlurAppearance) -> BackdropBlurAppearance {
        let clamped = raw.opacityLevel.isFinite ? min(max(raw.opacityLevel, 0.10), 1.00) : 0.55
        return BackdropBlurAppearance(
            borderStyle: raw.borderStyle,
            opacityLevel: clamped,
            tintColor: raw.tintColor
        )
    }
}

public final class AnnotateCanvasView: NSView, NSTextFieldDelegate {
    private static let blurCIContext = CIContext(options: [.cacheIntermediates: false])

    private enum ActiveAnnotationTransform {
        case textCornerScale(id: UUID, center: CGPoint, initialDistance: Double, initialFontSize: Double)
        case textRotate(id: UUID, center: CGPoint, initialAngle: Double, initialRotation: Double)
        case itemCornerScale(anchor: AnnotationCornerScaleAnchor, dragStartPoint: CGPoint)
        case directionalHandle(initialItem: AnnotationItem, handle: AnnotationDirectionalHandle)
    }

    public let canvasState: AnnotationCanvasState
    public let settings: AppSettings
    public let shortcutManager: ShortcutManager
    public var onRequestSaveScreenshot: (() -> Void)?
    public var onRequestCopyScreenshot: (() -> Void)?
    public var onRequestClose: (() -> Void)?
    public var onRequestOpenSettings: (() -> Void)?
    public var onLineWeightChanged: ((Double) -> Void)?
    public var onBlurOpacityChanged: ((Double) -> Void)?
    public var onTextSizeChanged: ((Double) -> Void)?
    public var exclusionScreenRectsProvider: (() -> [NSRect])?
    public var regionCaptureProvider: ((CGRect) -> CGImage?)? {
        didSet {
            cachedBlurImages.removeAll()
            if !backdropBlurViews.isEmpty || regionCaptureProvider == nil {
                syncBackdropBlurViews()
            }
            needsDisplay = true
        }
    }

    public private(set) var cursorLocation: CGPoint?
    public private(set) var activeTextField: NSTextField?
    public private(set) var editingAnnotationID: UUID?
    public private(set) var backdropBlurViews: [UUID: BackdropBlurRegionView] = [:]
    public private(set) var isPostDrawAutoSelection = false

    private var editingInitialTextColor: RGBColor?
    private var editingInitialNSColor: NSColor?
    private var editingOverrideColor: RGBColor?
    private var editingInitialFontName: String?
    private var editingInitialFontSize: Double?
    private var editingOverrideFontSize: Double?
    private var activeAnnotationTransform: ActiveAnnotationTransform?
    private var directionalGrabOffset: CGPoint = .zero
    private var isApplyingPostDrawSelection = false
    private var isTrackpadGestureTransforming = false
    private var isDraggingSelection = false
    private var isMarqueeSelecting = false
    private var dragOriginPoint: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var activeTouchIdentity: AnyObject?
    private var cachedBlurImages: [UUID: (rect: CGRect, style: BlurStyle, weight: Int, opacityBucket: Int, isDraft: Bool, image: CGImage)] = [:]
    private var lastRenderedWhiteboardActive = false
    private var isCachingOffscreenDisplay = false
    private var cancellables: Set<AnyCancellable> = []

    public init(
        frame: NSRect,
        canvasState: AnnotationCanvasState,
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared
    ) {
        self.canvasState = canvasState
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.lastRenderedWhiteboardActive = settings.isWhiteboardActive
        super.init(frame: frame)
        self.wantsLayer = true
        self.allowedTouchTypes = [.indirect]

        canvasState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncBackdropBlurViews()
                self?.needsDisplay = true
            }
            .store(in: &cancellables)

        canvasState.$selectedIDs
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingPostDrawSelection else { return }
                self.isPostDrawAutoSelection = false
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncBackdropBlurViews()
                self?.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$selectedColorIndex
            .combineLatest(settings.$favColors, settings.$useRandomColors, settings.$activeGradient)
            .dropFirst()
            .sink { [weak self] selectedIndex, favColors, useRandom, activeGradient in
                guard let self, let field = self.activeTextField else { return }
                let nextColor: RGBColor
                if useRandom {
                    nextColor = activeGradient.startColor
                } else if favColors.isEmpty {
                    nextColor = .red
                } else {
                    let safeIndex = min(max(selectedIndex, 0), favColors.count - 1)
                    nextColor = favColors[safeIndex]
                }
                self.editingOverrideColor = nextColor
                field.textColor = nextColor.nsColor
                self.needsDisplay = true
            }
            .store(in: &cancellables)

        canvasState.$annotations
            .dropFirst()
            .sink { [weak self] updatedItems in
                guard let self, let field = self.activeTextField else { return }
                guard let editID = self.editingAnnotationID else { return }
                guard let updatedItem = updatedItems.first(where: { $0.id == editID }) else { return }
                let safeSize = AnnotationItem.sanitizeFontSize(updatedItem.fontSize)
                self.editingOverrideFontSize = safeSize
                field.font = NSFont(name: updatedItem.fontName, size: CGFloat(safeSize))
                    ?? NSFont.systemFont(ofSize: CGFloat(safeSize), weight: .semibold)
                let desiredHeight = CGFloat(safeSize * 1.45)
                let clampedHeight = desiredHeight.isFinite ? min(max(36.0, desiredHeight), 400.0) : 36.0
                let itemOrigin = updatedItem.startPoint
                let hasFiniteItemOrigin = itemOrigin.x.isFinite && itemOrigin.y.isFinite
                let resolvedOrigin = hasFiniteItemOrigin ? itemOrigin : field.frame.origin
                let hasSafeOrigin = resolvedOrigin.x.isFinite && resolvedOrigin.y.isFinite
                if hasSafeOrigin && field.frame.width.isFinite {
                    field.frame = NSRect(
                        x: resolvedOrigin.x,
                        y: resolvedOrigin.y,
                        width: field.frame.width,
                        height: clampedHeight
                    )
                }
                self.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$annotateFontSize
            .dropFirst()
            .sink { [weak self] nextFontSize in
                guard let self, let field = self.activeTextField else { return }
                guard self.editingAnnotationID == nil else { return }
                let safeSize = AnnotationItem.sanitizeFontSize(nextFontSize)
                self.editingOverrideFontSize = safeSize
                let fontName = self.editingInitialFontName ?? self.settings.annotateFont.fontName
                field.font = NSFont(name: fontName, size: CGFloat(safeSize))
                    ?? NSFont.systemFont(ofSize: CGFloat(safeSize), weight: .semibold)
                let desiredHeight = CGFloat(safeSize * 1.45)
                let clampedHeight = desiredHeight.isFinite ? min(max(36.0, desiredHeight), 400.0) : 36.0
                let hasFiniteFieldOrigin = field.frame.origin.x.isFinite && field.frame.origin.y.isFinite
                if hasFiniteFieldOrigin {
                    field.frame.size.height = clampedHeight
                }
                self.needsDisplay = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.cancelActiveInteraction()
            }
            .store(in: &cancellables)
    }

    var hasActiveMouseInteraction: Bool {
        let hasOrphanedDrag = activeAnnotationTransform != nil || isDraggingSelection
        return hasOrphanedDrag || isMarqueeSelecting
    }

    private func selectPostDrawAnnotation(_ id: UUID) {
        isApplyingPostDrawSelection = true
        canvasState.selectedIDs = [id]
        isApplyingPostDrawSelection = false
        isPostDrawAutoSelection = true
    }

    public func cancelActiveInteraction() {
        activeAnnotationTransform = nil
        directionalGrabOffset = .zero
        isTrackpadGestureTransforming = false
        isDraggingSelection = false
        isMarqueeSelecting = false
        activeTouchIdentity = nil
        canvasState.selectionRectangle = nil
        canvasState.activeDraft = nil
        canvasState.endInteractiveTransform()
        syncBackdropBlurViews()
        needsDisplay = true
    }

    public func clearBlurCache() {
        cachedBlurImages.removeAll()
        syncBackdropBlurViews()
        needsDisplay = true
    }

    public func removeAllBackdropBlurViews() {
        for backdropView in backdropBlurViews.values {
            backdropView.removeFromSuperview()
        }
        backdropBlurViews.removeAll()
    }

    public func syncBackdropBlurViews() {
        syncBlurCacheState()
        let isHiddenOverlayPanel = window is AnnotatePanel && !settings.isAnnotating
        if settings.isWhiteboardActive || isHiddenOverlayPanel {
            removeAllBackdropBlurViews()
            return
        }

        var candidateItems = canvasState.annotations.filter { $0.mode == .blur }
        if let draft = canvasState.activeDraft, draft.mode == .blur {
            candidateItems.append(draft)
        }

        var activeBackdropIDs: Set<UUID> = []
        for item in candidateItems {
            guard let visibleRect = validatedVisibleBlurRect(for: item) else { continue }
            let hasCaptureDimensions = visibleRect.width >= 2.0 && visibleRect.height >= 2.0
            guard hasCaptureDimensions else { continue }
            guard resolveCapturedBlurImage(for: item, visibleRect: visibleRect) == nil else { continue }

            let isDraft = canvasState.activeDraft?.id == item.id
            let targetAppearance = BackdropBlurAppearance(
                borderStyle: isDraft ? .draft : .committed,
                opacityLevel: item.effectiveBlurOpacity,
                tintColor: item.blurTintColor
            )
            let backdropView = backdropBlurViews[item.id] ?? BackdropBlurRegionView(frame: visibleRect, appearance: targetAppearance)
            backdropView.frame = visibleRect
            backdropView.applyAppearance(targetAppearance)
            if backdropView.superview !== self {
                if let textField = activeTextField, textField.superview === self {
                    addSubview(backdropView, positioned: .below, relativeTo: textField)
                } else {
                    addSubview(backdropView)
                }
            }
            backdropBlurViews[item.id] = backdropView
            activeBackdropIDs.insert(item.id)
        }

        let staleIDs = backdropBlurViews.keys.filter { !activeBackdropIDs.contains($0) }
        for staleID in staleIDs {
            backdropBlurViews[staleID]?.removeFromSuperview()
            backdropBlurViews.removeValue(forKey: staleID)
        }
    }

    private func syncBlurCacheState() {
        if lastRenderedWhiteboardActive != settings.isWhiteboardActive {
            lastRenderedWhiteboardActive = settings.isWhiteboardActive
            cachedBlurImages.removeAll()
        }
        if !cachedBlurImages.isEmpty {
            var activeBlurIDs = Set(canvasState.annotations.lazy.filter { $0.mode == .blur }.map(\.id))
            if let draft = canvasState.activeDraft, draft.mode == .blur {
                activeBlurIDs.insert(draft.id)
            }
            cachedBlurImages = cachedBlurImages.filter { activeBlurIDs.contains($0.key) }
        }
    }

    private func validatedVisibleBlurRect(for item: AnnotationItem) -> CGRect? {
        let rawRect = item.boundingRect
        let hasFiniteOrigin = rawRect.origin.x.isFinite && rawRect.origin.y.isFinite
        let hasFiniteSize = rawRect.size.width.isFinite && rawRect.size.height.isFinite
        let isRawRectFinite = hasFiniteOrigin && hasFiniteSize
        let hasPositiveRawSize = rawRect.width > 0 && rawRect.height > 0
        guard isRawRectFinite && hasPositiveRawSize else { return nil }

        let visibleRect = rawRect.intersection(bounds)
        let isVisibleNonEmpty = !visibleRect.isNull && !visibleRect.isEmpty
        let hasFiniteVisibleOrigin = visibleRect.origin.x.isFinite && visibleRect.origin.y.isFinite
        let hasFiniteVisibleSize = visibleRect.size.width.isFinite && visibleRect.size.height.isFinite
        let isVisibleFinite = hasFiniteVisibleOrigin && hasFiniteVisibleSize
        let isVisibleBounded = visibleRect.width <= 16_384.0 && visibleRect.height <= 16_384.0
        let canRenderVisible = isVisibleNonEmpty && isVisibleFinite
        guard canRenderVisible && isVisibleBounded else { return nil }
        return visibleRect
    }

    private func resolveCapturedBlurImage(for item: AnnotationItem, visibleRect: CGRect) -> CGImage? {
        let hasCaptureDimensions = visibleRect.width >= 2.0 && visibleRect.height >= 2.0
        let canCapture = !settings.isWhiteboardActive && hasCaptureDimensions
        guard canCapture else { return nil }

        let isDraft = canvasState.activeDraft?.id == item.id
        let integralRect = visibleRect.integral
        let style = item.effectiveBlurStyle
        let clampedWeight = item.lineWeight.isFinite ? min(max(item.lineWeight, 2.0), 48.0) : 6.0
        let weightBucket = Int(clampedWeight.rounded())
        let opacityBucket = item.blurOpacity != nil ? Int((item.effectiveBlurOpacity * 100.0).rounded()) : -weightBucket

        if let cached = cachedBlurImages[item.id] {
            let matchesGeometry = cached.rect == integralRect && cached.weight == weightBucket
            let matchesStyleAndDraft = cached.style == style && cached.isDraft == isDraft
            let matchesAppearance = matchesStyleAndDraft && cached.opacityBucket == opacityBucket
            if matchesGeometry && matchesAppearance {
                return cached.image
            }
        }

        guard let rawImage = regionCaptureProvider?(visibleRect) else { return nil }
        var filterItem = item
        filterItem.startPoint = visibleRect.origin
        filterItem.endPoint = CGPoint(x: visibleRect.maxX, y: visibleRect.maxY)
        filterItem.isConstrained = false
        filterItem.lineWeight = clampedWeight
        guard let filtered = Self.applyBlurFilter(to: rawImage, item: filterItem) else { return nil }
        cachedBlurImages[item.id] = (integralRect, style, weightBucket, opacityBucket, isDraft, filtered)
        return filtered
    }

    public static func applyBlurFilter(to image: CGImage, item: AnnotationItem) -> CGImage? {
        let hasPositivePixels = image.width > 0 && image.height > 0
        let isWithinMaxPixels = image.width <= 16_384 && image.height <= 16_384
        guard hasPositivePixels && isWithinMaxPixels else { return nil }

        let ciImage = CIImage(cgImage: image)
        let extent = ciImage.extent
        let hasValidExtent = !extent.isEmpty && !extent.isInfinite
        guard hasValidExtent else { return nil }

        let clampedWeight = item.lineWeight.isFinite ? min(max(item.lineWeight, 2.0), 48.0) : 6.0
        let rectWidth = Double(item.boundingRect.width)
        let hasValidRectWidth = rectWidth.isFinite && rectWidth >= 1.0
        let rawScale = hasValidRectWidth ? (Double(image.width) / rectWidth) : 1.0
        let backingScale = rawScale.isFinite ? min(max(rawScale, 1.0), 4.0) : 1.0
        let pointStrength: Double
        if item.blurOpacity != nil {
            pointStrength = 1.5 + item.effectiveBlurOpacity * 34.5
        } else {
            pointStrength = 8.0 + clampedWeight * 1.75
        }
        let pixelStrength = pointStrength * backingScale

        let filtered: CIImage
        switch item.effectiveBlurStyle {
        case .gaussian:
            filtered = ciImage
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: pixelStrength])
                .cropped(to: extent)
        case .pixelate:
            let center = CIVector(x: extent.midX, y: extent.midY)
            filtered = ciImage
                .clampedToExtent()
                .applyingFilter(
                    "CIPixellate",
                    parameters: [
                        kCIInputScaleKey: pixelStrength,
                        kCIInputCenterKey: center
                    ]
                )
                .cropped(to: extent)
        }
        return blurCIContext.createCGImage(filtered, from: extent)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var acceptsFirstResponder: Bool { true }

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncBackdropBlurViews()
    }

    override public func cacheDisplay(in rect: NSRect, to bitmapImageRep: NSBitmapImageRep) {
        let previousCaching = isCachingOffscreenDisplay
        isCachingOffscreenDisplay = true
        let visibleBackdrops = backdropBlurViews.values.filter { !$0.isHidden }
        for backdropView in visibleBackdrops {
            backdropView.isHidden = true
        }
        defer {
            isCachingOffscreenDisplay = previousCaching
            for backdropView in visibleBackdrops {
                backdropView.isHidden = false
            }
        }
        super.cacheDisplay(in: rect, to: bitmapImageRep)
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        if let window, let rects = exclusionScreenRectsProvider?(), !rects.isEmpty {
            let windowPoint = superview?.convert(point, to: nil) ?? point
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            if rects.contains(where: { $0.contains(screenPoint) }) {
                return nil
            }
        }
        return super.hitTest(point)
    }

    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        cancelActiveInteraction()
        super.viewWillMove(toWindow: newWindow)
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override public func mouseMoved(with event: NSEvent) {
        if hasActiveMouseInteraction {
            cancelActiveInteraction()
        }
        cursorLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override public func mouseExited(with event: NSEvent) {
        cursorLocation = nil
        needsDisplay = true
    }

    override public func rightMouseDown(with event: NSEvent) {
        cancelActiveInteraction()
        super.rightMouseDown(with: event)
    }

    override public func otherMouseDown(with event: NSEvent) {
        cancelActiveInteraction()
        super.otherMouseDown(with: event)
    }

    private func visibleNonTextSelectionBox(for item: AnnotationItem) -> CGRect? {
        let rawBox = item.boundingRect
        let hasFiniteOrigin = rawBox.origin.x.isFinite && rawBox.origin.y.isFinite
        let hasFiniteSize = rawBox.size.width.isFinite && rawBox.size.height.isFinite
        guard hasFiniteOrigin && hasFiniteSize else { return nil }
        let clippedBox = rawBox.intersection(bounds)
        guard !clippedBox.isNull else { return nil }
        let selectionBox = clippedBox.insetBy(dx: -4.0, dy: -4.0)
        let hasFiniteBoxOrigin = selectionBox.origin.x.isFinite && selectionBox.origin.y.isFinite
        let hasFiniteBoxSize = selectionBox.size.width.isFinite && selectionBox.size.height.isFinite
        guard hasFiniteBoxOrigin && hasFiniteBoxSize else { return nil }
        return selectionBox
    }

    private func hitTestSelectedAnnotationTransformHandle(at point: CGPoint) -> ActiveAnnotationTransform? {
        let hasFinitePoint = point.x.isFinite && point.y.isFinite
        guard hasFinitePoint else { return nil }
        guard canvasState.selectedIDs.count == 1 else { return nil }
        guard let selectedID = canvasState.selectedIDs.first else { return nil }
        guard let item = canvasState.annotations.first(where: { $0.id == selectedID }) else { return nil }

        let handleHitRadius: CGFloat = 8.0
        if item.mode == .text {
            let localPoint = item.toTextLocalSpace(point)
            let rotationHandle = item.localTextRotationHandleCenter
            let distToRotation = hypot(localPoint.x - rotationHandle.x, localPoint.y - rotationHandle.y)
            if distToRotation <= handleHitRadius {
                let center = item.textCenter
                let initialAngle = atan2(Double(point.y - center.y), Double(point.x - center.x))
                return .textRotate(
                    id: item.id,
                    center: center,
                    initialAngle: initialAngle,
                    initialRotation: item.effectiveRotationRadians
                )
            }

            for corner in item.localTextScaleHandleCenters {
                let distToCorner = hypot(localPoint.x - corner.x, localPoint.y - corner.y)
                if distToCorner <= handleHitRadius {
                    let center = item.textCenter
                    let rawDist = hypot(Double(point.x - center.x), Double(point.y - center.y))
                    let safeSize = item.fontSize.isFinite ? min(max(item.fontSize, 8.0), 200.0) : 24.0
                    return .textCornerScale(
                        id: item.id,
                        center: center,
                        initialDistance: max(rawDist, 8.0),
                        initialFontSize: safeSize
                    )
                }
            }
            return nil
        }

        if item.usesDirectionalHandles {
            let candidateHandles: [(AnnotationDirectionalHandle, CGPoint)] = [
                (.headWidth, item.headScaleHandleCenter),
                (.tip, item.tipHandleCenter),
                (.tail, item.tailHandleCenter)
            ]
            var bestHandle: AnnotationDirectionalHandle?
            var bestDistance = handleHitRadius
            for (handle, center) in candidateHandles {
                let hasFiniteCenter = center.x.isFinite && center.y.isFinite
                guard hasFiniteCenter else { continue }
                let dist = hypot(point.x - center.x, point.y - center.y)
                let isCloserHit = bestHandle == nil ? (dist <= bestDistance) : (dist < bestDistance)
                if isCloserHit {
                    bestHandle = handle
                    bestDistance = dist
                }
            }
            if let bestHandle {
                return .directionalHandle(initialItem: item, handle: bestHandle)
            }
            return nil
        }

        guard let selectionBox = visibleNonTextSelectionBox(for: item) else { return nil }
        let corners = [
            CGPoint(x: selectionBox.minX, y: selectionBox.minY),
            CGPoint(x: selectionBox.maxX, y: selectionBox.minY),
            CGPoint(x: selectionBox.maxX, y: selectionBox.maxY),
            CGPoint(x: selectionBox.minX, y: selectionBox.maxY)
        ]
        for (cornerIndex, corner) in corners.enumerated() {
            let distToCorner = hypot(point.x - corner.x, point.y - corner.y)
            if distToCorner <= handleHitRadius {
                let anchor = AnnotationCornerScaleAnchor(initialItem: item, cornerIndex: cornerIndex)
                return .itemCornerScale(anchor: anchor, dragStartPoint: point)
            }
        }
        return nil
    }

    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorLocation = point
        commitActiveTextEditing()
        cancelActiveInteraction()

        let flags = event.modifierFlags
        let isCommandDown = flags.contains(.command)
        let isShiftDown = flags.contains(.shift)
        let isOptionDown = flags.contains(.option)
        let isControlDown = flags.contains(.control)

        if isCommandDown {
            isPostDrawAutoSelection = false
            dragOriginPoint = point
            lastDragPoint = point
            if let hitID = canvasState.hitTestAnnotation(at: point) {
                if !canvasState.selectedIDs.contains(hitID) {
                    canvasState.toggleSelection(at: point, additive: isShiftDown)
                }
                if !canvasState.selectedIDs.isEmpty {
                    isDraggingSelection = true
                    canvasState.beginInteractiveTransform()
                } else {
                    isDraggingSelection = false
                }
                isMarqueeSelecting = false
            } else {
                if !isShiftDown {
                    canvasState.selectedIDs.removeAll()
                }
                isDraggingSelection = false
                isMarqueeSelecting = true
                canvasState.selectionRectangle = CGRect(origin: point, size: .zero)
            }
            syncBackdropBlurViews()
            needsDisplay = true
            return
        }

        if let transform = hitTestSelectedAnnotationTransformHandle(at: point) {
            isPostDrawAutoSelection = false
            activeAnnotationTransform = transform
            dragOriginPoint = point
            if case let .directionalHandle(initialItem, handle) = transform {
                let handleCenter: CGPoint
                switch handle {
                case .tail: handleCenter = initialItem.tailHandleCenter
                case .headWidth: handleCenter = initialItem.headScaleHandleCenter
                case .tip: handleCenter = initialItem.tipHandleCenter
                }
                directionalGrabOffset = CGPoint(x: point.x - handleCenter.x, y: point.y - handleCenter.y)
            } else {
                directionalGrabOffset = .zero
            }
            isDraggingSelection = false
            isMarqueeSelecting = false
            canvasState.beginInteractiveTransform()
            needsDisplay = true
            return
        }

        if let hitID = canvasState.hitTestAnnotation(at: point),
           let hitItem = canvasState.annotations.first(where: { $0.id == hitID }) {
            let isAlreadySelected = canvasState.selectedIDs.contains(hitID)
            let isExplicitSelection = isAlreadySelected && !isPostDrawAutoSelection
            let isTextItem = hitItem.mode == .text
            let isTextMode = settings.currentDrawMode == .text
            let isTextHitInTextMode = isTextMode && isTextItem
            if isExplicitSelection || isTextHitInTextMode {
                isPostDrawAutoSelection = false
                let isDoubleClick = event.clickCount >= 2
                if isDoubleClick && isTextItem {
                    canvasState.selectedIDs = [hitItem.id]
                    beginInlineTextEditing(at: hitItem.startPoint, existingID: hitItem.id)
                    return
                }
                if !isAlreadySelected {
                    canvasState.selectedIDs = [hitItem.id]
                }
                dragOriginPoint = point
                lastDragPoint = point
                isDraggingSelection = true
                isMarqueeSelecting = false
                canvasState.beginInteractiveTransform()
                syncBackdropBlurViews()
                needsDisplay = true
                return
            }
        }

        if isPostDrawAutoSelection {
            canvasState.selectedIDs.removeAll()
            isPostDrawAutoSelection = false
        }

        if settings.currentDrawMode == .text {
            canvasState.selectedIDs.removeAll()
            beginInlineTextEditing(at: point)
            return
        }

        let effectiveAutoErase = isControlDown ? !settings.autoEraseEnabled : settings.autoEraseEnabled
        canvasState.beginStroke(
            at: point,
            mode: settings.currentDrawMode,
            color: settings.activeStrokeColor,
            gradient: settings.activeStrokeGradient,
            lineWeight: settings.lineWeight,
            isHighlighter: settings.currentDrawMode == .highlighter,
            isAutoErase: effectiveAutoErase,
            isShiftDown: isShiftDown,
            isOptionDown: isOptionDown,
            blurStyle: settings.blurStyle,
            blurOpacity: settings.blurOpacity,
            blurTintColor: settings.activeBlurTintColor
        )
        if settings.annotateArrowTailFade {
            canvasState.activeDraft?.tailFadeEnabled = true
        }
        syncBackdropBlurViews()
        needsDisplay = true
    }

    override public func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorLocation = point
        guard activeTextField == nil else { return }
        let flags = event.modifierFlags

        if let transform = activeAnnotationTransform {
            let hasFiniteDragPoint = point.x.isFinite && point.y.isFinite
            if hasFiniteDragPoint {
                switch transform {
                case let .textCornerScale(id, center, initialDistance, initialFontSize):
                    let hasFiniteCenter = center.x.isFinite && center.y.isFinite
                    guard hasFiniteCenter else { break }
                    let currentDistance = hypot(Double(point.x - center.x), Double(point.y - center.y))
                    let rawSize = initialFontSize * (currentDistance / max(initialDistance, 8.0))
                    let clampedSize = rawSize.isFinite ? min(max(rawSize, 8.0), 200.0) : initialFontSize
                    canvasState.scaleTextAnnotation(id, toFontSize: clampedSize)
                case let .textRotate(id, center, initialAngle, initialRotation):
                    let hasFiniteCenter = center.x.isFinite && center.y.isFinite
                    guard hasFiniteCenter else { break }
                    let currentAngle = atan2(Double(point.y - center.y), Double(point.x - center.x))
                    let baseRotation = AnnotationCanvasState.sanitizeRotationRadians(initialRotation)
                    var nextRotation = baseRotation + (currentAngle - initialAngle)
                    if flags.contains(.shift) {
                        let snapIncrement = Double.pi / 12.0
                        nextRotation = (nextRotation / snapIncrement).rounded() * snapIncrement
                    }
                    canvasState.setTextRotation(AnnotationCanvasState.sanitizeRotationRadians(nextRotation), for: id)
                case let .itemCornerScale(anchor, dragStartPoint):
                    let motion = AnnotationCornerScaleMotion(dragStartPoint: dragStartPoint, currentPoint: point)
                    let constraint: AnnotationScaleConstraint = flags.contains(.shift) ? .uniform : .free
                    let request = AnnotationCornerScaleRequest(anchor: anchor, motion: motion)
                        .withConstraint(constraint)
                    canvasState.applyCornerScale(request)
                    syncBackdropBlurViews()
                case let .directionalHandle(initialItem, handle):
                    guard point != dragOriginPoint else { break }
                    let adjustedPoint = CGPoint(
                        x: point.x - directionalGrabOffset.x,
                        y: point.y - directionalGrabOffset.y
                    )
                    let snap: AnnotationAngleSnap = flags.contains(.shift) ? .fortyFiveDegrees : .free
                    let request = AnnotationDirectionalDragRequest(initialItem: initialItem, handle: handle)
                        .at(adjustedPoint, angleSnap: snap)
                    canvasState.applyDirectionalHandleDrag(request)
                }
            }
            needsDisplay = true
            return
        }

        if isDraggingSelection {
            let delta = CGSize(width: point.x - lastDragPoint.x, height: point.y - lastDragPoint.y)
            lastDragPoint = point
            canvasState.moveSelectedAnnotations(by: delta)
            syncBackdropBlurViews()
            needsDisplay = true
            return
        }

        if isMarqueeSelecting {
            let rect = CGRect(
                x: min(dragOriginPoint.x, point.x),
                y: min(dragOriginPoint.y, point.y),
                width: abs(point.x - dragOriginPoint.x),
                height: abs(point.y - dragOriginPoint.y)
            )
            canvasState.selectAnnotations(in: rect)
            needsDisplay = true
            return
        }

        let hasNoDraft = canvasState.activeDraft == nil
        let isStrokeMode = !flags.contains(.command) && settings.currentDrawMode != .text
        if hasNoDraft && isStrokeMode {
            let effectiveAutoErase = flags.contains(.control) ? !settings.autoEraseEnabled : settings.autoEraseEnabled
            canvasState.beginStroke(
                at: point,
                mode: settings.currentDrawMode,
                color: settings.activeStrokeColor,
                gradient: settings.activeStrokeGradient,
                lineWeight: settings.lineWeight,
                isHighlighter: settings.currentDrawMode == .highlighter,
                isAutoErase: effectiveAutoErase,
                isShiftDown: flags.contains(.shift),
                isOptionDown: flags.contains(.option),
                blurStyle: settings.blurStyle,
                blurOpacity: settings.blurOpacity,
                blurTintColor: settings.activeBlurTintColor
            )
            if settings.annotateArrowTailFade {
                canvasState.activeDraft?.tailFadeEnabled = true
            }
        }

        canvasState.updateStroke(
            to: point,
            isShiftDown: flags.contains(.shift),
            isOptionDown: flags.contains(.option)
        )
        syncBackdropBlurViews()
        needsDisplay = true
    }

    override public func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorLocation = point

        if activeAnnotationTransform != nil {
            activeAnnotationTransform = nil
            directionalGrabOffset = .zero
            canvasState.endInteractiveTransform()
            syncBackdropBlurViews()
            needsDisplay = true
            return
        }

        if isDraggingSelection || isMarqueeSelecting {
            isDraggingSelection = false
            isMarqueeSelecting = false
            canvasState.endInteractiveTransform()
            canvasState.selectionRectangle = nil
            syncBackdropBlurViews()
            needsDisplay = true
            return
        }

        guard activeTextField == nil else { return }

        canvasState.updateStroke(
            to: point,
            isShiftDown: event.modifierFlags.contains(.shift),
            isOptionDown: event.modifierFlags.contains(.option)
        )
        if let committedID = canvasState.finishStroke() {
            selectPostDrawAnnotation(committedID)
        }
        syncBackdropBlurViews()
        needsDisplay = true
    }

    private func beginTrackpadTransformIfNeeded(for phase: NSEvent.Phase) {
        if phase.isEmpty {
            if isTrackpadGestureTransforming {
                isTrackpadGestureTransforming = false
                canvasState.endInteractiveTransform()
            }
            return
        }
        if phase.contains(.began) {
            isTrackpadGestureTransforming = true
            canvasState.beginInteractiveTransform()
        } else if phase.contains(.changed) && !isTrackpadGestureTransforming {
            isTrackpadGestureTransforming = true
            canvasState.beginInteractiveTransform()
        }
    }

    private func endTrackpadTransformIfNeeded(for phase: NSEvent.Phase) {
        let isFinished = phase.contains(.ended) || phase.contains(.cancelled)
        if isFinished {
            isTrackpadGestureTransforming = false
            canvasState.endInteractiveTransform()
        }
    }

    override public func magnify(with event: NSEvent) {
        let canTransformSelection = activeTextField == nil && canvasState.hasSelectedAnnotations
        guard canTransformSelection else {
            super.magnify(with: event)
            return
        }
        beginTrackpadTransformIfNeeded(for: event.phase)
        let rawScale = 1.0 + Double(event.magnification)
        let safeScale = rawScale.isFinite ? max(0.1, rawScale) : 1.0
        canvasState.scaleSelectedAnnotations(by: safeScale)
        endTrackpadTransformIfNeeded(for: event.phase)
        syncBackdropBlurViews()
        needsDisplay = true
    }

    override public func rotate(with event: NSEvent) {
        let canTransformText = activeTextField == nil && canvasState.hasSelectedTextAnnotations
        guard canTransformText else {
            super.rotate(with: event)
            return
        }
        beginTrackpadTransformIfNeeded(for: event.phase)
        let deltaRadians = Double(event.rotation) * .pi / 180.0
        canvasState.rotateSelectedTextAnnotations(by: deltaRadians)
        endTrackpadTransformIfNeeded(for: event.phase)
        needsDisplay = true
    }

    override public func touchesBegan(with event: NSEvent) {
        guard settings.isTouchDrawActive else { return }
        let touches = event.touches(matching: .began, in: self)
        guard touches.count == 1, let touch = touches.first else { return }
        if isPostDrawAutoSelection {
            canvasState.selectedIDs.removeAll()
            isPostDrawAutoSelection = false
        }
        activeTouchIdentity = touch.identity
        let point = touchPoint(for: touch)
        cursorLocation = point
        canvasState.beginStroke(
            at: point,
            mode: settings.currentDrawMode == .text ? .freeHand : settings.currentDrawMode,
            color: settings.activeStrokeColor,
            gradient: settings.activeStrokeGradient,
            lineWeight: settings.lineWeight,
            isHighlighter: settings.currentDrawMode == .highlighter,
            isAutoErase: settings.autoEraseEnabled,
            blurStyle: settings.blurStyle,
            blurOpacity: settings.blurOpacity,
            blurTintColor: settings.activeBlurTintColor
        )
        if settings.annotateArrowTailFade {
            canvasState.activeDraft?.tailFadeEnabled = true
        }
        syncBackdropBlurViews()
        needsDisplay = true
    }

    override public func touchesMoved(with event: NSEvent) {
        guard settings.isTouchDrawActive, let activeID = activeTouchIdentity else { return }
        let touches = event.touches(matching: .moved, in: self)
        guard let touch = touches.first(where: { $0.identity.isEqual(activeID) }) else { return }
        let point = touchPoint(for: touch)
        cursorLocation = point
        canvasState.updateStroke(to: point)
        syncBackdropBlurViews()
        needsDisplay = true
    }

    override public func touchesEnded(with event: NSEvent) {
        guard settings.isTouchDrawActive, let activeID = activeTouchIdentity else { return }
        let touches = event.touches(matching: .ended, in: self)
        guard touches.contains(where: { $0.identity.isEqual(activeID) }) else { return }
        activeTouchIdentity = nil
        if let committedID = canvasState.finishStroke() {
            selectPostDrawAnnotation(committedID)
        }
        syncBackdropBlurViews()
        needsDisplay = true
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleKeyCommand(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override public func keyDown(with event: NSEvent) {
        if handleKeyCommand(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
            return
        }
        super.keyDown(with: event)
    }

    @objc public func undo(_ sender: Any?) {
        isPostDrawAutoSelection = false
        canvasState.undo()
        syncBackdropBlurViews()
        needsDisplay = true
    }

    @objc public func redo(_ sender: Any?) {
        isPostDrawAutoSelection = false
        canvasState.redo()
        syncBackdropBlurViews()
        needsDisplay = true
    }

    private var shouldAdjustTextSizeForWeightShortcut: Bool {
        let selectedItems = canvasState.annotations.filter { canvasState.selectedIDs.contains($0.id) }
        if !selectedItems.isEmpty {
            return selectedItems.allSatisfy { $0.mode == .text }
        }
        return settings.currentDrawMode == .text
    }

    private var shouldAdjustBlurOpacityForWeightShortcut: Bool {
        let selectedItems = canvasState.annotations.filter { canvasState.selectedIDs.contains($0.id) }
        if !selectedItems.isEmpty {
            return selectedItems.allSatisfy { $0.mode == .blur }
        }
        return settings.currentDrawMode == .blur
    }

    private func adjustStrokeLineWeight(by step: Double) {
        let safeStep = step.isFinite ? step : 0.0
        let selectedItems = canvasState.annotations.filter { canvasState.selectedIDs.contains($0.id) }
        let hasSelectedStroke = selectedItems.contains { $0.mode.supportsStrokeLineWeight }
        if hasSelectedStroke {
            guard let updatedWeight = canvasState.adjustSelectedStrokeLineWeight(by: safeStep) else { return }
            let safeUpdated = updatedWeight.isFinite ? min(max(updatedWeight, 1.0), 64.0) : 6.0
            let isPureStrokeSelection = selectedItems.allSatisfy { $0.mode.supportsStrokeLineWeight }
            if isPureStrokeSelection {
                let safeMin = settings.minLineWeight.isFinite ? settings.minLineWeight : 2.0
                let safeMax = settings.maxLineWeight.isFinite ? max(settings.maxLineWeight, safeMin) : max(24.0, safeMin)
                settings.lineWeight = min(max(safeUpdated, safeMin), safeMax)
            } else if safeStep < 0 {
                settings.decreaseLineWeight(step: abs(safeStep))
            } else if safeStep > 0 {
                settings.increaseLineWeight(step: safeStep)
            }
            onLineWeightChanged?(safeUpdated)
            return
        }
        if safeStep < 0 {
            settings.decreaseLineWeight(step: abs(safeStep))
        } else if safeStep > 0 {
            settings.increaseLineWeight(step: safeStep)
        }
        onLineWeightChanged?(settings.lineWeight)
    }

    private func adjustTextFontSize(by step: Double) {
        let safeStep = step.isFinite ? step : 0.0
        if let updatedSize = canvasState.adjustSelectedTextFontSize(by: safeStep) {
            let safeUpdated = AnnotationItem.sanitizeFontSize(updatedSize)
            settings.annotateFontSize = min(max(safeUpdated, 10.0), 96.0)
            onTextSizeChanged?(safeUpdated)
        } else {
            let currentSize = settings.annotateFontSize
            let safeBase = currentSize.isFinite ? currentSize : 24.0
            let nextSize = min(max(safeBase + safeStep, 10.0), 96.0)
            settings.annotateFontSize = nextSize
            onTextSizeChanged?(nextSize)
        }
    }

    private func applySelectedFavoriteColor(at index: Int) {
        settings.selectFavoriteColor(index: index)
        let resolvedColor = settings.activeStrokeColor
        let resolvedGradient = settings.activeStrokeGradient
        canvasState.applyColorUpdate(
            AnnotationColorUpdate(color: resolvedColor, gradient: resolvedGradient)
        )
        let hasSelectedBlur = canvasState.hasSelectedBlurAnnotations
        let isActiveCustomBlurTool = settings.currentDrawMode == .blur && settings.blurUseCustomColor
        if hasSelectedBlur || isActiveCustomBlurTool {
            if hasSelectedBlur {
                settings.blurUseCustomColor = true
            }
            settings.blurCustomColor = resolvedColor
        }
    }

    @discardableResult
    public func handleKeyCommand(keyCode: UInt16, modifiers: UInt) -> Bool {
        let isPrimaryMouseReleased = (NSEvent.pressedMouseButtons & 1) == 0
        if isPrimaryMouseReleased && hasActiveMouseInteraction {
            cancelActiveInteraction()
        }

        if keyCode == 0x35 {
            if activeTextField != nil {
                cancelActiveTextEditing()
            } else if settings.isShowingShortcutsCheatsheet {
                settings.isShowingShortcutsCheatsheet = false
            } else {
                onRequestClose?()
            }
            return true
        }

        let normMods = modifiers & KeyBinding.relevantModifiersMask
        if normMods == KeyBinding.commandMask && keyCode == 0x0C {
            NSApp.terminate(nil)
            return true
        }
        if normMods == KeyBinding.commandMask && keyCode == 0x2B {
            onRequestOpenSettings?()
            return true
        }

        guard activeTextField == nil else { return false }

        if normMods == KeyBinding.commandMask && keyCode == 0x06 {
            isPostDrawAutoSelection = false
            canvasState.undo()
            syncBackdropBlurViews()
            needsDisplay = true
            return true
        }
        let isCommandShiftZ = normMods == (KeyBinding.commandMask | KeyBinding.shiftMask) && keyCode == 0x06
        let isCommandY = normMods == KeyBinding.commandMask && keyCode == 0x10
        if isCommandShiftZ || isCommandY {
            isPostDrawAutoSelection = false
            canvasState.redo()
            syncBackdropBlurViews()
            needsDisplay = true
            return true
        }
        if normMods == KeyBinding.commandMask && keyCode == 0x00 {
            isPostDrawAutoSelection = false
            canvasState.selectedIDs = Set(canvasState.annotations.map(\.id))
            needsDisplay = true
            return true
        }
        if normMods == KeyBinding.commandMask && keyCode == 0x01 {
            onRequestSaveScreenshot?()
            return true
        }
        if normMods == 0 && keyCode == 0x75 {
            isPostDrawAutoSelection = false
            canvasState.deleteSelectedOrClearAll()
            syncBackdropBlurViews()
            needsDisplay = true
            return true
        }
        if normMods == KeyBinding.shiftMask && keyCode == 0x2C {
            settings.isShowingShortcutsCheatsheet.toggle()
            needsDisplay = true
            return true
        }

        guard let matched = shortcutManager.matchLocalAnnotateCommand(keyCode: keyCode, modifiers: modifiers) else {
            return false
        }

        switch matched.command {
        case .firstFavColor: applySelectedFavoriteColor(at: 0)
        case .secondFavColor: applySelectedFavoriteColor(at: 1)
        case .thirdFavColor: applySelectedFavoriteColor(at: 2)
        case .fourthFavColor: applySelectedFavoriteColor(at: 3)
        case .fifthFavColor: applySelectedFavoriteColor(at: 4)
        case .randomColors:
            settings.enableGradients = true
            settings.selectRandomColors()
            let resolvedColor = settings.useRandomColors ? settings.activeGradient.startColor : settings.activeStrokeColor
            let resolvedGradient = settings.activeStrokeGradient
            canvasState.applyColorUpdate(
                AnnotationColorUpdate(color: resolvedColor, gradient: resolvedGradient)
            )
            if canvasState.hasSelectedBlurAnnotations {
                settings.blurUseCustomColor = true
                settings.blurCustomColor = resolvedColor
            }
        case .freeHand: settings.selectOrToggleDrawMode(.freeHand)
        case .arrow: settings.selectOrToggleDrawMode(.arrow)
        case .rectangle: settings.selectOrToggleDrawMode(.rectangle)
        case .circle: settings.selectOrToggleDrawMode(.circle)
        case .text: settings.selectOrToggleDrawMode(.text)
        case .highlighter: settings.selectOrToggleDrawMode(.highlighter)
        case .blur: settings.selectOrToggleDrawMode(.blur)
        case .clearAnnotate:
            isPostDrawAutoSelection = false
            canvasState.deleteSelectedOrClearAll()
        case .decreaseLineWeight:
            if shouldAdjustTextSizeForWeightShortcut {
                adjustTextFontSize(by: -2.0)
            } else if shouldAdjustBlurOpacityForWeightShortcut {
                settings.decreaseBlurOpacity()
                canvasState.updateSelectedBlurOpacity(settings.blurOpacity)
                clearBlurCache()
                onBlurOpacityChanged?(settings.blurOpacity)
            } else {
                adjustStrokeLineWeight(by: -2.0)
            }
        case .increaseLineWeight:
            if shouldAdjustTextSizeForWeightShortcut {
                adjustTextFontSize(by: 2.0)
            } else if shouldAdjustBlurOpacityForWeightShortcut {
                settings.increaseBlurOpacity()
                canvasState.updateSelectedBlurOpacity(settings.blurOpacity)
                clearBlurCache()
                onBlurOpacityChanged?(settings.blurOpacity)
            } else {
                adjustStrokeLineWeight(by: 2.0)
            }
        case .setLineWeight:
            if let digit = matched.lineWeightDigit {
                settings.setLineWeightFromDigit(digit)
                canvasState.updateSelectedStrokeLineWeight(settings.lineWeight)
                onLineWeightChanged?(settings.lineWeight)
            }
        case .touchDraw:
            settings.isTouchDrawActive.toggle()
        case .annotateWhiteboard:
            settings.isWhiteboardActive.toggle()
        case .saveScreenshot:
            onRequestSaveScreenshot?()
        case .copyScreenshot:
            if !canvasState.selectedIDs.isEmpty {
                canvasState.copySelectedAnnotations()
            } else {
                onRequestCopyScreenshot?()
            }
        case .pasteAnnotations:
            isPostDrawAutoSelection = false
            canvasState.pasteAnnotations()
        case .annotateShortcuts:
            settings.isShowingShortcutsCheatsheet.toggle()
        default:
            return false
        }

        syncBackdropBlurViews()
        needsDisplay = true
        return true
    }

    public func beginInlineTextEditing(at point: CGPoint, existingID: UUID? = nil) {
        let hasFinitePoint = point.x.isFinite && point.y.isFinite
        guard hasFinitePoint else { return }
        commitActiveTextEditing()
        let existingItem: AnnotationItem?
        if let existingID {
            existingItem = canvasState.annotations.first { item in
                let matchesID = item.id == existingID
                return matchesID && item.mode == .text
            }
        } else {
            existingItem = nil
        }

        let candidateOrigin = existingItem?.startPoint ?? point
        let hasFiniteCandidateOrigin = candidateOrigin.x.isFinite && candidateOrigin.y.isFinite
        let resolvedOrigin = hasFiniteCandidateOrigin ? candidateOrigin : point
        let hasFiniteResolvedOrigin = resolvedOrigin.x.isFinite && resolvedOrigin.y.isFinite
        guard hasFiniteResolvedOrigin else { return }

        editingAnnotationID = existingID
        canvasState.activeInlineEditingID = existingID
        let resolvedColor = existingItem?.strokeColor ?? settings.activeStrokeColor
        let resolvedFontName = existingItem?.fontName ?? settings.annotateFont.fontName
        let rawFontSize = existingItem?.fontSize ?? settings.annotateFontSize
        let resolvedFontSize = AnnotationItem.sanitizeFontSize(rawFontSize)
        let initialNSColor = resolvedColor.nsColor

        editingInitialTextColor = resolvedColor
        editingInitialNSColor = initialNSColor
        editingOverrideColor = nil
        editingInitialFontName = resolvedFontName
        editingInitialFontSize = resolvedFontSize
        editingOverrideFontSize = nil

        let rawDesiredWidth = existingItem.map { $0.textLayoutRect.width + 32.0 } ?? 260.0
        let desiredWidth = rawDesiredWidth.isFinite ? rawDesiredWidth : 260.0
        let hasValidBoundsWidth = bounds.width.isFinite && bounds.width > 260.0
        let maxCanvasWidth = hasValidBoundsWidth ? min(bounds.width, 1200.0) : 1200.0
        let fieldWidth = min(max(260.0, desiredWidth), maxCanvasWidth)
        let rawDesiredHeight = CGFloat(resolvedFontSize * 1.45)
        let desiredHeight = rawDesiredHeight.isFinite ? rawDesiredHeight : 36.0
        let fieldHeight = min(max(36.0, desiredHeight), 400.0)
        let hasValidFieldSize = fieldWidth.isFinite && fieldHeight.isFinite
        guard hasValidFieldSize else {
            clearEditingMetadata()
            return
        }
        let field = NSTextField(frame: NSRect(x: resolvedOrigin.x, y: resolvedOrigin.y, width: fieldWidth, height: fieldHeight))
        field.isBordered = true
        field.isBezeled = true
        field.drawsBackground = true
        field.backgroundColor = NSColor.black.withAlphaComponent(0.45)
        field.textColor = initialNSColor
        field.font = NSFont(name: resolvedFontName, size: CGFloat(resolvedFontSize))
            ?? NSFont.systemFont(ofSize: CGFloat(resolvedFontSize), weight: .semibold)
        if let existingItem {
            field.stringValue = AnnotationItem.clampText(existingItem.text)
        }
        if settings.annotateTextPlaceholder {
            field.placeholderString = "Type something..."
        }
        field.delegate = self
        field.target = self
        field.action = #selector(textFieldCommitted(_:))
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
        needsDisplay = true
    }

    public func commitActiveTextEditing() {
        guard let field = activeTextField else { return }
        let value = AnnotationItem.clampText(field.stringValue)
        let origin = field.frame.origin
        let editID = editingAnnotationID
        let resolvedColor: RGBColor
        if let currentNSColor = field.textColor {
            let matchesInitialColor = currentNSColor == editingInitialNSColor
            if let overrideColor = editingOverrideColor, currentNSColor == overrideColor.nsColor {
                resolvedColor = overrideColor
            } else if matchesInitialColor, let initialColor = editingInitialTextColor {
                resolvedColor = initialColor
            } else {
                resolvedColor = RGBColor(nsColor: currentNSColor)
            }
        } else {
            resolvedColor = editingOverrideColor ?? editingInitialTextColor ?? settings.activeStrokeColor
        }
        let resolvedFontName = editingInitialFontName ?? settings.annotateFont.fontName
        let liveEditedItem = editID.flatMap { targetID in
            canvasState.annotations.first { $0.id == targetID }
        }
        let rawResolvedFontSize: Double
        if let liveItem = liveEditedItem {
            let liveSize = AnnotationItem.sanitizeFontSize(liveItem.fontSize)
            let initialSize = AnnotationItem.sanitizeFontSize(editingInitialFontSize ?? liveSize)
            let wasLiveModified = abs(liveSize - initialSize) > 1e-6
            if wasLiveModified {
                rawResolvedFontSize = liveSize
            } else if let overrideSize = editingOverrideFontSize {
                rawResolvedFontSize = overrideSize
            } else if let fieldFont = field.font {
                let fieldSize = AnnotationItem.sanitizeFontSize(Double(fieldFont.pointSize))
                let matchesInitial = abs(fieldSize - initialSize) < 1e-6
                rawResolvedFontSize = matchesInitial ? initialSize : fieldSize
            } else {
                rawResolvedFontSize = initialSize
            }
        } else if let overrideSize = editingOverrideFontSize {
            rawResolvedFontSize = overrideSize
        } else if let fieldFont = field.font {
            let fieldSize = AnnotationItem.sanitizeFontSize(Double(fieldFont.pointSize))
            if let rawInitial = editingInitialFontSize {
                let initialSize = AnnotationItem.sanitizeFontSize(rawInitial)
                rawResolvedFontSize = abs(fieldSize - initialSize) < 1e-6 ? initialSize : fieldSize
            } else {
                rawResolvedFontSize = fieldSize
            }
        } else {
            rawResolvedFontSize = editingInitialFontSize ?? settings.annotateFontSize
        }
        let resolvedFontSize = AnnotationItem.sanitizeFontSize(rawResolvedFontSize)

        clearEditingMetadata()
        field.removeFromSuperview()
        activeTextField = nil

        if let committedID = canvasState.addOrUpdateTextAnnotation(
            id: editID,
            at: origin,
            text: value,
            color: resolvedColor,
            fontName: resolvedFontName,
            fontSize: resolvedFontSize,
            isAutoErase: settings.autoEraseEnabled
        ) {
            selectPostDrawAnnotation(committedID)
        } else {
            isPostDrawAutoSelection = false
        }
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    public func cancelActiveTextEditing() {
        clearEditingMetadata()
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func clearEditingMetadata() {
        canvasState.activeInlineEditingID = nil
        editingAnnotationID = nil
        editingInitialTextColor = nil
        editingInitialNSColor = nil
        editingOverrideColor = nil
        editingInitialFontName = nil
        editingInitialFontSize = nil
        editingOverrideFontSize = nil
    }

    @objc private func textFieldCommitted(_ sender: NSTextField) {
        commitActiveTextEditing()
    }

    public func controlTextDidChange(_ obj: Notification) {
        let targetField = (obj.object as? NSTextField) ?? activeTextField
        guard let field = targetField else { return }
        if let editor = field.currentEditor(), editor.string.count > AnnotationItem.maxTextLength {
            editor.string = AnnotationItem.clampText(editor.string)
        }
        if field.stringValue.count > AnnotationItem.maxTextLength {
            field.stringValue = AnnotationItem.clampText(field.stringValue)
        }
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelActiveTextEditing()
            return true
        }
        return false
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        syncBlurCacheState()

        if settings.isWhiteboardActive {
            context.setFillColor(
                settings.annotateWhiteboardColor.nsColor
                    .withAlphaComponent(CGFloat(settings.whiteboardOpacity))
                    .cgColor
            )
            context.fill(bounds)
        } else if settings.dimScreenOnAnnotate {
            context.setFillColor(NSColor.black.withAlphaComponent(CGFloat(settings.dimScreenOpacity)).cgColor)
            context.fill(bounds)
        }

        for item in canvasState.annotations {
            drawAnnotation(item, in: context, isSelected: canvasState.selectedIDs.contains(item.id))
        }
        if let draft = canvasState.activeDraft {
            drawAnnotation(draft, in: context, isSelected: false)
        }

        if let marquee = canvasState.selectionRectangle {
            context.saveGState()
            context.setFillColor(NSColor(SettingsView.themeLightBlue).withAlphaComponent(0.14).cgColor)
            context.setStrokeColor(NSColor(SettingsView.themeBlue).withAlphaComponent(0.80).cgColor)
            context.setLineWidth(1.5)
            context.fill(marquee)
            context.stroke(marquee)
            context.restoreGState()
        }

        if settings.annotateToolIndicator, let cursor = cursorLocation {
            drawToolIndicator(at: cursor, in: context)
        }
    }

    private func drawSelectedTextChrome(for item: AnnotationItem, in context: CGContext) {
        let selectionBox = item.textSelectionBox
        let hasFiniteOrigin = selectionBox.origin.x.isFinite && selectionBox.origin.y.isFinite
        let hasFiniteSize = selectionBox.size.width.isFinite && selectionBox.size.height.isFinite
        guard hasFiniteOrigin && hasFiniteSize else { return }

        let lightBlueCG = NSColor(SettingsView.themeLightBlue).cgColor
        let primaryBlueCG = NSColor(SettingsView.themeBlue).cgColor
        let whiteCG = NSColor.white.cgColor

        context.saveGState()
        context.setStrokeColor(lightBlueCG)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(selectionBox)

        let shouldShowTransformHandles = canvasState.selectedIDs.count == 1
        guard shouldShowTransformHandles else {
            context.restoreGState()
            return
        }

        let rotationCenter = item.localTextRotationHandleCenter
        let rotationRadius: CGFloat = 5.0
        context.setLineDash(phase: 0, lengths: [])
        context.beginPath()
        context.move(to: CGPoint(x: selectionBox.midX, y: selectionBox.maxY))
        context.addLine(to: CGPoint(x: rotationCenter.x, y: rotationCenter.y - rotationRadius))
        context.strokePath()

        let cornerRadius: CGFloat = 4.5
        for corner in item.localTextScaleHandleCenters {
            let handleRect = CGRect(
                x: corner.x - cornerRadius,
                y: corner.y - cornerRadius,
                width: cornerRadius * 2.0,
                height: cornerRadius * 2.0
            )
            context.setFillColor(whiteCG)
            context.fillEllipse(in: handleRect)
            context.setStrokeColor(primaryBlueCG)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: handleRect)
        }

        let rotationHandleRect = CGRect(
            x: rotationCenter.x - rotationRadius,
            y: rotationCenter.y - rotationRadius,
            width: rotationRadius * 2.0,
            height: rotationRadius * 2.0
        )
        context.setFillColor(whiteCG)
        context.fillEllipse(in: rotationHandleRect)
        context.setStrokeColor(primaryBlueCG)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: rotationHandleRect)
        context.restoreGState()
    }

    private func drawAnnotation(_ item: AnnotationItem, in context: CGContext, isSelected: Bool) {
        context.saveGState()
        if item.isHighlighter && item.mode != .blur {
            context.setBlendMode(.multiply)
        }

        let color = item.strokeColor.nsColor

        switch item.mode {
        case .text:
            let hasActiveField = activeTextField != nil
            let isEditingThisItem = hasActiveField && editingAnnotationID == item.id
            let hasFiniteOrigin = item.startPoint.x.isFinite && item.startPoint.y.isFinite
            if !isEditingThisItem && hasFiniteOrigin {
                let safeFontSize = AnnotationItem.sanitizeFontSize(item.fontSize)
                let font = NSFont(name: item.fontName, size: CGFloat(safeFontSize))
                    ?? NSFont.systemFont(ofSize: CGFloat(safeFontSize), weight: .semibold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let center = item.textCenter
                let angle = item.effectiveRotationRadians
                let hasFiniteCenter = center.x.isFinite && center.y.isFinite
                let boundedText = AnnotationItem.clampText(item.text)
                context.saveGState()
                if hasFiniteCenter && angle != 0.0 {
                    context.translateBy(x: center.x, y: center.y)
                    context.rotate(by: CGFloat(angle))
                    context.translateBy(x: -center.x, y: -center.y)
                }
                (boundedText as NSString).draw(at: item.startPoint, withAttributes: attrs)
                if isSelected {
                    drawSelectedTextChrome(for: item, in: context)
                }
                context.restoreGState()
            }
        case .arrow:
            drawDirectionalPolygon(item, in: context)
        case .rectangle, .circle:
            let path = buildCGPath(for: item)
            if item.isFilled {
                context.addPath(path)
                context.setFillColor(color.withAlphaComponent(0.28).cgColor)
                context.fillPath()
            }
            strokePath(path, item: item, color: color, in: context)
        case .freeHand, .highlighter:
            if item.usesTaperedWedgeLine {
                drawDirectionalPolygon(item, in: context)
            } else {
                let path = buildCGPath(for: item)
                strokePath(path, item: item, color: color, in: context)
            }
        case .blur:
            if let visibleRect = validatedVisibleBlurRect(for: item) {
                let isDraft = canvasState.activeDraft?.id == item.id
                let hasCaptureDimensions = visibleRect.width >= 2.0 && visibleRect.height >= 2.0
                let blurredImage = resolveCapturedBlurImage(for: item, visibleRect: visibleRect)
                let isScreenDestination = NSGraphicsContext.current?.isDrawingToScreen ?? false
                let isLiveScreenRender = isScreenDestination && !isCachingOffscreenDisplay
                let hasMountedBackdrop = backdropBlurViews[item.id]?.superview === self
                let hasWindowedBackdrop = hasMountedBackdrop && window != nil
                let canUseLiveBackdrop = !settings.isWhiteboardActive && hasCaptureDimensions
                let usesLiveBackdrop = blurredImage == nil && canUseLiveBackdrop
                let hasActiveLiveBackdrop = usesLiveBackdrop && hasWindowedBackdrop
                let shouldLeaveClearForBackdrop = hasActiveLiveBackdrop && isLiveScreenRender

                if shouldLeaveClearForBackdrop {
                    context.clear(visibleRect)
                } else {
                    context.saveGState()
                    context.clip(to: visibleRect)
                    if let blurredImage {
                        context.setFillColor(NSColor(srgbRed: 0.14, green: 0.18, blue: 0.24, alpha: 1.0).cgColor)
                        context.fill(visibleRect)
                        context.interpolationQuality = .high
                        context.draw(blurredImage, in: visibleRect)
                        if let tint = item.blurTintColor {
                            let tintAlpha = CGFloat(0.12 + item.effectiveBlurOpacity * 0.78)
                            context.setFillColor(tint.nsColor.withAlphaComponent(tintAlpha).cgColor)
                            context.fill(visibleRect)
                        } else {
                            let neutralVeilAlpha = max(0.0, (item.effectiveBlurOpacity - 0.65) * 0.85)
                            if neutralVeilAlpha > 0 {
                                context.setFillColor(NSColor.white.withAlphaComponent(CGFloat(neutralVeilAlpha)).cgColor)
                                context.fill(visibleRect)
                            }
                        }
                    } else {
                        let baseColor: NSColor
                        let tileColor: NSColor
                        if let tint = item.blurTintColor {
                            let mix = min(max(0.25 + item.effectiveBlurOpacity * 0.65, 0.0), 1.0)
                            let tR = tint.red.isFinite ? min(max(tint.red, 0.0), 1.0) : 0.0
                            let tG = tint.green.isFinite ? min(max(tint.green, 0.0), 1.0) : 0.0
                            let tB = tint.blue.isFinite ? min(max(tint.blue, 0.0), 1.0) : 0.0
                            baseColor = NSColor(
                                srgbRed: CGFloat(0.14 * (1.0 - mix) + tR * mix),
                                green: CGFloat(0.18 * (1.0 - mix) + tG * mix),
                                blue: CGFloat(0.24 * (1.0 - mix) + tB * mix),
                                alpha: 1.0
                            )
                            tileColor = NSColor(
                                srgbRed: CGFloat(0.20 * (1.0 - mix) + tR * mix),
                                green: CGFloat(0.26 * (1.0 - mix) + tG * mix),
                                blue: CGFloat(0.34 * (1.0 - mix) + tB * mix),
                                alpha: 1.0
                            )
                        } else {
                            baseColor = NSColor(srgbRed: 0.14, green: 0.18, blue: 0.24, alpha: 1.0)
                            tileColor = NSColor(srgbRed: 0.20, green: 0.26, blue: 0.34, alpha: 1.0)
                        }
                        context.setFillColor(baseColor.cgColor)
                        context.fill(visibleRect)
                        let tileSize = max(10.0, max(visibleRect.width, visibleRect.height) / 32.0)
                        let cols = Int(ceil(visibleRect.width / tileSize))
                        let rows = Int(ceil(visibleRect.height / tileSize))
                        context.setFillColor(tileColor.cgColor)
                        for row in 0..<rows {
                            for col in 0..<cols where (row + col).isMultiple(of: 2) {
                                let tileRect = CGRect(
                                    x: visibleRect.minX + CGFloat(col) * tileSize,
                                    y: visibleRect.minY + CGFloat(row) * tileSize,
                                    width: tileSize,
                                    height: tileSize
                                )
                                context.fill(tileRect)
                            }
                        }
                    }
                    context.restoreGState()

                    if isDraft {
                        context.setStrokeColor(NSColor(SettingsView.themeBlue).cgColor)
                        context.setLineWidth(1.5)
                        context.stroke(visibleRect)
                    }
                }
            }
        }
        context.restoreGState()

        if isSelected && item.usesDirectionalHandles {
            let tail = item.tailHandleCenter
            let tip = item.tipHandleCenter
            let lightBlueNS = NSColor(SettingsView.themeLightBlue)
            let lightBlueCG = lightBlueNS.cgColor
            context.saveGState()
            context.setBlendMode(.normal)
            context.setStrokeColor(lightBlueCG)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.beginPath()
            context.move(to: tail)
            context.addLine(to: tip)
            context.strokePath()

            if canvasState.selectedIDs.count == 1 {
                let axisAnchor = item.headScaleAxisAnchor
                let headHandle = item.headScaleHandleCenter
                context.setLineDash(phase: 0, lengths: [3, 2])
                context.beginPath()
                context.move(to: axisAnchor)
                context.addLine(to: headHandle)
                context.strokePath()

                context.setLineDash(phase: 0, lengths: [])
                let endpointRadius: CGFloat = 5.0
                let whiteCG = NSColor.white.cgColor
                let primaryBlueCG = NSColor(SettingsView.themeBlue).cgColor
                for endpoint in [tail, tip] {
                    let handleRect = CGRect(
                        x: endpoint.x - endpointRadius,
                        y: endpoint.y - endpointRadius,
                        width: endpointRadius * 2.0,
                        height: endpointRadius * 2.0
                    )
                    context.setFillColor(whiteCG)
                    context.fillEllipse(in: handleRect)
                    context.setStrokeColor(primaryBlueCG)
                    context.setLineWidth(2.0)
                    context.strokeEllipse(in: handleRect)
                }

                let haloRadius: CGFloat = 8.5
                let haloRect = CGRect(
                    x: headHandle.x - haloRadius,
                    y: headHandle.y - haloRadius,
                    width: haloRadius * 2.0,
                    height: haloRadius * 2.0
                )
                context.setFillColor(lightBlueNS.withAlphaComponent(0.24).cgColor)
                context.fillEllipse(in: haloRect)

                let innerRadius: CGFloat = 5.5
                let innerRect = CGRect(
                    x: headHandle.x - innerRadius,
                    y: headHandle.y - innerRadius,
                    width: innerRadius * 2.0,
                    height: innerRadius * 2.0
                )
                context.setFillColor(lightBlueCG)
                context.fillEllipse(in: innerRect)
                context.setStrokeColor(whiteCG)
                context.setLineWidth(2.0)
                context.strokeEllipse(in: innerRect)
            }
            context.restoreGState()
        } else if isSelected && item.mode != .text {
            if let selectionBox = visibleNonTextSelectionBox(for: item) {
                context.saveGState()
                context.setBlendMode(.normal)
                context.setStrokeColor(NSColor(SettingsView.themeLightBlue).cgColor)
                context.setLineWidth(1.5)
                context.setLineDash(phase: 0, lengths: [4, 3])
                context.stroke(selectionBox)

                if canvasState.selectedIDs.count == 1 {
                    let cornerRadius: CGFloat = 4.5
                    let whiteCG = NSColor.white.cgColor
                    let primaryBlueCG = NSColor(SettingsView.themeBlue).cgColor
                    let corners = [
                        CGPoint(x: selectionBox.minX, y: selectionBox.minY),
                        CGPoint(x: selectionBox.maxX, y: selectionBox.minY),
                        CGPoint(x: selectionBox.maxX, y: selectionBox.maxY),
                        CGPoint(x: selectionBox.minX, y: selectionBox.maxY)
                    ]
                    context.setLineDash(phase: 0, lengths: [])
                    for corner in corners {
                        let handleRect = CGRect(
                            x: corner.x - cornerRadius,
                            y: corner.y - cornerRadius,
                            width: cornerRadius * 2.0,
                            height: cornerRadius * 2.0
                        )
                        context.setFillColor(whiteCG)
                        context.fillEllipse(in: handleRect)
                        context.setStrokeColor(primaryBlueCG)
                        context.setLineWidth(1.5)
                        context.strokeEllipse(in: handleRect)
                    }
                }
                context.restoreGState()
            }
        }
    }

    private func drawDirectionalPolygon(_ item: AnnotationItem, in context: CGContext) {
        let hasFiniteStart = item.startPoint.x.isFinite && item.startPoint.y.isFinite
        let hasFiniteEnd = item.endPoint.x.isFinite && item.endPoint.y.isFinite
        guard hasFiniteStart && hasFiniteEnd else { return }

        let polygonPath = buildCGPath(for: item)
        guard !polygonPath.isEmpty else { return }
        let rawBox = polygonPath.boundingBoxOfPath
        let hasFiniteRawOrigin = rawBox.origin.x.isFinite && rawBox.origin.y.isFinite
        let hasFiniteRawSize = rawBox.size.width.isFinite && rawBox.size.height.isFinite
        let isRawBoxFinite = hasFiniteRawOrigin && hasFiniteRawSize
        guard !rawBox.isNull && isRawBoxFinite else { return }

        let paddedBox = rawBox.insetBy(dx: -14.0, dy: -14.0)
        let hasFinitePaddedOrigin = paddedBox.origin.x.isFinite && paddedBox.origin.y.isFinite
        let hasFinitePaddedSize = paddedBox.size.width.isFinite && paddedBox.size.height.isFinite
        let isPaddedBoxFinite = hasFinitePaddedOrigin && hasFinitePaddedSize
        guard !paddedBox.isNull && isPaddedBoxFinite else { return }

        let hasFiniteBoundsOrigin = bounds.origin.x.isFinite && bounds.origin.y.isFinite
        let hasFiniteBoundsSize = bounds.size.width.isFinite && bounds.size.height.isFinite
        let isBoundsFinite = hasFiniteBoundsOrigin && hasFiniteBoundsSize
        guard isBoundsFinite else { return }

        let hasPositiveBounds = bounds.width > 0 && bounds.height > 0
        let visibleLayerRect = hasPositiveBounds ? paddedBox.intersection(bounds) : paddedBox
        let isVisibleNonEmpty = !visibleLayerRect.isNull && !visibleLayerRect.isEmpty
        let hasFiniteVisibleOrigin = visibleLayerRect.origin.x.isFinite && visibleLayerRect.origin.y.isFinite
        let hasFiniteVisibleSize = visibleLayerRect.size.width.isFinite && visibleLayerRect.size.height.isFinite
        let isVisibleFinite = hasFiniteVisibleOrigin && hasFiniteVisibleSize
        let isVisibleBounded = visibleLayerRect.width <= 16_384.0 && visibleLayerRect.height <= 16_384.0
        let canRenderVisible = isVisibleNonEmpty && isVisibleFinite
        guard canRenderVisible && isVisibleBounded else { return }

        if item.tailFadeEnabled {
            let dx = Double(item.endPoint.x - item.startPoint.x)
            let dy = Double(item.endPoint.y - item.startPoint.y)
            let length = hypot(dx, dy)
            if length.isFinite && length > 1e-3 {
                let usesHeadAccents = !item.isHighlighter
                context.saveGState()
                if usesHeadAccents {
                    context.setShadow(
                        offset: CGSize(width: 0, height: -2.0),
                        blur: 5.0,
                        color: NSColor.black.withAlphaComponent(0.36).cgColor
                    )
                    context.beginTransparencyLayer(in: visibleLayerRect, auxiliaryInfo: nil)
                }

                context.saveGState()
                context.addPath(polygonPath)
                context.clip()
                let startRGB = (item.gradientPair?.startColor ?? item.strokeColor).sanitized
                let endRGB = (item.gradientPair?.endColor ?? item.strokeColor).sanitized
                let startBaseAlpha = item.isHighlighter ? min(startRGB.alpha, 0.42) : startRGB.alpha
                let endBaseAlpha = item.isHighlighter ? min(endRGB.alpha, 0.42) : endRGB.alpha
                let locations: [CGFloat] = [0.0, 0.42, 0.74, 1.0]
                let multipliers: [Double] = [0.02, 0.32, 0.96, 1.00]
                var stopColors: [CGColor] = []
                stopColors.reserveCapacity(locations.count)
                for idx in 0..<locations.count {
                    let t = Double(locations[idx])
                    let mult = multipliers[idx]
                    let r = startRGB.red + (endRGB.red - startRGB.red) * t
                    let g = startRGB.green + (endRGB.green - startRGB.green) * t
                    let b = startRGB.blue + (endRGB.blue - startRGB.blue) * t
                    let baseAlpha = startBaseAlpha + (endBaseAlpha - startBaseAlpha) * t
                    let stopAlpha = min(max(baseAlpha * mult, 0.0), 1.0)
                    let stopColor = NSColor(
                        srgbRed: CGFloat(r),
                        green: CGFloat(g),
                        blue: CGFloat(b),
                        alpha: CGFloat(stopAlpha)
                    )
                    stopColors.append(stopColor.cgColor)
                }
                if let space = CGColorSpace(name: CGColorSpace.sRGB),
                   let cgGradient = CGGradient(colorsSpace: space, colors: stopColors as CFArray, locations: locations) {
                    context.drawLinearGradient(
                        cgGradient,
                        start: item.startPoint,
                        end: item.endPoint,
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                }
                context.restoreGState()

                if usesHeadAccents {
                    context.saveGState()
                    context.addPath(polygonPath)
                    context.setLineWidth(1.5)
                    context.setLineJoin(.round)
                    context.replacePathWithStrokedPath()
                    context.clip()
                    let rimLocations: [CGFloat] = [0.0, 0.52, 0.78, 1.0]
                    let rimColors: [CGColor] = [
                        NSColor.white.withAlphaComponent(0.0).cgColor,
                        NSColor.white.withAlphaComponent(0.0).cgColor,
                        NSColor.white.withAlphaComponent(0.78).cgColor,
                        NSColor.white.withAlphaComponent(0.95).cgColor
                    ]
                    if let space = CGColorSpace(name: CGColorSpace.sRGB),
                       let rimGradient = CGGradient(colorsSpace: space, colors: rimColors as CFArray, locations: rimLocations) {
                        context.drawLinearGradient(
                            rimGradient,
                            start: item.startPoint,
                            end: item.endPoint,
                            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                        )
                    }
                    context.restoreGState()
                    context.endTransparencyLayer()
                }
                context.restoreGState()
                return
            }
        }

        if let gradient = item.gradientPair {
            let effectiveGradient: GradientPair
            if item.isHighlighter {
                let sAlpha = min(gradient.startColor.sanitized.alpha, 0.42)
                let eAlpha = min(gradient.endColor.sanitized.alpha, 0.42)
                effectiveGradient = GradientPair(
                    startColor: gradient.startColor.withAlpha(sAlpha),
                    endColor: gradient.endColor.withAlpha(eAlpha)
                )
            } else {
                effectiveGradient = gradient
            }
            context.addPath(polygonPath)
            context.clip()
            drawLinearGradient(effectiveGradient, from: item.startPoint, to: item.endPoint, in: context)
        } else {
            let baseColor = item.strokeColor.sanitized
            let resolvedColor = item.isHighlighter
                ? baseColor.withAlpha(min(baseColor.alpha, 0.42)).nsColor
                : baseColor.nsColor
            context.addPath(polygonPath)
            context.setFillColor(resolvedColor.cgColor)
            context.fillPath()
        }
    }

    private func strokePath(_ path: CGPath, item: AnnotationItem, color: NSColor, in context: CGContext) {
        let clampedWeight = item.lineWeight.isFinite ? min(max(item.lineWeight, 1.0), 64.0) : 6.0
        context.setLineWidth(CGFloat(clampedWeight))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)

        if let gradient = item.gradientPair {
            context.replacePathWithStrokedPath()
            context.clip()
            let box = item.boundingRect
            drawLinearGradient(
                gradient,
                from: CGPoint(x: box.minX, y: box.minY),
                to: CGPoint(x: box.maxX, y: box.maxY),
                in: context
            )
        } else {
            context.setStrokeColor(color.cgColor)
            context.strokePath()
        }
    }

    private func drawLinearGradient(
        _ pair: GradientPair,
        from start: CGPoint,
        to end: CGPoint,
        in context: CGContext
    ) {
        let colors = [pair.startColor.nsColor.cgColor, pair.endColor.nsColor.cgColor] as CFArray
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cgGradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) else {
            return
        }
        context.drawLinearGradient(cgGradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func buildCGPath(for item: AnnotationItem) -> CGPath {
        let path = CGMutablePath()
        switch item.mode {
        case .freeHand, .highlighter:
            if item.usesTaperedWedgeLine {
                let vertices = item.taperedLinePolygonPoints()
                if let first = vertices.first {
                    let isFirstFinite = first.x.isFinite && first.y.isFinite
                    if isFirstFinite {
                        path.move(to: first)
                        for pt in vertices.dropFirst() where pt.x.isFinite && pt.y.isFinite {
                            path.addLine(to: pt)
                        }
                        path.closeSubpath()
                    }
                }
            } else {
                guard let first = item.points.first else { return path }
                let isFirstFinite = first.x.isFinite && first.y.isFinite
                guard isFirstFinite else { return path }
                path.move(to: first)
                for pt in item.points.dropFirst() where pt.x.isFinite && pt.y.isFinite {
                    path.addLine(to: pt)
                }
            }
        case .arrow:
            let vertices = item.arrowPolygonPoints()
            if let first = vertices.first {
                let isFirstFinite = first.x.isFinite && first.y.isFinite
                if isFirstFinite {
                    path.move(to: first)
                    for pt in vertices.dropFirst() where pt.x.isFinite && pt.y.isFinite {
                        path.addLine(to: pt)
                    }
                    path.closeSubpath()
                }
            }
        case .rectangle, .blur, .text:
            let box = item.boundingRect
            let hasFiniteOrigin = box.origin.x.isFinite && box.origin.y.isFinite
            let hasFiniteSize = box.size.width.isFinite && box.size.height.isFinite
            if hasFiniteOrigin && hasFiniteSize {
                path.addRect(box)
            }
        case .circle:
            let box = item.boundingRect
            let hasFiniteOrigin = box.origin.x.isFinite && box.origin.y.isFinite
            let hasFiniteSize = box.size.width.isFinite && box.size.height.isFinite
            if hasFiniteOrigin && hasFiniteSize {
                path.addEllipse(in: box)
            }
        }
        return path
    }

    private func drawToolIndicator(at cursor: CGPoint, in context: CGContext) {
        let hasFiniteCursor = cursor.x.isFinite && cursor.y.isFinite
        guard hasFiniteCursor else { return }
        context.saveGState()
        let badgeCenter = CGPoint(x: cursor.x + 14, y: cursor.y - 14)
        let safeWeight = settings.lineWeight.isFinite ? settings.lineWeight : 6.0
        let radius = max(4.0, min(12.0, CGFloat(safeWeight * 0.5)))
        let badgeRect = CGRect(
            x: badgeCenter.x - radius,
            y: badgeCenter.y - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        context.setFillColor(settings.activeStrokeColor.nsColor.cgColor)
        context.fillEllipse(in: badgeRect)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: badgeRect)
        context.restoreGState()
    }

    private func touchPoint(for touch: NSTouch) -> CGPoint {
        let normalized = touch.normalizedPosition
        return CGPoint(
            x: bounds.origin.x + normalized.x * bounds.size.width,
            y: bounds.origin.y + normalized.y * bounds.size.height
        )
    }
}

public final class AnnotateOverlayController {
    public let settings: AppSettings
    public let shortcutManager: ShortcutManager
    public let canvasState: AnnotationCanvasState
    public let toastController: ToastWindowController

    public private(set) var panel: AnnotatePanel?
    public private(set) var canvasView: AnnotateCanvasView?
    public private(set) var controlsPanel: FloatingControlPanel?
    public private(set) var shortcutsPanel: FloatingControlPanel?
    public var onRequestOpenSettings: (() -> Void)?

    private let captureManager = ScreenCaptureManager()
    private var autoEraseTimer: Timer?
    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []
    private static let savedSessionKey = "presentify.savedAnnotationSession"

    public init(
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared,
        canvasState: AnnotationCanvasState = AnnotationCanvasState()
    ) {
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.canvasState = canvasState
        self.toastController = ToastWindowController(settings: settings)

        captureManager.onFirstFrameCaptured = { [weak self] in
            guard let self, self.settings.isAnnotating else { return }
            self.canvasView?.clearBlurCache()
        }

        if settings.annotateSaveSession,
           let savedData = settings.defaults.data(forKey: Self.savedSessionKey) {
            canvasState.importSessionData(savedData)
        }

        bindSettings()
    }

    deinit {
        stopTimersAndMonitors()
        captureManager.stopStream()
    }

    public func toggleAnnotation() {
        if settings.isAnnotating {
            hideAnnotation()
        } else {
            showAnnotation()
        }
    }

    public func toggleAnnotateControls() {
        if !settings.isAnnotating {
            settings.showAnnotateControls = true
            showAnnotation()
        } else {
            settings.showAnnotateControls.toggle()
            updateAuxiliaryPanels()
        }
    }

    public func showAnnotation() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        if panel == nil {
            let newPanel = AnnotatePanel(contentRect: screenFrame)
            let view = AnnotateCanvasView(
                frame: NSRect(origin: .zero, size: screenFrame.size),
                canvasState: canvasState,
                settings: settings,
                shortcutManager: shortcutManager
            )
            view.onRequestSaveScreenshot = { [weak self] in self?.saveScreenshot() }
            view.onRequestCopyScreenshot = { [weak self] in self?.copyScreenshot() }
            view.onRequestClose = { [weak self] in self?.hideAnnotation() }
            view.onRequestOpenSettings = { [weak self] in self?.onRequestOpenSettings?() }
            view.onLineWeightChanged = { [weak self] weight in
                let safeWeight = weight.isFinite ? min(max(weight, 1.0), 64.0) : 6.0
                self?.toastController.showToast(.lineWeight, message: "Line Weight: \(Int(safeWeight.rounded())) pt")
            }
            view.onBlurOpacityChanged = { [weak self] opacity in
                let safeOpacity = opacity.isFinite ? min(max(opacity, 0.10), 1.00) : 0.55
                self?.toastController.showToast(
                    .lineWeight,
                    message: "Blur Opacity: \(Int((safeOpacity * 100.0).rounded()))%"
                )
            }
            view.onTextSizeChanged = { [weak self] fontSize in
                let safeSize = AnnotationItem.sanitizeFontSize(fontSize)
                self?.toastController.showToast(
                    .lineWeight,
                    message: "Text Size: \(Int(safeSize.rounded())) pt"
                )
            }
            view.exclusionScreenRectsProvider = { [weak self] in
                self?.visibleAuxiliaryPanelRects() ?? []
            }
            view.regionCaptureProvider = { [weak self, weak view] viewRect in
                guard let self, let view else { return nil }
                guard let panel = self.panel else { return nil }
                let isBundledApp = Bundle.main.bundleURL.pathExtension == "app"
                guard isBundledApp && !self.settings.isWhiteboardActive else { return nil }
                let windowRect = view.convert(viewRect, to: nil)
                let screenRect = panel.convertToScreen(windowRect)
                let windowID = panel.windowNumber > 0 ? CGWindowID(panel.windowNumber) : nil
                return self.captureManager.captureScreenRect(screenRect, excludingWindowID: windowID)
            }
            newPanel.contentView = view
            self.panel = newPanel
            self.canvasView = view
        }

        panel?.setFrame(screenFrame, display: true)
        canvasView?.frame = NSRect(origin: .zero, size: screenFrame.size)
        panel?.updateBackground(from: settings)
        updateInteractivePassThrough(modifierFlags: NSEvent.modifierFlags)
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(canvasView)

        settings.isAnnotating = true
        updateBlurCaptureStream()
        canvasView?.syncBackdropBlurViews()
        updateAuxiliaryPanels()
        startTimersAndMonitors()

        if settings.annotateInteractiveMode {
            toastController.showToast(
                .interactiveMode,
                message: "Interactive Mode active: Hold \(settings.interactiveModeKey.title) to draw"
            )
        }
    }

    public func hideAnnotation() {
        canvasView?.commitActiveTextEditing()
        canvasView?.cancelActiveInteraction()
        if settings.annotateSaveSession, let data = canvasState.exportSessionData() {
            settings.defaults.set(data, forKey: Self.savedSessionKey)
        } else if !settings.annotateSaveSession {
            canvasState.clearAll()
        }

        stopTimersAndMonitors()
        captureManager.stopStream()
        CustomColorPanelBridge.shared.close()
        controlsPanel?.orderOut(nil)
        shortcutsPanel?.orderOut(nil)
        panel?.orderOut(nil)
        toastController.dismiss()
        settings.isAnnotating = false
        canvasView?.clearBlurCache()
        canvasView?.removeAllBackdropBlurViews()
    }

    @discardableResult
    public func saveScreenshot() -> URL? {
        guard let view = canvasView else { return nil }
        return Screenshotter.saveViewScreenshot(view, directoryPath: settings.screenshotSaveDirectoryPath)
    }

    @discardableResult
    public func copyScreenshot() -> Bool {
        guard let view = canvasView else { return false }
        return Screenshotter.copyViewScreenshotToPasteboard(view)
    }

    public func updateInteractivePassThrough(modifierFlags: NSEvent.ModifierFlags) {
        guard let panel else { return }
        let previousIgnores = panel.ignoresMouseEvents
        if !settings.annotateInteractiveMode {
            panel.ignoresMouseEvents = false
        } else {
            let isHoldKeyActive: Bool
            switch settings.interactiveModeKey {
            case .fn:
                isHoldKeyActive = modifierFlags.contains(.function)
            case .capsLock:
                isHoldKeyActive = modifierFlags.contains(.capsLock)
            }
            panel.ignoresMouseEvents = !isHoldKeyActive
        }
        if panel.ignoresMouseEvents {
            canvasView?.cancelActiveInteraction()
        }
        if panel.ignoresMouseEvents != previousIgnores {
            canvasView?.clearBlurCache()
        }
    }

    private func updateBlurCaptureStream() {
        let canCaptureOverlay = settings.isAnnotating && !settings.isWhiteboardActive
        let hasBlurAnnotation = canvasState.annotations.contains { $0.mode == .blur }
        let needsBlurStream = settings.currentDrawMode == .blur || hasBlurAnnotation
        guard canCaptureOverlay && needsBlurStream else {
            captureManager.stopStream()
            return
        }
        let windowID = panel.flatMap { $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil }
        let targetScreen = panel?.screen ?? NSScreen.main
        let preferredDisplayID = targetScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        captureManager.startStream(excludingWindowID: windowID, preferredDisplayID: preferredDisplayID)
    }

    private func visibleAuxiliaryPanelRects() -> [NSRect] {
        var rects: [NSRect] = []
        if settings.showAnnotateControls, let controlsPanel, controlsPanel.isVisible {
            rects.append(controlsPanel.frame)
        }
        if settings.isShowingShortcutsCheatsheet, let shortcutsPanel, shortcutsPanel.isVisible {
            rects.append(shortcutsPanel.frame)
        }
        if NSColorPanel.sharedColorPanelExists && NSColorPanel.shared.isVisible {
            rects.append(NSColorPanel.shared.frame)
        }
        return rects
    }

    private func bindSettings() {
        settings.$currentDrawMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.settings.isAnnotating else { return }
                self.canvasView?.commitActiveTextEditing()
                self.updateBlurCaptureStream()
                self.updateAuxiliaryPanels()
                self.panel?.makeKey()
                self.panel?.makeFirstResponder(self.canvasView)
                self.canvasView?.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$blurOpacity
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] newOpacity in
                guard let self else { return }
                self.canvasState.updateSelectedBlurOpacity(newOpacity)
                self.canvasView?.clearBlurCache()
            }
            .store(in: &cancellables)

        settings.$blurStyle
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] newStyle in
                guard let self else { return }
                self.canvasState.updateSelectedBlurStyle(newStyle)
                self.canvasView?.clearBlurCache()
            }
            .store(in: &cancellables)

        settings.$blurUseCustomColor
            .combineLatest(settings.$blurCustomColor)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.canvasState.updateSelectedBlurTintColor(self.settings.activeBlurTintColor)
                self.canvasView?.clearBlurCache()
                self.updateAuxiliaryPanels()
            }
            .store(in: &cancellables)

        settings.$whiteboardEnabled
            .combineLatest(settings.$whiteboardColor, settings.$dimScreenOnAnnotate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.panel?.updateBackground(from: self.settings)
                if self.settings.isAnnotating {
                    self.updateBlurCaptureStream()
                }
                self.canvasView?.clearBlurCache()
                self.canvasView?.syncBackdropBlurViews()
                self.canvasView?.needsDisplay = true
            }
            .store(in: &cancellables)

        canvasState.$annotations
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.settings.isAnnotating else { return }
                self.updateBlurCaptureStream()
            }
            .store(in: &cancellables)

        canvasState.$selectedIDs
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.settings.isAnnotating else { return }
                self.updateAuxiliaryPanels()
            }
            .store(in: &cancellables)

        settings.$touchDrawEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self, enabled, self.settings.isAnnotating else { return }
                self.toastController.showToast(.touchDraw, message: "Touch Draw enabled: Draw with 1 finger on trackpad")
            }
            .store(in: &cancellables)

        settings.$selectedColorIndex
            .combineLatest(settings.$favColors, settings.$useRandomColors, settings.$enableGradients)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self, self.settings.isAnnotating else { return }
                self.canvasView?.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$isShowingShortcutsCheatsheet
            .combineLatest(settings.$annotateControlsVertical)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateAuxiliaryPanels() }
            .store(in: &cancellables)
    }

    private func updateAuxiliaryPanels() {
        guard settings.isAnnotating else {
            controlsPanel?.orderOut(nil)
            shortcutsPanel?.orderOut(nil)
            return
        }

        if settings.showAnnotateControls {
            if controlsPanel == nil {
                let toolbarView = AnnotateControlsView(
                    settings: settings,
                    canvasState: canvasState,
                    onUndo: { [weak self] in self?.canvasState.undo() },
                    onRedo: { [weak self] in self?.canvasState.redo() },
                    onSaveScreenshot: { [weak self] in _ = self?.saveScreenshot() },
                    onClear: { [weak self] in self?.canvasState.clearAll() },
                    onToggleShortcuts: { [weak self] in self?.settings.isShowingShortcutsCheatsheet.toggle() },
                    onClose: { [weak self] in self?.hideAnnotation() },
                    onTextSizeChanged: { [weak self] fontSize in
                        let safeSize = AnnotationItem.sanitizeFontSize(fontSize)
                        self?.toastController.showToast(
                            .lineWeight,
                            message: "Text Size: \(Int(safeSize.rounded())) pt"
                        )
                    }
                )
                let hosting = FirstMouseHostingView(rootView: toolbarView)
                let fitting = hosting.fittingSize
                let width = fitting.width > 0 ? fitting.width : 720
                let height = fitting.height > 0 ? fitting.height : 52
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let cPanel = FloatingControlPanel(contentRect: hosting.frame)
                cPanel.onKeyDown = { [weak self] event in
                    self?.canvasView?.handleKeyCommand(
                        keyCode: event.keyCode,
                        modifiers: event.modifierFlags.rawValue
                    ) ?? false
                }
                cPanel.contentView = hosting
                if let visible = NSScreen.main?.visibleFrame {
                    cPanel.setFrameOrigin(NSPoint(x: visible.midX - width * 0.5, y: visible.minY + 36))
                }
                controlsPanel = cPanel
            } else if let cPanel = controlsPanel, let hosting = cPanel.contentView {
                hosting.layoutSubtreeIfNeeded()
                let fitting = hosting.fittingSize
                let hasValidFittingSize = fitting.width > 0 && fitting.height > 0
                if hasValidFittingSize && cPanel.frame.size != fitting {
                    cPanel.setContentSize(fitting)
                    hosting.frame = NSRect(origin: .zero, size: fitting)
                }
            }
            controlsPanel?.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
            controlsPanel?.orderFrontRegardless()
        } else {
            controlsPanel?.orderOut(nil)
        }

        if settings.isShowingShortcutsCheatsheet {
            if shortcutsPanel == nil {
                let hud = AnnotateShortcutsView(
                    shortcutManager: shortcutManager,
                    onClose: { [weak self] in self?.settings.isShowingShortcutsCheatsheet = false }
                )
                let hosting = FirstMouseHostingView(rootView: hud)
                let fitting = hosting.fittingSize
                let width = fitting.width > 0 ? fitting.width : 560
                let height = fitting.height > 0 ? fitting.height : 440
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let sPanel = FloatingControlPanel(contentRect: hosting.frame)
                sPanel.onKeyDown = { [weak self] event in
                    self?.canvasView?.handleKeyCommand(
                        keyCode: event.keyCode,
                        modifiers: event.modifierFlags.rawValue
                    ) ?? false
                }
                sPanel.contentView = hosting
                if let visible = NSScreen.main?.visibleFrame {
                    sPanel.setFrameOrigin(NSPoint(x: visible.midX - width * 0.5, y: visible.midY - height * 0.5))
                }
                shortcutsPanel = sPanel
            }
            shortcutsPanel?.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
            shortcutsPanel?.orderFrontRegardless()
        } else {
            shortcutsPanel?.orderOut(nil)
        }
    }

    private func startTimersAndMonitors() {
        stopTimersAndMonitors()
        autoEraseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.canvasState.pruneExpiredAnnotations(delay: self.settings.autoEraseDelay)
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateInteractivePassThrough(modifierFlags: event.modifierFlags)
            return event
        }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.settings.isAnnotating else { return event }
            if self.canvasView?.activeTextField != nil, event.keyCode != 0x35 {
                return event
            }
            if self.canvasView?.handleKeyCommand(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.rawValue
            ) == true {
                return nil
            }
            return event
        }
    }

    private func stopTimersAndMonitors() {
        autoEraseTimer?.invalidate()
        autoEraseTimer = nil
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}
