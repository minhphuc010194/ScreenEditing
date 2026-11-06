import AppKit
import CoreEngine
import Foundation
import SwiftUI

public enum DrawMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case freeHand
    case arrow
    case rectangle
    case circle
    case text
    case highlighter
    case blur

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .freeHand: return "Free Hand"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .text: return "Text"
        case .highlighter: return "Highlighter"
        case .blur: return "Blur"
        }
    }

    public var displayName: String { title }

    public var systemImage: String {
        switch self {
        case .freeHand: return "scribble"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .text: return "textformat"
        case .highlighter: return "highlighter"
        case .blur: return "checkerboard.rectangle"
        }
    }

    public var iconName: String { systemImage }

    public var supportsStrokeLineWeight: Bool {
        switch self {
        case .freeHand, .arrow, .rectangle, .circle, .highlighter:
            return true
        case .text, .blur:
            return false
        }
    }
}

public enum BlurStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case gaussian
    case pixelate

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .gaussian: return "Gaussian Blur"
        case .pixelate: return "Pixelate"
        }
    }
}

public enum OverlayShape: Int, Codable, CaseIterable, Identifiable, Sendable {
    case circle = 0
    case squircle = 1
    case rectangle = 2
    case rhombus = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .circle: return "Circle"
        case .squircle: return "Squircle"
        case .rectangle: return "Rectangle"
        case .rhombus: return "Rhombus"
        }
    }

    public var systemImage: String {
        switch self {
        case .circle: return "circle"
        case .squircle: return "app"
        case .rectangle: return "rectangle"
        case .rhombus: return "diamond"
        }
    }

    public func polygonPoints(in rect: CGRect, maxPoints: Int = 64) -> [CGPoint] {
        let count = max(8, maxPoints)
        var buffer = Array(repeating: CEPoint(x: 0, y: 0), count: count)
        let ceBounds = CERect(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
        let written = buffer.withUnsafeMutableBufferPointer { ptr in
            ce_build_shape_polygon(Int32(rawValue), ceBounds, ptr.baseAddress, count)
        }
        return buffer.prefix(written).map { CGPoint(x: $0.x, y: $0.y) }
    }
}

public enum CursorBorderStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case solid
    case dashed
    case none

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .solid: return "Solid"
        case .dashed: return "Dashed"
        case .none: return "None"
        }
    }
}

public enum CursorClickAnimation: String, Codable, CaseIterable, Identifiable, Sendable {
    case scale
    case rotate
    case none

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scale: return "Scale"
        case .rotate: return "Rotate"
        case .none: return "None"
        }
    }
}

public enum InteractiveModeKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case fn
    case capsLock

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fn: return "Fn"
        case .capsLock: return "Caps Lock"
        }
    }
}

public enum SettingsTab: String, Codable, CaseIterable, Identifiable, Sendable {
    case general
    case annotation
    case cursorHighlight
    case shortcuts
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "General"
        case .annotation: return "Annotate"
        case .cursorHighlight: return "Cursor"
        case .shortcuts: return "Shortcuts"
        case .about: return "About"
        }
    }

    public var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .annotation: return "pencil.tip.crop.circle"
        case .cursorHighlight: return "cursorarrow.rays"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}

public enum AnnotateFontOption: String, Codable, Identifiable, Equatable, CaseIterable, Sendable {
    case systemDefault
    case helveticaNeue
    case avenirNext
    case menlo
    case georgia
    case chalkboardSE
    case markerFelt

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .systemDefault: return "System Default"
        case .helveticaNeue: return "Helvetica Neue"
        case .avenirNext: return "Avenir Next"
        case .menlo: return "Menlo"
        case .georgia: return "Georgia"
        case .chalkboardSE: return "Chalkboard SE"
        case .markerFelt: return "Marker Felt"
        }
    }

    public var fontName: String {
        switch self {
        case .systemDefault: return ".AppleSystemUIFont"
        case .helveticaNeue: return "HelveticaNeue"
        case .avenirNext: return "AvenirNext-Regular"
        case .menlo: return "Menlo-Regular"
        case .georgia: return "Georgia"
        case .chalkboardSE: return "ChalkboardSE-Regular"
        case .markerFelt: return "MarkerFelt-Wide"
        }
    }
}

public struct RGBColor: Codable, Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = Self.clampUnit(red, fallback: 0.0)
        self.green = Self.clampUnit(green, fallback: 0.0)
        self.blue = Self.clampUnit(blue, fallback: 0.0)
        self.alpha = Self.clampUnit(alpha, fallback: 1.0)
    }

    private static func clampUnit(_ raw: Double, fallback: Double) -> Double {
        if raw.isFinite {
            return min(max(raw, 0.0), 1.0)
        }
        if raw == .infinity {
            return 1.0
        }
        if raw == -.infinity {
            return 0.0
        }
        return fallback
    }

    public init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    public var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }

    public func withAlpha(_ newAlpha: Double) -> RGBColor {
        RGBColor(red: red, green: green, blue: blue, alpha: newAlpha)
    }

    public var sanitized: RGBColor {
        RGBColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let red = RGBColor(red: 1.0, green: 0.23, blue: 0.19)
    public static let orange = RGBColor(red: 1.0, green: 0.58, blue: 0.0)
    public static let yellow = RGBColor(red: 1.0, green: 0.84, blue: 0.04)
    public static let green = RGBColor(red: 0.20, green: 0.78, blue: 0.35)
    public static let blue = RGBColor(red: 0.04, green: 0.52, blue: 1.0)
    public static let purple = RGBColor(red: 0.69, green: 0.32, blue: 0.87)
    public static let pink = RGBColor(red: 1.0, green: 0.18, blue: 0.33)
    public static let cyan = RGBColor(red: 0.20, green: 0.68, blue: 0.90)
    public static let white = RGBColor(red: 1.0, green: 1.0, blue: 1.0)
    public static let black = RGBColor(red: 0.08, green: 0.08, blue: 0.10)
}

public struct GradientPair: Codable, Equatable, Hashable, Sendable {
    public var startColor: RGBColor
    public var endColor: RGBColor

    public init(startColor: RGBColor, endColor: RGBColor) {
        self.startColor = startColor
        self.endColor = endColor
    }

    public var sanitized: GradientPair {
        GradientPair(startColor: startColor.sanitized, endColor: endColor.sanitized)
    }
}

public struct AnnotationColorUpdate: Equatable, Sendable {
    public var color: RGBColor
    public var gradient: GradientPair?
    public var coalescingToken: UUID?

    public init(color: RGBColor, gradient: GradientPair? = nil, coalescingToken: UUID? = nil) {
        self.color = color
        self.gradient = gradient
        self.coalescingToken = coalescingToken
    }
}

public enum AnnotationScaleConstraint: Equatable, Sendable {
    case free
    case uniform
}

public struct AnnotationCornerScaleAnchor: Equatable, Sendable {
    public var initialItem: AnnotationItem
    public var cornerIndex: Int

    public init(initialItem: AnnotationItem, cornerIndex: Int) {
        self.initialItem = initialItem
        self.cornerIndex = cornerIndex
    }
}

public struct AnnotationCornerScaleMotion: Equatable, Sendable {
    public var dragStartPoint: CGPoint
    public var currentPoint: CGPoint

    public init(dragStartPoint: CGPoint, currentPoint: CGPoint) {
        self.dragStartPoint = dragStartPoint
        self.currentPoint = currentPoint
    }
}

public struct AnnotationCornerScaleRequest: Equatable, Sendable {
    public var anchor: AnnotationCornerScaleAnchor
    public var motion: AnnotationCornerScaleMotion
    public var constraint: AnnotationScaleConstraint

    public init(anchor: AnnotationCornerScaleAnchor, motion: AnnotationCornerScaleMotion) {
        self.anchor = anchor
        self.motion = motion
        self.constraint = .free
    }

    public func withConstraint(_ constraint: AnnotationScaleConstraint) -> AnnotationCornerScaleRequest {
        var copy = self
        copy.constraint = constraint
        return copy
    }
}

public enum AnnotationDirectionalHandle: Equatable, Sendable {
    case tail
    case headWidth
    case tip
}

public enum AnnotationAngleSnap: Equatable, Sendable {
    case free
    case fortyFiveDegrees
}

public struct AnnotationDirectionalDragRequest: Equatable, Sendable {
    public var initialItem: AnnotationItem
    public var handle: AnnotationDirectionalHandle
    public var currentPoint: CGPoint
    public var angleSnap: AnnotationAngleSnap

    public init(initialItem: AnnotationItem, handle: AnnotationDirectionalHandle) {
        self.initialItem = initialItem
        self.handle = handle
        self.currentPoint = initialItem.endPoint
        self.angleSnap = .free
    }

    public func at(_ point: CGPoint, angleSnap: AnnotationAngleSnap = .free) -> AnnotationDirectionalDragRequest {
        var copy = self
        copy.currentPoint = point
        copy.angleSnap = angleSnap
        return copy
    }
}

public enum AnnotationTailFadeMode: Equatable, Sendable {
    case disabled
    case enabled
}

public enum GradientGenerator {
    public static let presets: [GradientPair] = [
        GradientPair(startColor: RGBColor(red: 1.0, green: 0.25, blue: 0.42), endColor: RGBColor(red: 1.0, green: 0.58, blue: 0.0)),
        GradientPair(startColor: RGBColor(red: 0.04, green: 0.52, blue: 1.0), endColor: RGBColor(red: 0.0, green: 0.88, blue: 0.78)),
        GradientPair(startColor: RGBColor(red: 0.56, green: 0.18, blue: 0.95), endColor: RGBColor(red: 0.95, green: 0.22, blue: 0.66)),
        GradientPair(startColor: RGBColor(red: 0.16, green: 0.82, blue: 0.42), endColor: RGBColor(red: 0.96, green: 0.86, blue: 0.12)),
        GradientPair(startColor: RGBColor(red: 0.98, green: 0.44, blue: 0.15), endColor: RGBColor(red: 0.92, green: 0.12, blue: 0.48))
    ]

    public static func randomVividColor() -> RGBColor {
        let hue = Double.random(in: 0.0...1.0)
        let saturation = Double.random(in: 0.78...0.98)
        let brightness = Double.random(in: 0.88...1.0)
        let color = NSColor(hue: CGFloat(hue), saturation: CGFloat(saturation), brightness: CGFloat(brightness), alpha: 1.0)
        return RGBColor(nsColor: color)
    }

    public static func randomVividGradient() -> GradientPair {
        let baseHue = Double.random(in: 0.0...1.0)
        let offsetHue = (baseHue + Double.random(in: 0.15...0.42)).truncatingRemainder(dividingBy: 1.0)
        let start = NSColor(hue: CGFloat(baseHue), saturation: 0.88, brightness: 0.98, alpha: 1.0)
        let end = NSColor(hue: CGFloat(offsetHue), saturation: 0.90, brightness: 0.96, alpha: 1.0)
        return GradientPair(startColor: RGBColor(nsColor: start), endColor: RGBColor(nsColor: end))
    }
}

private final class TextLayoutMeasureCache: @unchecked Sendable {
    struct Key: Hashable, Sendable {
        let text: String
        let fontName: String
        let fontSizeCentipoints: Int
    }

    static let shared = TextLayoutMeasureCache()
    private static let maxEntries = 256

    private let lock = NSLock()
    private var entries: [Key: CGSize] = [:]
    private var insertionOrder: [Key] = []

    func measuredSize(for key: Key) -> CGSize {
        lock.lock()
        if let cached = entries[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let pointSize = CGFloat(key.fontSizeCentipoints) / 100.0
        let font = NSFont(name: key.fontName, size: pointSize)
            ?? NSFont.systemFont(ofSize: pointSize, weight: .semibold)
        let rawMeasured = (key.text as NSString).size(withAttributes: [.font: font])
        let rawWidth = Double(rawMeasured.width)
        let rawHeight = Double(rawMeasured.height)
        let width = rawWidth.isFinite ? max(24.0, ceil(rawWidth)) : 24.0
        let fallbackHeight = max(20.0, ceil(Double(pointSize) * 1.2))
        let height = rawHeight.isFinite ? max(20.0, ceil(rawHeight)) : fallbackHeight
        let resolved = CGSize(width: width, height: height)

        lock.lock()
        if entries[key] == nil {
            if insertionOrder.count >= Self.maxEntries {
                let evicted = insertionOrder.removeFirst()
                entries.removeValue(forKey: evicted)
            }
            insertionOrder.append(key)
        }
        entries[key] = resolved
        lock.unlock()
        return resolved
    }
}

public struct AnnotationItem: Identifiable, Codable, Equatable, Sendable {
    public static let maxTextLength = 2_048

    public static func clampText(_ raw: String) -> String {
        raw.count > maxTextLength ? String(raw.prefix(maxTextLength)) : raw
    }

    public static func sanitizeFontSize(_ raw: Double) -> Double {
        guard raw.isFinite else { return 24.0 }
        return min(max(raw, 8.0), 200.0)
    }

    public static func sanitizeHeadWidth(_ raw: Double) -> Double {
        guard raw.isFinite else { return 28.0 }
        return min(max(raw, 8.0), 240.0)
    }

    public var id: UUID
    public var mode: DrawMode
    public var points: [CGPoint]
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var isConstrained: Bool
    public var isFilled: Bool
    public var strokeColor: RGBColor
    public var gradientPair: GradientPair?
    public var lineWeight: Double
    public var isHighlighter: Bool
    public var isAutoErase: Bool
    public var createdAt: TimeInterval
    public var text: String
    public var fontName: String
    public var fontSize: Double
    public var blurStyle: BlurStyle? = nil
    public var blurOpacity: Double? = nil
    public var blurTintColor: RGBColor? = nil
    public var rotationRadians: Double = 0.0
    public var headWidth: Double? = nil
    public var tailFadeEnabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id
        case mode
        case points
        case startPoint
        case endPoint
        case isConstrained
        case isFilled
        case strokeColor
        case gradientPair
        case lineWeight
        case isHighlighter
        case isAutoErase
        case createdAt
        case text
        case fontName
        case fontSize
        case blurStyle
        case blurOpacity
        case blurTintColor
        case rotationRadians
        case headWidth
        case tailFadeEnabled
    }

    public init(
        id: UUID = UUID(),
        mode: DrawMode,
        points: [CGPoint] = [],
        startPoint: CGPoint,
        endPoint: CGPoint,
        isConstrained: Bool = false,
        isFilled: Bool = false,
        strokeColor: RGBColor,
        gradientPair: GradientPair? = nil,
        lineWeight: Double = 6.0,
        isHighlighter: Bool = false,
        isAutoErase: Bool = false,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        text: String = "",
        fontName: String = AnnotateFontOption.systemDefault.fontName,
        fontSize: Double = 24.0,
        blurStyle: BlurStyle? = nil,
        blurOpacity: Double? = nil,
        blurTintColor: RGBColor? = nil,
        rotationRadians: Double = 0.0,
        headWidth: Double? = nil,
        tailFadeEnabled: Bool = false
    ) {
        self.id = id
        self.mode = mode
        self.points = points.isEmpty ? [startPoint] : points
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.isConstrained = isConstrained
        self.isFilled = isFilled
        self.strokeColor = strokeColor
        self.gradientPair = gradientPair
        self.lineWeight = lineWeight
        self.isHighlighter = isHighlighter
        self.isAutoErase = isAutoErase
        self.createdAt = createdAt
        self.text = Self.clampText(text)
        self.fontName = fontName
        self.fontSize = Self.sanitizeFontSize(fontSize)
        self.blurStyle = blurStyle
        self.blurOpacity = blurOpacity
        self.blurTintColor = blurTintColor
        self.rotationRadians = AnnotationCanvasState.sanitizeRotationRadians(rotationRadians)
        self.headWidth = headWidth.map(Self.sanitizeHeadWidth)
        self.tailFadeEnabled = tailFadeEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.mode = try container.decode(DrawMode.self, forKey: .mode)
        self.points = try container.decode([CGPoint].self, forKey: .points)
        self.startPoint = try container.decode(CGPoint.self, forKey: .startPoint)
        self.endPoint = try container.decode(CGPoint.self, forKey: .endPoint)
        self.isConstrained = try container.decode(Bool.self, forKey: .isConstrained)
        self.isFilled = try container.decode(Bool.self, forKey: .isFilled)
        self.strokeColor = try container.decode(RGBColor.self, forKey: .strokeColor)
        self.gradientPair = try container.decodeIfPresent(GradientPair.self, forKey: .gradientPair)
        self.lineWeight = try container.decode(Double.self, forKey: .lineWeight)
        self.isHighlighter = try container.decode(Bool.self, forKey: .isHighlighter)
        self.isAutoErase = try container.decode(Bool.self, forKey: .isAutoErase)
        self.createdAt = try container.decode(TimeInterval.self, forKey: .createdAt)
        self.text = try container.decode(String.self, forKey: .text)
        self.fontName = try container.decode(String.self, forKey: .fontName)
        self.fontSize = try container.decode(Double.self, forKey: .fontSize)
        self.blurStyle = try container.decodeIfPresent(BlurStyle.self, forKey: .blurStyle)
        self.blurOpacity = try container.decodeIfPresent(Double.self, forKey: .blurOpacity)
        self.blurTintColor = try container.decodeIfPresent(RGBColor.self, forKey: .blurTintColor)
        self.rotationRadians = try container.decodeIfPresent(Double.self, forKey: .rotationRadians) ?? 0.0
        let decodedHeadWidth = try container.decodeIfPresent(Double.self, forKey: .headWidth)
        self.headWidth = decodedHeadWidth.map(Self.sanitizeHeadWidth)
        self.tailFadeEnabled = try container.decodeIfPresent(Bool.self, forKey: .tailFadeEnabled) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mode, forKey: .mode)
        try container.encode(points, forKey: .points)
        try container.encode(startPoint, forKey: .startPoint)
        try container.encode(endPoint, forKey: .endPoint)
        try container.encode(isConstrained, forKey: .isConstrained)
        try container.encode(isFilled, forKey: .isFilled)
        try container.encode(strokeColor, forKey: .strokeColor)
        try container.encodeIfPresent(gradientPair, forKey: .gradientPair)
        try container.encode(lineWeight, forKey: .lineWeight)
        try container.encode(isHighlighter, forKey: .isHighlighter)
        try container.encode(isAutoErase, forKey: .isAutoErase)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(text, forKey: .text)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(blurStyle, forKey: .blurStyle)
        try container.encodeIfPresent(blurOpacity, forKey: .blurOpacity)
        try container.encodeIfPresent(blurTintColor, forKey: .blurTintColor)
        try container.encode(rotationRadians, forKey: .rotationRadians)
        try container.encodeIfPresent(headWidth.map(Self.sanitizeHeadWidth), forKey: .headWidth)
        try container.encode(tailFadeEnabled, forKey: .tailFadeEnabled)
    }

    public var effectiveBlurStyle: BlurStyle {
        let baseStyle = blurStyle ?? .gaussian
        guard isFilled else { return baseStyle }
        return baseStyle == .gaussian ? .pixelate : .gaussian
    }

    public var effectiveBlurOpacity: Double {
        guard let raw = blurOpacity, raw.isFinite else { return 0.55 }
        return min(max(raw, 0.10), 1.00)
    }

    public var effectiveRotationRadians: Double {
        rotationRadians.isFinite ? rotationRadians : 0.0
    }

    public var textLayoutRect: CGRect {
        let safeFontSize = Self.sanitizeFontSize(fontSize)
        let centipoints = Int((safeFontSize * 100.0).rounded())
        let boundedText = Self.clampText(text)
        let boundedFontName = fontName.count > 256 ? String(fontName.prefix(256)) : fontName
        let cacheKey = TextLayoutMeasureCache.Key(
            text: boundedText,
            fontName: boundedFontName,
            fontSizeCentipoints: centipoints
        )
        let size = TextLayoutMeasureCache.shared.measuredSize(for: cacheKey)
        return CGRect(x: Double(startPoint.x), y: Double(startPoint.y), width: size.width, height: size.height)
    }

    public var textSelectionBox: CGRect {
        textLayoutRect.insetBy(dx: -4.0, dy: -4.0)
    }

    public var textCenter: CGPoint {
        let rect = textLayoutRect
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    public var localTextScaleHandleCenters: [CGPoint] {
        let box = textSelectionBox
        return [
            CGPoint(x: box.minX, y: box.minY),
            CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.maxY),
            CGPoint(x: box.minX, y: box.maxY)
        ]
    }

    public var localTextRotationHandleCenter: CGPoint {
        let box = textSelectionBox
        return CGPoint(x: box.midX, y: box.maxY + 22.0)
    }

    public var worldTextScaleHandleCenters: [CGPoint] {
        localTextScaleHandleCenters.map(fromTextLocalSpace)
    }

    public var worldTextRotationHandleCenter: CGPoint {
        fromTextLocalSpace(localTextRotationHandleCenter)
    }

    public var nonTextSelectionBox: CGRect {
        let rawBox = boundingRect
        let hasFiniteOrigin = rawBox.origin.x.isFinite && rawBox.origin.y.isFinite
        let hasFiniteSize = rawBox.size.width.isFinite && rawBox.size.height.isFinite
        guard hasFiniteOrigin && hasFiniteSize else { return .null }
        let inset = rawBox.insetBy(dx: -4.0, dy: -4.0)
        let hasFiniteInsetOrigin = inset.origin.x.isFinite && inset.origin.y.isFinite
        let hasFiniteInsetSize = inset.size.width.isFinite && inset.size.height.isFinite
        guard hasFiniteInsetOrigin && hasFiniteInsetSize else { return .null }
        return inset
    }

    public var selectionScaleHandleCenters: [CGPoint] {
        if mode == .text {
            return worldTextScaleHandleCenters
        }
        let box = nonTextSelectionBox
        guard !box.isNull else { return [] }
        return [
            CGPoint(x: box.minX, y: box.minY),
            CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.maxY),
            CGPoint(x: box.minX, y: box.maxY)
        ]
    }

    public var isConstrainedStraightLine: Bool {
        let isFreeformMode = mode == .freeHand || mode == .highlighter
        let isTwoPointConstrained = isConstrained && points.count == 2
        return isFreeformMode && isTwoPointConstrained
    }

    public var usesDirectionalHandles: Bool {
        mode == .arrow || isConstrainedStraightLine
    }

    public var usesTaperedWedgeLine: Bool {
        let hasTaperStyling = headWidth != nil || tailFadeEnabled
        return isConstrainedStraightLine && hasTaperStyling
    }

    public var tailHandleCenter: CGPoint {
        AnnotationCanvasState.clampCanvasPoint(startPoint)
    }

    public var tipHandleCenter: CGPoint {
        AnnotationCanvasState.clampCanvasPoint(endPoint)
    }

    public var headScaleAxisAnchor: CGPoint {
        guard let basis = directionalBasis() else { return tipHandleCenter }
        if mode == .arrow {
            let geom = arrowGeometry(using: basis)
            return AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: geom.wingCenterX, y: geom.wingCenterY)
            )
        }
        let collarDist = basis.length * 0.82
        return AnnotationCanvasState.clampCanvasPoint(
            CGPoint(
                x: basis.startX + basis.ux * collarDist,
                y: basis.startY + basis.uy * collarDist
            )
        )
    }

    public var headScaleHandleCenter: CGPoint {
        guard let basis = directionalBasis() else { return tipHandleCenter }
        if mode == .arrow {
            let geom = arrowGeometry(using: basis)
            return AnnotationCanvasState.clampCanvasPoint(
                CGPoint(
                    x: geom.wingCenterX + basis.px * geom.headHalfWidth,
                    y: geom.wingCenterY + basis.py * geom.headHalfWidth
                )
            )
        }
        let resolvedHeadWidth = headWidth.map(Self.sanitizeHeadWidth) ?? min(max(basis.safeWeight, 8.0), 240.0)
        let headHalfWidth = resolvedHeadWidth * 0.5
        let hasTaperStyling = headWidth != nil || tailFadeEnabled
        let tailHalfWidth = hasTaperStyling
            ? max(1.5, min(basis.safeWeight * 0.45, headHalfWidth * 0.22))
            : (basis.safeWeight * 0.5)
        let collarDist = basis.length * 0.82
        let collarX = basis.startX + basis.ux * collarDist
        let collarY = basis.startY + basis.uy * collarDist
        let offset = max(headHalfWidth * 0.82 + tailHalfWidth * 0.18, 14.0)
        return AnnotationCanvasState.clampCanvasPoint(
            CGPoint(
                x: collarX + basis.px * offset,
                y: collarY + basis.py * offset
            )
        )
    }

    public var directionalHandleCenters: [CGPoint] {
        [tailHandleCenter, headScaleHandleCenter, tipHandleCenter]
    }

    public func toTextLocalSpace(_ point: CGPoint) -> CGPoint {
        let angle = effectiveRotationRadians
        guard angle != 0.0 else { return point }
        let center = textCenter
        let hasFiniteCenter = center.x.isFinite && center.y.isFinite
        guard hasFiniteCenter else { return point }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGPoint(
            x: Double(center.x) + dx * cosAngle + dy * sinAngle,
            y: Double(center.y) - dx * sinAngle + dy * cosAngle
        )
    }

    public func fromTextLocalSpace(_ point: CGPoint) -> CGPoint {
        let angle = effectiveRotationRadians
        guard angle != 0.0 else { return point }
        let center = textCenter
        let hasFiniteCenter = center.x.isFinite && center.y.isFinite
        guard hasFiniteCenter else { return point }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGPoint(
            x: Double(center.x) + dx * cosAngle - dy * sinAngle,
            y: Double(center.y) + dx * sinAngle + dy * cosAngle
        )
    }

    public func intersectsMarquee(_ marquee: CGRect) -> Bool {
        guard marquee.intersects(boundingRect) else { return false }
        guard effectiveRotationRadians != 0.0 else { return true }
        let localCorners = [
            CGPoint(x: marquee.minX, y: marquee.minY),
            CGPoint(x: marquee.maxX, y: marquee.minY),
            CGPoint(x: marquee.maxX, y: marquee.maxY),
            CGPoint(x: marquee.minX, y: marquee.maxY)
        ].map(toTextLocalSpace)
        let xs = localCorners.map(\.x)
        let ys = localCorners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max() else { return false }
        guard let minY = ys.min(), let maxY = ys.max() else { return false }
        let localMarqueeBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return localMarqueeBounds.intersects(textLayoutRect)
    }

    public func withCenteredFontSize(_ newSize: Double, center: CGPoint) -> AnnotationItem {
        var updated = self
        updated.fontSize = Self.sanitizeFontSize(newSize)
        let fallbackX = startPoint.x.isFinite ? min(max(Double(startPoint.x), -32_768.0), 32_768.0) : 0.0
        let fallbackY = startPoint.y.isFinite ? min(max(Double(startPoint.y), -32_768.0), 32_768.0) : 0.0
        let hasFiniteCenter = center.x.isFinite && center.y.isFinite
        guard hasFiniteCenter else {
            let safeOrigin = CGPoint(x: fallbackX, y: fallbackY)
            updated.startPoint = safeOrigin
            updated.endPoint = safeOrigin
            updated.points = [safeOrigin]
            return updated
        }
        let measuredRect = updated.textLayoutRect
        let rawOriginX = Double(center.x) - Double(measuredRect.width) * 0.5
        let rawOriginY = Double(center.y) - Double(measuredRect.height) * 0.5
        let clampedX = rawOriginX.isFinite ? min(max(rawOriginX, -32_768.0), 32_768.0) : fallbackX
        let clampedY = rawOriginY.isFinite ? min(max(rawOriginY, -32_768.0), 32_768.0) : fallbackY
        let clampedOrigin = CGPoint(x: clampedX, y: clampedY)
        updated.startPoint = clampedOrigin
        updated.endPoint = clampedOrigin
        updated.points = [clampedOrigin]
        return updated
    }

    public var boundingRect: CGRect {
        switch mode {
        case .rectangle, .circle, .blur:
            let ceRect = ce_make_rect(
                CEPoint(x: Double(startPoint.x), y: Double(startPoint.y)),
                CEPoint(x: Double(endPoint.x), y: Double(endPoint.y)),
                isConstrained
            )
            return CGRect(x: ceRect.x, y: ceRect.y, width: ceRect.width, height: ceRect.height)
        case .text:
            let layoutRect = textLayoutRect
            let angle = effectiveRotationRadians
            guard angle != 0.0 else { return layoutRect }
            let hasFiniteOrigin = layoutRect.origin.x.isFinite && layoutRect.origin.y.isFinite
            guard hasFiniteOrigin else { return layoutRect }
            let corners = [
                CGPoint(x: layoutRect.minX, y: layoutRect.minY),
                CGPoint(x: layoutRect.maxX, y: layoutRect.minY),
                CGPoint(x: layoutRect.maxX, y: layoutRect.maxY),
                CGPoint(x: layoutRect.minX, y: layoutRect.maxY)
            ].map(fromTextLocalSpace)
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max() else { return layoutRect }
            guard let minY = ys.min(), let maxY = ys.max() else { return layoutRect }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .arrow:
            if let polyBox = Self.finitePolygonBounds(arrowPolygonPoints()) {
                return polyBox
            }
            let cePoints = [
                CEPoint(x: Double(startPoint.x), y: Double(startPoint.y)),
                CEPoint(x: Double(endPoint.x), y: Double(endPoint.y))
            ]
            let box = cePoints.withUnsafeBufferPointer { ptr in
                ce_compute_bounding_box(ptr.baseAddress, ptr.count, lineWeight * 2.0)
            }
            return CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
        case .freeHand, .highlighter:
            if usesTaperedWedgeLine, let polyBox = Self.finitePolygonBounds(taperedLinePolygonPoints()) {
                return polyBox
            }
            let cePoints = points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
            let box = cePoints.withUnsafeBufferPointer { ptr in
                ce_compute_bounding_box(ptr.baseAddress, ptr.count, lineWeight)
            }
            return CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
        }
    }

    public func arrowPolygonPoints() -> [CGPoint] {
        guard let basis = directionalBasis() else { return [] }
        let geom = arrowGeometry(using: basis)
        return [
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.startX + basis.px * geom.tailHalfWidth, y: basis.startY + basis.py * geom.tailHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: geom.neckX + basis.px * geom.neckHalfWidth, y: geom.neckY + basis.py * geom.neckHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: geom.wingCenterX + basis.px * geom.headHalfWidth, y: geom.wingCenterY + basis.py * geom.headHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.endX, y: basis.endY)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: geom.wingCenterX - basis.px * geom.headHalfWidth, y: geom.wingCenterY - basis.py * geom.headHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: geom.neckX - basis.px * geom.neckHalfWidth, y: geom.neckY - basis.py * geom.neckHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.startX - basis.px * geom.tailHalfWidth, y: basis.startY - basis.py * geom.tailHalfWidth)
            )
        ]
    }

    public func taperedLinePolygonPoints() -> [CGPoint] {
        guard let basis = directionalBasis() else { return [] }
        let resolvedHeadWidth = headWidth.map(Self.sanitizeHeadWidth) ?? min(max(basis.safeWeight, 8.0), 240.0)
        let headHalfWidth = resolvedHeadWidth * 0.5
        let hasTaperStyling = headWidth != nil || tailFadeEnabled
        let tailHalfWidth = hasTaperStyling
            ? max(1.5, min(basis.safeWeight * 0.45, headHalfWidth * 0.22))
            : (basis.safeWeight * 0.5)
        return [
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.startX + basis.px * tailHalfWidth, y: basis.startY + basis.py * tailHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.endX + basis.px * headHalfWidth, y: basis.endY + basis.py * headHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.endX - basis.px * headHalfWidth, y: basis.endY - basis.py * headHalfWidth)
            ),
            AnnotationCanvasState.clampCanvasPoint(
                CGPoint(x: basis.startX - basis.px * tailHalfWidth, y: basis.startY - basis.py * tailHalfWidth)
            )
        ]
    }

    private struct DirectionalBasis {
        let startX: Double
        let startY: Double
        let endX: Double
        let endY: Double
        let length: Double
        let ux: Double
        let uy: Double
        let px: Double
        let py: Double
        let safeWeight: Double
    }

    private struct ArrowGeometry {
        let tailHalfWidth: Double
        let neckHalfWidth: Double
        let headHalfWidth: Double
        let neckX: Double
        let neckY: Double
        let wingCenterX: Double
        let wingCenterY: Double
    }

    private func directionalBasis() -> DirectionalBasis? {
        let hasFiniteStart = startPoint.x.isFinite && startPoint.y.isFinite
        let hasFiniteEnd = endPoint.x.isFinite && endPoint.y.isFinite
        guard hasFiniteStart && hasFiniteEnd else { return nil }
        let startX = Double(startPoint.x)
        let startY = Double(startPoint.y)
        let endX = Double(endPoint.x)
        let endY = Double(endPoint.y)
        let dx = endX - startX
        let dy = endY - startY
        guard dx.isFinite && dy.isFinite else { return nil }
        let length = hypot(dx, dy)
        let ux = length > 1e-6 ? (dx / length) : 1.0
        let uy = length > 1e-6 ? (dy / length) : 0.0
        let safeWeight = lineWeight.isFinite ? min(max(lineWeight, 1.0), 64.0) : 6.0
        return DirectionalBasis(
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            length: length,
            ux: ux,
            uy: uy,
            px: -uy,
            py: ux,
            safeWeight: safeWeight
        )
    }

    private func arrowGeometry(using basis: DirectionalBasis) -> ArrowGeometry {
        let hasTaperStyling = headWidth != nil || tailFadeEnabled
        let headHalfWidth: Double
        let headLength: Double
        let tailHalfWidth: Double
        let neckHalfWidth: Double
        let barbBack: Double

        if hasTaperStyling {
            let resolvedHeadWidth = headWidth.map(Self.sanitizeHeadWidth) ?? min(max(basis.safeWeight * 3.8, 16.0), 240.0)
            headHalfWidth = resolvedHeadWidth * 0.5
            let desiredHeadLength = max(14.0, headHalfWidth * 1.65)
            headLength = basis.length > 1e-6 ? min(basis.length * 0.60, desiredHeadLength) : desiredHeadLength
            tailHalfWidth = max(1.5, min(basis.safeWeight * 0.42, headHalfWidth * 0.20))
            neckHalfWidth = min(max(basis.safeWeight * 0.55, headHalfWidth * 0.44), headHalfWidth * 0.82)
            barbBack = headLength * 0.14
        } else {
            headHalfWidth = max(basis.safeWeight * 1.8, 7.0)
            let desiredHeadLength = max(basis.safeWeight * 3.0, 12.0)
            headLength = basis.length > 1e-6 ? min(basis.length * 0.65, desiredHeadLength) : desiredHeadLength
            tailHalfWidth = basis.safeWeight * 0.5
            neckHalfWidth = basis.safeWeight * 0.5
            barbBack = 0.0
        }

        let neckX = basis.endX - basis.ux * headLength
        let neckY = basis.endY - basis.uy * headLength
        let wingCenterX = neckX - basis.ux * barbBack
        let wingCenterY = neckY - basis.uy * barbBack
        return ArrowGeometry(
            tailHalfWidth: tailHalfWidth,
            neckHalfWidth: neckHalfWidth,
            headHalfWidth: headHalfWidth,
            neckX: neckX,
            neckY: neckY,
            wingCenterX: wingCenterX,
            wingCenterY: wingCenterY
        )
    }

    private static func finitePolygonBounds(_ vertices: [CGPoint]) -> CGRect? {
        guard !vertices.isEmpty else { return nil }
        var minX = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for vertex in vertices {
            let x = Double(vertex.x)
            let y = Double(vertex.y)
            guard x.isFinite && y.isFinite else { return nil }
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
        let width = maxX - minX
        let height = maxY - minY
        guard width.isFinite && height.isFinite else { return nil }
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
}

public final class AnnotationCanvasState: ObservableObject {
    @Published public var annotations: [AnnotationItem] = []
    @Published public var activeDraft: AnnotationItem?
    @Published public var selectedIDs: Set<UUID> = [] {
        didSet {
            if selectedIDs != oldValue {
                lastCoalescedColorToken = nil
            }
        }
    }
    @Published public var selectionRectangle: CGRect?
    @Published public private(set) var copiedAnnotations: [AnnotationItem] = []
    @Published public private(set) var pasteCount: Int = 0
    @Published public private(set) var undoStack: [[AnnotationItem]] = []
    @Published public private(set) var redoStack: [[AnnotationItem]] = []
    public var activeInlineEditingID: UUID?

    private var isInteractiveTransformActive = false
    private var didRecordInteractiveSnapshot = false
    private var interactiveTextCenters: [UUID: CGPoint] = [:]
    private var lastCoalescedColorToken: UUID?

    public init() {}

    public func beginStroke(
        at point: CGPoint,
        mode: DrawMode,
        color: RGBColor,
        gradient: GradientPair? = nil,
        lineWeight: Double,
        isHighlighter: Bool = false,
        isAutoErase: Bool = false,
        isShiftDown: Bool = false,
        isOptionDown: Bool = false,
        blurStyle: BlurStyle? = nil,
        blurOpacity: Double? = nil,
        blurTintColor: RGBColor? = nil,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        selectedIDs.removeAll()
        selectionRectangle = nil
        let effectiveHighlighter = isHighlighter || mode == .highlighter
        let effectiveWeight = effectiveHighlighter ? max(lineWeight * 2.2, 14.0) : lineWeight
        let effectiveColor = effectiveHighlighter ? color.withAlpha(0.42) : color

        activeDraft = AnnotationItem(
            mode: mode,
            points: [point],
            startPoint: point,
            endPoint: point,
            isConstrained: isShiftDown,
            isFilled: isOptionDown,
            strokeColor: effectiveColor,
            gradientPair: gradient,
            lineWeight: effectiveWeight,
            isHighlighter: effectiveHighlighter,
            isAutoErase: isAutoErase,
            createdAt: now,
            blurStyle: mode == .blur ? blurStyle : nil,
            blurOpacity: mode == .blur ? blurOpacity : nil,
            blurTintColor: mode == .blur ? blurTintColor : nil
        )
    }

    public func updateStroke(to point: CGPoint, isShiftDown: Bool = false, isOptionDown: Bool = false) {
        guard var draft = activeDraft else { return }
        draft.isConstrained = isShiftDown
        draft.isFilled = isOptionDown

        switch draft.mode {
        case .freeHand, .highlighter:
            if isShiftDown {
                let snapped = ce_constrain_line(
                    CEPoint(x: Double(draft.startPoint.x), y: Double(draft.startPoint.y)),
                    CEPoint(x: Double(point.x), y: Double(point.y))
                )
                let end = CGPoint(x: snapped.x, y: snapped.y)
                draft.endPoint = end
                draft.points = [draft.startPoint, end]
            } else {
                draft.endPoint = point
                draft.points.append(point)
            }
        case .arrow:
            if isShiftDown {
                let snapped = ce_constrain_line(
                    CEPoint(x: Double(draft.startPoint.x), y: Double(draft.startPoint.y)),
                    CEPoint(x: Double(point.x), y: Double(point.y))
                )
                let end = CGPoint(x: snapped.x, y: snapped.y)
                draft.endPoint = end
                draft.points = [draft.startPoint, end]
            } else {
                draft.endPoint = point
                draft.points = [draft.startPoint, point]
            }
        case .rectangle, .circle, .blur:
            if isShiftDown {
                let constrainedRect = ce_make_rect(
                    CEPoint(x: Double(draft.startPoint.x), y: Double(draft.startPoint.y)),
                    CEPoint(x: Double(point.x), y: Double(point.y)),
                    true
                )
                let signX: Double = point.x >= draft.startPoint.x ? 1.0 : -1.0
                let signY: Double = point.y >= draft.startPoint.y ? 1.0 : -1.0
                draft.endPoint = CGPoint(
                    x: Double(draft.startPoint.x) + signX * constrainedRect.width,
                    y: Double(draft.startPoint.y) + signY * constrainedRect.height
                )
            } else {
                draft.endPoint = point
            }
            draft.points = [draft.startPoint, draft.endPoint]
        case .text:
            draft.endPoint = point
        }

        activeDraft = draft
    }

    @discardableResult
    public func finishStroke() -> UUID? {
        guard var draft = activeDraft else { return nil }
        activeDraft = nil

        if draft.mode == .blur {
            let bounds = draft.boundingRect
            let hasFiniteBounds = bounds.width.isFinite && bounds.height.isFinite
            let hasMinimumBlurSize = bounds.width >= 2.0 && bounds.height >= 2.0
            guard hasFiniteBounds && hasMinimumBlurSize else { return nil }
        }

        let isFreeformMode = draft.mode == .freeHand || draft.mode == .highlighter
        let isFreeformStroke = isFreeformMode && !draft.isConstrained
        if isFreeformStroke && draft.points.count >= 3 {
            let inputPoints = draft.points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
            let maxOut = max(inputPoints.count * 4 + 2, 16)
            var outputPoints = Array(repeating: CEPoint(x: 0, y: 0), count: maxOut)
            let smoothedCount = inputPoints.withUnsafeBufferPointer { inPtr in
                outputPoints.withUnsafeMutableBufferPointer { outPtr in
                    ce_smooth_stroke(inPtr.baseAddress, inPtr.count, outPtr.baseAddress, maxOut)
                }
            }
            if smoothedCount > 0 {
                draft.points = outputPoints.prefix(smoothedCount).map { CGPoint(x: $0.x, y: $0.y) }
            }
        }

        if !draft.usesDirectionalHandles {
            draft.tailFadeEnabled = false
            draft.headWidth = nil
        }

        recordUndoSnapshot()
        annotations.append(draft)
        return draft.id
    }

    @discardableResult
    public func addOrUpdateTextAnnotation(
        id: UUID? = nil,
        at point: CGPoint,
        text: String,
        color: RGBColor,
        fontName: String = AnnotateFontOption.systemDefault.fontName,
        fontSize: Double = 24.0,
        isAutoErase: Bool = false,
        now: TimeInterval = Date().timeIntervalSince1970
    ) -> UUID? {
        let hasFinitePoint = point.x.isFinite && point.y.isFinite
        guard hasFinitePoint else { return nil }
        let clampedPoint = Self.clampCanvasPoint(point)
        let boundedText = AnnotationItem.clampText(text)
        let safeFontSize = AnnotationItem.sanitizeFontSize(fontSize)
        let trimmed = boundedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingID = id, let index = annotations.firstIndex(where: { $0.id == existingID }) {
            recordUndoSnapshot()
            if trimmed.isEmpty {
                annotations.remove(at: index)
                selectedIDs.remove(existingID)
                return nil
            } else {
                let safeOrigin = Self.clampCanvasPoint(annotations[index].startPoint)
                annotations[index].startPoint = safeOrigin
                annotations[index].endPoint = safeOrigin
                annotations[index].points = [safeOrigin]
                annotations[index].text = boundedText
                annotations[index].strokeColor = color
                annotations[index].fontName = fontName
                annotations[index].fontSize = safeFontSize
                annotations[index].rotationRadians = Self.sanitizeRotationRadians(annotations[index].rotationRadians)
                annotations[index].createdAt = now
                return existingID
            }
        }

        guard !trimmed.isEmpty else { return nil }
        recordUndoSnapshot()
        let item = AnnotationItem(
            id: id ?? UUID(),
            mode: .text,
            points: [clampedPoint],
            startPoint: clampedPoint,
            endPoint: clampedPoint,
            strokeColor: color,
            lineWeight: 2.0,
            isAutoErase: isAutoErase,
            createdAt: now,
            text: boundedText,
            fontName: fontName,
            fontSize: safeFontSize
        )
        annotations.append(item)
        return item.id
    }

    public func hitTestAnnotation(at point: CGPoint, tolerance: Double = 6.0) -> UUID? {
        let testPoint = CEPoint(x: Double(point.x), y: Double(point.y))
        for item in annotations.reversed() {
            switch item.mode {
            case .rectangle, .circle:
                let rect = ce_make_rect(
                    CEPoint(x: Double(item.startPoint.x), y: Double(item.startPoint.y)),
                    CEPoint(x: Double(item.endPoint.x), y: Double(item.endPoint.y)),
                    item.isConstrained
                )
                if ce_hit_test_rect(rect, item.isFilled, item.lineWeight, testPoint, tolerance) {
                    return item.id
                }
            case .blur:
                let rect = ce_make_rect(
                    CEPoint(x: Double(item.startPoint.x), y: Double(item.startPoint.y)),
                    CEPoint(x: Double(item.endPoint.x), y: Double(item.endPoint.y)),
                    item.isConstrained
                )
                if ce_hit_test_rect(rect, true, item.lineWeight, testPoint, tolerance) {
                    return item.id
                }
            case .text:
                let layoutRect = item.textLayoutRect
                let localPoint = item.toTextLocalSpace(point)
                let ceLocalPoint = CEPoint(x: Double(localPoint.x), y: Double(localPoint.y))
                let rect = CERect(
                    x: Double(layoutRect.origin.x),
                    y: Double(layoutRect.origin.y),
                    width: Double(layoutRect.size.width),
                    height: Double(layoutRect.size.height)
                )
                if ce_hit_test_rect(rect, true, 2.0, ceLocalPoint, tolerance) {
                    return item.id
                }
            case .arrow:
                let vertices = item.arrowPolygonPoints()
                if Self.pointInPolygon(point, vertices: vertices) {
                    return item.id
                }
                let closedEdges = Self.closedStrokePoints(vertices)
                let isEdgeHit = closedEdges.withUnsafeBufferPointer { ptr in
                    ce_hit_test_stroke(ptr.baseAddress, ptr.count, 0.0, testPoint, tolerance)
                }
                if isEdgeHit {
                    return item.id
                }
            case .freeHand, .highlighter:
                if item.usesTaperedWedgeLine {
                    let vertices = item.taperedLinePolygonPoints()
                    if Self.pointInPolygon(point, vertices: vertices) {
                        return item.id
                    }
                    let closedEdges = Self.closedStrokePoints(vertices)
                    let isEdgeHit = closedEdges.withUnsafeBufferPointer { ptr in
                        ce_hit_test_stroke(ptr.baseAddress, ptr.count, 0.0, testPoint, tolerance)
                    }
                    if isEdgeHit {
                        return item.id
                    }
                } else {
                    let strokePoints = item.points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
                    let isHit = strokePoints.withUnsafeBufferPointer { ptr in
                        ce_hit_test_stroke(ptr.baseAddress, ptr.count, item.lineWeight, testPoint, tolerance)
                    }
                    if isHit {
                        return item.id
                    }
                }
            }
        }
        return nil
    }

    public func selectAnnotations(in rect: CGRect) {
        selectionRectangle = rect
        let normalized = rect.standardized
        let ceMarquee = CERect(
            x: Double(normalized.origin.x),
            y: Double(normalized.origin.y),
            width: Double(normalized.size.width),
            height: Double(normalized.size.height)
        )

        var matched: Set<UUID> = []
        for item in annotations {
            switch item.mode {
            case .arrow:
                if Self.rectIntersectsPolygon(normalized, vertices: item.arrowPolygonPoints()) {
                    matched.insert(item.id)
                }
            case .freeHand, .highlighter:
                if item.usesTaperedWedgeLine {
                    if Self.rectIntersectsPolygon(normalized, vertices: item.taperedLinePolygonPoints()) {
                        matched.insert(item.id)
                    }
                } else {
                    let pts = item.points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
                    let intersects = pts.withUnsafeBufferPointer { ptr in
                        ce_rect_intersects_stroke(ceMarquee, ptr.baseAddress, ptr.count)
                    }
                    if intersects {
                        matched.insert(item.id)
                    }
                }
            case .text:
                if item.intersectsMarquee(normalized) {
                    matched.insert(item.id)
                }
            case .rectangle, .circle, .blur:
                if normalized.intersects(item.boundingRect) {
                    matched.insert(item.id)
                }
            }
        }
        selectedIDs = matched
    }

    public func toggleSelection(at point: CGPoint, additive: Bool = false) {
        if let hitID = hitTestAnnotation(at: point) {
            if additive {
                if selectedIDs.contains(hitID) {
                    selectedIDs.remove(hitID)
                } else {
                    selectedIDs.insert(hitID)
                }
            } else {
                selectedIDs = [hitID]
            }
        } else if !additive {
            selectedIDs.removeAll()
        }
    }

    public var hasSelectedTextAnnotations: Bool {
        annotations.contains { item in
            let isSelected = selectedIDs.contains(item.id)
            return isSelected && item.mode == .text
        }
    }

    public var hasSelectedAnnotations: Bool {
        annotations.contains { selectedIDs.contains($0.id) }
    }

    public var hasSelectedBlurAnnotations: Bool {
        annotations.contains { item in
            let isSelected = selectedIDs.contains(item.id)
            return isSelected && item.mode == .blur
        }
    }

    public func beginInteractiveTransform() {
        isInteractiveTransformActive = true
        didRecordInteractiveSnapshot = false
        interactiveTextCenters.removeAll()
        for item in annotations where item.mode == .text {
            interactiveTextCenters[item.id] = item.textCenter
        }
    }

    public func endInteractiveTransform() {
        isInteractiveTransformActive = false
        didRecordInteractiveSnapshot = false
        interactiveTextCenters.removeAll()
    }

    public func moveSelectedAnnotations(by delta: CGSize) {
        let hasFiniteDelta = delta.width.isFinite && delta.height.isFinite
        guard hasFiniteDelta else { return }
        let hasNonZeroDelta = delta.width != 0 || delta.height != 0
        guard !selectedIDs.isEmpty && hasNonZeroDelta else { return }

        let dx = Double(delta.width)
        let dy = Double(delta.height)
        recordTransformUndoSnapshotIfNeeded()
        for index in annotations.indices where selectedIDs.contains(annotations[index].id) {
            annotations[index].startPoint = Self.clampCanvasPoint(
                CGPoint(
                    x: Double(annotations[index].startPoint.x) + dx,
                    y: Double(annotations[index].startPoint.y) + dy
                )
            )
            annotations[index].endPoint = Self.clampCanvasPoint(
                CGPoint(
                    x: Double(annotations[index].endPoint.x) + dx,
                    y: Double(annotations[index].endPoint.y) + dy
                )
            )
            annotations[index].points = annotations[index].points.map { point in
                Self.clampCanvasPoint(
                    CGPoint(x: Double(point.x) + dx, y: Double(point.y) + dy)
                )
            }
        }
    }

    public func scaleTextAnnotation(_ id: UUID, toFontSize fontSize: Double) {
        guard fontSize.isFinite else { return }
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard annotations[index].mode == .text else { return }

        let clampedSize = AnnotationItem.sanitizeFontSize(fontSize)
        let fixedCenter = interactiveTextCenters[id] ?? annotations[index].textCenter
        let updated = annotations[index].withCenteredFontSize(clampedSize, center: fixedCenter)
        let currentSize = annotations[index].fontSize
        let didRepairSize = !currentSize.isFinite
        let didChangeSize = didRepairSize || abs(currentSize - updated.fontSize) > 1e-6
        let didChangeOrigin = annotations[index].startPoint != updated.startPoint
        guard didChangeSize || didChangeOrigin else { return }

        recordTransformUndoSnapshotIfNeeded()
        annotations[index] = updated
    }

    public func scaleSelectedTextAnnotations(by factor: Double) {
        let isValidFactor = factor.isFinite && factor > 0
        guard isValidFactor && !selectedIDs.isEmpty else { return }

        let willChange = annotations.contains { item in
            let isSelectedText = selectedIDs.contains(item.id) && item.mode == .text
            guard isSelectedText else { return false }
            let isCurrentFinite = item.fontSize.isFinite
            let baseSize = AnnotationItem.sanitizeFontSize(item.fontSize)
            let rawScaled = baseSize * factor
            let clamped = rawScaled.isFinite ? min(max(rawScaled, 8.0), 200.0) : 200.0
            let fixedCenter = interactiveTextCenters[item.id] ?? item.textCenter
            let updated = item.withCenteredFontSize(clamped, center: fixedCenter)
            if !isCurrentFinite {
                return true
            }
            let didChangeSize = abs(clamped - item.fontSize) > 1e-6
            return didChangeSize || item.startPoint != updated.startPoint
        }
        guard willChange else { return }

        recordTransformUndoSnapshotIfNeeded()
        for index in annotations.indices {
            let item = annotations[index]
            let isSelectedText = selectedIDs.contains(item.id) && item.mode == .text
            guard isSelectedText else { continue }
            let baseSize = AnnotationItem.sanitizeFontSize(item.fontSize)
            let rawScaled = baseSize * factor
            let nextSize = rawScaled.isFinite ? min(max(rawScaled, 8.0), 200.0) : 200.0
            let fixedCenter = interactiveTextCenters[item.id] ?? item.textCenter
            annotations[index] = item.withCenteredFontSize(nextSize, center: fixedCenter)
        }
    }

    public func scaleSelectedAnnotations(by factor: Double) {
        let isValidFactor = factor.isFinite && factor > 0
        guard isValidFactor && !selectedIDs.isEmpty else { return }

        var nextAnnotations = annotations
        var anyChanged = false

        for index in nextAnnotations.indices where selectedIDs.contains(nextAnnotations[index].id) {
            let item = nextAnnotations[index]
            if item.mode == .text {
                let baseSize = AnnotationItem.sanitizeFontSize(item.fontSize)
                let rawScaled = baseSize * factor
                let nextSize = rawScaled.isFinite ? min(max(rawScaled, 8.0), 200.0) : 200.0
                let fixedCenter = interactiveTextCenters[item.id] ?? item.textCenter
                let updated = item.withCenteredFontSize(nextSize, center: fixedCenter)
                let didRepairSize = !item.fontSize.isFinite
                let didChangeSize = didRepairSize || abs(item.fontSize - updated.fontSize) > 1e-6
                let didChangeOrigin = item.startPoint != updated.startPoint
                if didChangeSize || didChangeOrigin {
                    nextAnnotations[index] = updated
                    anyChanged = true
                }
                continue
            }

            guard Self.hasAllFinitePoints(item) else { continue }
            let box = item.boundingRect
            let hasFiniteOrigin = box.origin.x.isFinite && box.origin.y.isFinite
            let hasFiniteSize = box.size.width.isFinite && box.size.height.isFinite
            guard hasFiniteOrigin && hasFiniteSize else { continue }
            let center = CGPoint(x: box.midX, y: box.midY)
            let hasFiniteCenter = center.x.isFinite && center.y.isFinite
            guard hasFiniteCenter else { continue }

            var updated = item
            switch item.mode {
            case .rectangle, .circle, .blur:
                let baseWidth = max(Double(box.width), 4.0)
                let baseHeight = max(Double(box.height), 4.0)
                let rawWidth = baseWidth * factor
                let rawHeight = baseHeight * factor
                let nextWidth = rawWidth.isFinite ? min(max(rawWidth, 4.0), 65_536.0) : baseWidth
                let nextHeight = rawHeight.isFinite ? min(max(rawHeight, 4.0), 65_536.0) : baseHeight
                let signX: Double = item.endPoint.x >= item.startPoint.x ? 1.0 : -1.0
                let signY: Double = item.endPoint.y >= item.startPoint.y ? 1.0 : -1.0
                let halfW = nextWidth * 0.5
                let halfH = nextHeight * 0.5
                let p1 = Self.clampCanvasPoint(
                    CGPoint(x: Double(center.x) - signX * halfW, y: Double(center.y) - signY * halfH)
                )
                let p2 = Self.clampCanvasPoint(
                    CGPoint(x: Double(center.x) + signX * halfW, y: Double(center.y) + signY * halfH)
                )
                updated.startPoint = p1
                updated.endPoint = p2
                updated.points = [p1, p2]
                updated.isConstrained = false
            case .arrow, .freeHand, .highlighter:
                guard let rawBounds = Self.rawPointBounds(for: item) else { continue }
                let maxRawDim: Double
                if item.usesDirectionalHandles {
                    maxRawDim = hypot(
                        Double(item.endPoint.x - item.startPoint.x),
                        Double(item.endPoint.y - item.startPoint.y)
                    )
                } else {
                    maxRawDim = max(Double(rawBounds.width), Double(rawBounds.height))
                }
                let minScale = maxRawDim > 1e-6 ? (4.0 / maxRawDim) : 1.0
                let maxScale = maxRawDim > 1e-6 ? min(65_536.0 / maxRawDim, 100.0) : 100.0
                let effectiveFactor = min(max(factor, minScale), max(maxScale, minScale))
                guard effectiveFactor.isFinite else { continue }
                let scalePoint: (CGPoint) -> CGPoint = { pt in
                    let x = Double(center.x) + (Double(pt.x) - Double(center.x)) * effectiveFactor
                    let y = Double(center.y) + (Double(pt.y) - Double(center.y)) * effectiveFactor
                    return Self.clampCanvasPoint(CGPoint(x: x, y: y))
                }
                updated.startPoint = scalePoint(item.startPoint)
                updated.endPoint = scalePoint(item.endPoint)
                if item.mode == .arrow {
                    updated.points = [updated.startPoint, updated.endPoint]
                } else if item.isConstrainedStraightLine {
                    updated.points = [updated.startPoint, updated.endPoint]
                    updated.isConstrained = true
                } else {
                    updated.points = item.points.map(scalePoint)
                }
                if item.usesDirectionalHandles, let customHead = item.headWidth {
                    updated.headWidth = AnnotationItem.sanitizeHeadWidth(customHead * effectiveFactor)
                }
            case .text:
                break
            }

            if updated != item {
                nextAnnotations[index] = updated
                anyChanged = true
            }
        }

        guard anyChanged else { return }
        recordTransformUndoSnapshotIfNeeded()
        annotations = nextAnnotations
    }

    public func applyCornerScale(_ request: AnnotationCornerScaleRequest) {
        let cornerIndex = request.anchor.cornerIndex
        let isValidCorner = cornerIndex >= 0 && cornerIndex <= 3
        guard isValidCorner else { return }

        let startPt = request.motion.dragStartPoint
        let currentPt = request.motion.currentPoint
        let hasFiniteStart = startPt.x.isFinite && startPt.y.isFinite
        let hasFiniteCurrent = currentPt.x.isFinite && currentPt.y.isFinite
        guard hasFiniteStart && hasFiniteCurrent else { return }

        let deltaX = Double(currentPt.x) - Double(startPt.x)
        let deltaY = Double(currentPt.y) - Double(startPt.y)
        let hasFiniteDelta = deltaX.isFinite && deltaY.isFinite
        guard hasFiniteDelta else { return }
        let isZeroDelta = deltaX == 0.0 && deltaY == 0.0
        guard !isZeroDelta else { return }

        let initial = request.anchor.initialItem
        guard initial.mode != .text else { return }
        guard Self.hasAllFinitePoints(initial) else { return }
        guard let index = annotations.firstIndex(where: { $0.id == initial.id }) else { return }

        var updated = initial
        switch initial.mode {
        case .rectangle, .circle, .blur:
            let box = initial.boundingRect
            let hasFiniteOrigin = box.origin.x.isFinite && box.origin.y.isFinite
            let hasFiniteSize = box.size.width.isFinite && box.size.height.isFinite
            guard hasFiniteOrigin && hasFiniteSize else { return }

            let rawGrabbed: CGPoint
            let rawAnchor: CGPoint
            let defaultSignX: Double
            let defaultSignY: Double
            switch cornerIndex {
            case 0:
                rawGrabbed = CGPoint(x: box.minX, y: box.minY)
                rawAnchor = CGPoint(x: box.maxX, y: box.maxY)
                defaultSignX = -1.0
                defaultSignY = -1.0
            case 1:
                rawGrabbed = CGPoint(x: box.maxX, y: box.minY)
                rawAnchor = CGPoint(x: box.minX, y: box.maxY)
                defaultSignX = 1.0
                defaultSignY = -1.0
            case 2:
                rawGrabbed = CGPoint(x: box.maxX, y: box.maxY)
                rawAnchor = CGPoint(x: box.minX, y: box.minY)
                defaultSignX = 1.0
                defaultSignY = 1.0
            default:
                rawGrabbed = CGPoint(x: box.minX, y: box.maxY)
                rawAnchor = CGPoint(x: box.maxX, y: box.minY)
                defaultSignX = -1.0
                defaultSignY = 1.0
            }

            let safeAnchor = Self.clampCanvasPoint(rawAnchor)
            let candidateX = Double(rawGrabbed.x) + deltaX
            let candidateY = Double(rawGrabbed.y) + deltaY
            guard candidateX.isFinite && candidateY.isFinite else { return }

            let rawDiffX = candidateX - Double(safeAnchor.x)
            let rawDiffY = candidateY - Double(safeAnchor.y)
            let signX: Double = rawDiffX > 0 ? 1.0 : (rawDiffX < 0 ? -1.0 : defaultSignX)
            let signY: Double = rawDiffY > 0 ? 1.0 : (rawDiffY < 0 ? -1.0 : defaultSignY)

            let spanX: Double
            let spanY: Double
            if request.constraint == .uniform {
                let constrainedRect = ce_make_rect(
                    CEPoint(x: Double(safeAnchor.x), y: Double(safeAnchor.y)),
                    CEPoint(x: candidateX, y: candidateY),
                    true
                )
                let rawSide = max(constrainedRect.width, constrainedRect.height)
                let safeSide = rawSide.isFinite ? max(rawSide, 4.0) : 4.0
                spanX = safeSide
                spanY = safeSide
            } else {
                spanX = max(abs(rawDiffX), 4.0)
                spanY = max(abs(rawDiffY), 4.0)
            }

            let clampedCorner = Self.clampCanvasPoint(
                CGPoint(
                    x: Double(safeAnchor.x) + signX * spanX,
                    y: Double(safeAnchor.y) + signY * spanY
                )
            )
            updated.startPoint = safeAnchor
            updated.endPoint = clampedCorner
            updated.points = [safeAnchor, clampedCorner]
            updated.isConstrained = false

        case .arrow, .freeHand, .highlighter:
            guard let rawBounds = Self.rawPointBounds(for: initial) else { return }
            let rawGrabbed: CGPoint
            let rawAnchor: CGPoint
            switch cornerIndex {
            case 0:
                rawGrabbed = CGPoint(x: rawBounds.minX, y: rawBounds.minY)
                rawAnchor = CGPoint(x: rawBounds.maxX, y: rawBounds.maxY)
            case 1:
                rawGrabbed = CGPoint(x: rawBounds.maxX, y: rawBounds.minY)
                rawAnchor = CGPoint(x: rawBounds.minX, y: rawBounds.maxY)
            case 2:
                rawGrabbed = CGPoint(x: rawBounds.maxX, y: rawBounds.maxY)
                rawAnchor = CGPoint(x: rawBounds.minX, y: rawBounds.minY)
            default:
                rawGrabbed = CGPoint(x: rawBounds.minX, y: rawBounds.maxY)
                rawAnchor = CGPoint(x: rawBounds.maxX, y: rawBounds.minY)
            }

            let isTwoDimensional = rawBounds.width >= 8.0 && rawBounds.height >= 8.0
            if isTwoDimensional && request.constraint == .free {
                let rawSpanX = Double(rawGrabbed.x - rawAnchor.x)
                let rawSpanY = Double(rawGrabbed.y - rawAnchor.y)
                let hasValidSpans = abs(rawSpanX) >= 8.0 && abs(rawSpanY) >= 8.0
                guard hasValidSpans else { return }

                let targetSpanX = Double(rawGrabbed.x) + deltaX - Double(rawAnchor.x)
                let targetSpanY = Double(rawGrabbed.y) + deltaY - Double(rawAnchor.y)
                guard targetSpanX.isFinite && targetSpanY.isFinite else { return }

                let defaultSignX: Double = rawSpanX >= 0 ? 1.0 : -1.0
                let defaultSignY: Double = rawSpanY >= 0 ? 1.0 : -1.0
                let signX: Double = targetSpanX > 0 ? 1.0 : (targetSpanX < 0 ? -1.0 : defaultSignX)
                let signY: Double = targetSpanY > 0 ? 1.0 : (targetSpanY < 0 ? -1.0 : defaultSignY)
                let clampedSpanX = signX * min(max(abs(targetSpanX), 8.0), 32_768.0)
                let clampedSpanY = signY * min(max(abs(targetSpanY), 8.0), 32_768.0)

                let scaleX = clampedSpanX / rawSpanX
                let scaleY = clampedSpanY / rawSpanY
                guard scaleX.isFinite && scaleY.isFinite else { return }

                let mapPoint: (CGPoint) -> CGPoint = { pt in
                    let x = Double(rawAnchor.x) + (Double(pt.x) - Double(rawAnchor.x)) * scaleX
                    let y = Double(rawAnchor.y) + (Double(pt.y) - Double(rawAnchor.y)) * scaleY
                    return Self.clampCanvasPoint(CGPoint(x: x, y: y))
                }
                updated.startPoint = mapPoint(initial.startPoint)
                updated.endPoint = mapPoint(initial.endPoint)
                if initial.mode == .arrow {
                    updated.points = [updated.startPoint, updated.endPoint]
                } else {
                    updated.points = initial.points.map(mapPoint)
                }
            } else {
                let anchorX = rawBounds.width < 8.0 ? rawBounds.midX : rawAnchor.x
                let anchorY = rawBounds.height < 8.0 ? rawBounds.midY : rawAnchor.y
                let anchorPoint = CGPoint(x: anchorX, y: anchorY)
                let initialDist = max(
                    hypot(Double(startPt.x - anchorPoint.x), Double(startPt.y - anchorPoint.y)),
                    8.0
                )
                let currentDist = hypot(
                    Double(currentPt.x - anchorPoint.x),
                    Double(currentPt.y - anchorPoint.y)
                )
                guard initialDist.isFinite && currentDist.isFinite else { return }

                var minScale = 0.10
                if initial.mode == .arrow {
                    let initialLen = hypot(
                        Double(initial.endPoint.x - initial.startPoint.x),
                        Double(initial.endPoint.y - initial.startPoint.y)
                    )
                    if initialLen > 1e-6 {
                        minScale = max(minScale, 8.0 / initialLen)
                    }
                }
                let rawRatio = currentDist / initialDist
                guard rawRatio.isFinite else { return }
                let maxScale = max(20.0, minScale)
                let uniformScale = min(max(rawRatio, minScale), maxScale)

                let mapPoint: (CGPoint) -> CGPoint = { pt in
                    let x = Double(anchorPoint.x) + (Double(pt.x) - Double(anchorPoint.x)) * uniformScale
                    let y = Double(anchorPoint.y) + (Double(pt.y) - Double(anchorPoint.y)) * uniformScale
                    return Self.clampCanvasPoint(CGPoint(x: x, y: y))
                }
                updated.startPoint = mapPoint(initial.startPoint)
                updated.endPoint = mapPoint(initial.endPoint)
                if initial.mode == .arrow {
                    let arrowLen = hypot(
                        Double(updated.endPoint.x - updated.startPoint.x),
                        Double(updated.endPoint.y - updated.startPoint.y)
                    )
                    if arrowLen < 8.0 {
                        let dx = Double(initial.endPoint.x - initial.startPoint.x)
                        let dy = Double(initial.endPoint.y - initial.startPoint.y)
                        let baseLen = hypot(dx, dy)
                        let unitX = baseLen > 1e-6 ? (dx / baseLen) : 1.0
                        let unitY = baseLen > 1e-6 ? (dy / baseLen) : 0.0
                        updated.endPoint = Self.clampCanvasPoint(
                            CGPoint(
                                x: Double(updated.startPoint.x) + unitX * 8.0,
                                y: Double(updated.startPoint.y) + unitY * 8.0
                            )
                        )
                    }
                    updated.points = [updated.startPoint, updated.endPoint]
                } else {
                    updated.points = initial.points.map(mapPoint)
                }
            }

        case .text:
            return
        }

        guard updated != annotations[index] else { return }
        recordTransformUndoSnapshotIfNeeded()
        annotations[index] = updated
    }

    public func applyDirectionalHandleDrag(_ request: AnnotationDirectionalDragRequest) {
        let currentPt = request.currentPoint
        let hasFiniteCurrent = currentPt.x.isFinite && currentPt.y.isFinite
        guard hasFiniteCurrent else { return }

        let initial = request.initialItem
        guard initial.usesDirectionalHandles else { return }
        guard Self.hasAllFinitePoints(initial) else { return }
        guard let index = annotations.firstIndex(where: { $0.id == initial.id }) else { return }

        let initStartX = Double(initial.startPoint.x)
        let initStartY = Double(initial.startPoint.y)
        let initEndX = Double(initial.endPoint.x)
        let initEndY = Double(initial.endPoint.y)
        let initDX = initEndX - initStartX
        let initDY = initEndY - initStartY
        guard initDX.isFinite && initDY.isFinite else { return }
        let initLen = hypot(initDX, initDY)
        let initUX = initLen > 1e-6 ? (initDX / initLen) : 1.0
        let initUY = initLen > 1e-6 ? (initDY / initLen) : 0.0
        let px = -initUY
        let py = initUX

        var updated = initial
        switch request.handle {
        case .tail, .tip:
            let isTail = request.handle == .tail
            let rawAnchor = isTail ? initial.endPoint : initial.startPoint
            let safeAnchor = Self.clampCanvasPoint(rawAnchor)
            let anchorX = Double(safeAnchor.x)
            let anchorY = Double(safeAnchor.y)
            var candidateX = Double(currentPt.x)
            var candidateY = Double(currentPt.y)
            if request.angleSnap == .fortyFiveDegrees {
                let snapped = ce_constrain_line(
                    CEPoint(x: anchorX, y: anchorY),
                    CEPoint(x: candidateX, y: candidateY)
                )
                candidateX = snapped.x
                candidateY = snapped.y
            }
            guard candidateX.isFinite && candidateY.isFinite else { return }
            let diffX = candidateX - anchorX
            let diffY = candidateY - anchorY
            let dist = hypot(diffX, diffY)
            guard dist.isFinite else { return }
            let resolvedMoving: CGPoint
            if dist < 8.0 {
                let fallbackUX = isTail ? -initUX : initUX
                let fallbackUY = isTail ? -initUY : initUY
                resolvedMoving = Self.clampCanvasPoint(
                    CGPoint(x: anchorX + fallbackUX * 8.0, y: anchorY + fallbackUY * 8.0)
                )
            } else {
                resolvedMoving = Self.clampCanvasPoint(CGPoint(x: candidateX, y: candidateY))
            }
            if isTail {
                updated.startPoint = resolvedMoving
                updated.endPoint = safeAnchor
            } else {
                updated.startPoint = safeAnchor
                updated.endPoint = resolvedMoving
            }
            updated.points = [updated.startPoint, updated.endPoint]
            if initial.isConstrainedStraightLine {
                updated.isConstrained = true
            } else {
                updated.isConstrained = request.angleSnap == .fortyFiveDegrees
            }
        case .headWidth:
            let dx = Double(currentPt.x) - initStartX
            let dy = Double(currentPt.y) - initStartY
            guard dx.isFinite && dy.isFinite else { return }
            let perpDist = abs(dx * px + dy * py)
            guard perpDist.isFinite else { return }
            let nextHeadWidth: Double
            if initial.mode == .arrow {
                nextHeadWidth = AnnotationItem.sanitizeHeadWidth(perpDist * 2.0)
            } else {
                let safeWeight = initial.lineWeight.isFinite ? min(max(initial.lineWeight, 1.0), 64.0) : 6.0
                let approxTailHW = max(1.5, safeWeight * 0.45)
                let rawHalfWidth = max(4.0, (perpDist - 0.18 * approxTailHW) / 0.82)
                nextHeadWidth = AnnotationItem.sanitizeHeadWidth(rawHalfWidth * 2.0)
            }
            updated.headWidth = nextHeadWidth
        }

        guard updated != annotations[index] else { return }
        recordTransformUndoSnapshotIfNeeded()
        annotations[index] = updated
    }

    @discardableResult
    public func adjustSelectedTextFontSize(by delta: Double) -> Double? {
        let isValidDelta = delta.isFinite && delta != 0
        guard isValidDelta && !selectedIDs.isEmpty else { return nil }

        var firstResultSize: Double?
        var anyWillChange = false
        for item in annotations {
            let isSelectedText = selectedIDs.contains(item.id) && item.mode == .text
            guard isSelectedText else { continue }
            let isCurrentFinite = item.fontSize.isFinite
            let baseSize = AnnotationItem.sanitizeFontSize(item.fontSize)
            let rawSum = baseSize + delta
            let clamped = rawSum.isFinite ? min(max(rawSum, 8.0), 200.0) : baseSize
            if firstResultSize == nil {
                firstResultSize = clamped
            }
            let fixedCenter = interactiveTextCenters[item.id] ?? item.textCenter
            let updated = item.withCenteredFontSize(clamped, center: fixedCenter)
            let sizeChanged = !isCurrentFinite || abs(clamped - item.fontSize) > 1e-6
            if sizeChanged || item.startPoint != updated.startPoint {
                anyWillChange = true
            }
        }
        guard let reportedSize = firstResultSize else { return nil }
        guard anyWillChange else { return reportedSize }

        recordTransformUndoSnapshotIfNeeded()
        for index in annotations.indices {
            let item = annotations[index]
            let isSelectedText = selectedIDs.contains(item.id) && item.mode == .text
            guard isSelectedText else { continue }
            let baseSize = AnnotationItem.sanitizeFontSize(item.fontSize)
            let rawSum = baseSize + delta
            let nextSize = rawSum.isFinite ? min(max(rawSum, 8.0), 200.0) : baseSize
            let fixedCenter = interactiveTextCenters[item.id] ?? item.textCenter
            annotations[index] = item.withCenteredFontSize(nextSize, center: fixedCenter)
        }
        return reportedSize
    }

    @discardableResult
    public func adjustSelectedStrokeLineWeight(by delta: Double) -> Double? {
        let isValidDelta = delta.isFinite && delta != 0
        guard isValidDelta && !selectedIDs.isEmpty else { return nil }

        var firstResultWeight: Double?
        var anyWillChange = false
        for item in annotations {
            let isSelectedStroke = selectedIDs.contains(item.id) && item.mode.supportsStrokeLineWeight
            guard isSelectedStroke else { continue }
            let isCurrentFinite = item.lineWeight.isFinite
            let baseWeight = isCurrentFinite ? min(max(item.lineWeight, 1.0), 64.0) : 6.0
            let rawSum = baseWeight + delta
            let clamped = rawSum.isFinite ? min(max(rawSum, 1.0), 64.0) : baseWeight
            if firstResultWeight == nil {
                firstResultWeight = clamped
            }
            let weightChanged = !isCurrentFinite || abs(clamped - item.lineWeight) > 1e-6
            var headChanged = false
            if let customHead = item.headWidth {
                let safeCustomHead = AnnotationItem.sanitizeHeadWidth(customHead)
                let requiredHead = AnnotationItem.sanitizeHeadWidth(max(safeCustomHead, clamped * 1.4))
                headChanged = !customHead.isFinite || abs(requiredHead - customHead) > 1e-6
            }
            if weightChanged || headChanged {
                anyWillChange = true
            }
        }
        guard let reportedWeight = firstResultWeight else { return nil }
        guard anyWillChange else { return reportedWeight }

        recordTransformUndoSnapshotIfNeeded()
        for index in annotations.indices {
            let item = annotations[index]
            let isSelectedStroke = selectedIDs.contains(item.id) && item.mode.supportsStrokeLineWeight
            guard isSelectedStroke else { continue }
            let baseWeight = item.lineWeight.isFinite ? min(max(item.lineWeight, 1.0), 64.0) : 6.0
            let rawSum = baseWeight + delta
            let nextWeight = rawSum.isFinite ? min(max(rawSum, 1.0), 64.0) : baseWeight
            annotations[index].lineWeight = nextWeight
            if let customHead = annotations[index].headWidth {
                let safeCustomHead = AnnotationItem.sanitizeHeadWidth(customHead)
                annotations[index].headWidth = AnnotationItem.sanitizeHeadWidth(max(safeCustomHead, nextWeight * 1.4))
            }
        }
        return reportedWeight
    }

    public func setTextRotation(_ radians: Double, for id: UUID) {
        guard radians.isFinite else { return }
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard annotations[index].mode == .text else { return }
        let normalized = Self.sanitizeRotationRadians(radians)
        let currentRaw = annotations[index].rotationRadians
        let isUnchanged = currentRaw.isFinite && abs(currentRaw - normalized) <= 1e-9
        guard !isUnchanged else { return }

        recordTransformUndoSnapshotIfNeeded()
        annotations[index].rotationRadians = normalized
    }

    public func rotateSelectedTextAnnotations(by deltaRadians: Double) {
        let isValidDelta = deltaRadians.isFinite && abs(deltaRadians) > 1e-9
        guard isValidDelta && !selectedIDs.isEmpty else { return }
        let normalizedDelta = Self.sanitizeRotationRadians(deltaRadians)
        guard abs(normalizedDelta) > 1e-9 else { return }
        guard hasSelectedTextAnnotations else { return }

        recordTransformUndoSnapshotIfNeeded()
        for index in annotations.indices {
            let isSelectedText = selectedIDs.contains(annotations[index].id) && annotations[index].mode == .text
            if isSelectedText {
                let baseAngle = Self.sanitizeRotationRadians(annotations[index].effectiveRotationRadians)
                annotations[index].rotationRadians = Self.sanitizeRotationRadians(baseAngle + normalizedDelta)
            }
        }
    }

    public func applyColorUpdate(_ update: AnnotationColorUpdate) {
        guard !selectedIDs.isEmpty else { return }
        let safeColor = update.color.sanitized
        let safeGradient = update.gradient?.sanitized
        let safeHighlighterColor = safeColor.withAlpha(0.42)

        let willChange = annotations.contains { item in
            let isEditableSelection = selectedIDs.contains(item.id) && item.id != activeInlineEditingID
            guard isEditableSelection else { return false }
            switch item.mode {
            case .text:
                return item.strokeColor != safeColor || item.gradientPair != nil
            case .highlighter:
                return item.strokeColor != safeHighlighterColor || item.gradientPair != safeGradient
            case .freeHand, .arrow, .rectangle, .circle:
                return item.strokeColor != safeColor || item.gradientPair != safeGradient
            case .blur:
                return item.blurTintColor != safeColor
            }
        }
        guard willChange else { return }

        if let token = update.coalescingToken {
            if lastCoalescedColorToken != token {
                recordUndoSnapshot()
            }
            lastCoalescedColorToken = token
        } else {
            recordUndoSnapshot()
        }

        for index in annotations.indices {
            let itemID = annotations[index].id
            let isEditableSelection = selectedIDs.contains(itemID) && itemID != activeInlineEditingID
            guard isEditableSelection else { continue }
            switch annotations[index].mode {
            case .text:
                annotations[index].strokeColor = safeColor
                annotations[index].gradientPair = nil
            case .highlighter:
                annotations[index].strokeColor = safeHighlighterColor
                annotations[index].gradientPair = safeGradient
            case .freeHand, .arrow, .rectangle, .circle:
                annotations[index].strokeColor = safeColor
                annotations[index].gradientPair = safeGradient
            case .blur:
                annotations[index].blurTintColor = safeColor
            }
        }
    }

    public func updateSelectedStrokeLineWeight(_ weight: Double) {
        let isValidInput = weight.isFinite && !selectedIDs.isEmpty
        guard isValidInput else { return }
        let clamped = min(max(weight, 1.0), 64.0)
        let willChange = annotations.contains { item in
            let isSelectedStroke = selectedIDs.contains(item.id) && item.mode.supportsStrokeLineWeight
            guard isSelectedStroke else { return false }
            let weightDiffers = !item.lineWeight.isFinite || abs(item.lineWeight - clamped) > 1e-6
            if weightDiffers {
                return true
            }
            guard let customHead = item.headWidth else { return false }
            let safeCustomHead = AnnotationItem.sanitizeHeadWidth(customHead)
            let requiredHead = AnnotationItem.sanitizeHeadWidth(max(safeCustomHead, clamped * 1.4))
            return !customHead.isFinite || abs(requiredHead - customHead) > 1e-6
        }
        guard willChange else { return }
        recordUndoSnapshot()
        for index in annotations.indices {
            let isSelectedStroke = selectedIDs.contains(annotations[index].id) && annotations[index].mode.supportsStrokeLineWeight
            if isSelectedStroke {
                annotations[index].lineWeight = clamped
                if let customHead = annotations[index].headWidth {
                    let safeCustomHead = AnnotationItem.sanitizeHeadWidth(customHead)
                    annotations[index].headWidth = AnnotationItem.sanitizeHeadWidth(max(safeCustomHead, clamped * 1.4))
                }
            }
        }
    }

    public func applySelectedTailFade(_ mode: AnnotationTailFadeMode) {
        guard !selectedIDs.isEmpty else { return }
        let targetEnabled = mode == .enabled
        let willChange = annotations.contains { item in
            let isSelectedEditable = selectedIDs.contains(item.id) && item.id != activeInlineEditingID
            let isTargetDirectional = isSelectedEditable && item.usesDirectionalHandles
            return isTargetDirectional && item.tailFadeEnabled != targetEnabled
        }
        guard willChange else { return }
        recordUndoSnapshot()
        for index in annotations.indices {
            let item = annotations[index]
            let isSelectedEditable = selectedIDs.contains(item.id) && item.id != activeInlineEditingID
            let isTargetDirectional = isSelectedEditable && item.usesDirectionalHandles
            if isTargetDirectional {
                annotations[index].tailFadeEnabled = targetEnabled
            }
        }
    }

    public func updateSelectedBlurOpacity(_ opacity: Double) {
        guard !selectedIDs.isEmpty else { return }
        let clamped = opacity.isFinite ? min(max(opacity, 0.10), 1.00) : 0.55
        let willChange = annotations.contains { item in
            let isSelectedBlur = selectedIDs.contains(item.id) && item.mode == .blur
            return isSelectedBlur && item.blurOpacity != clamped
        }
        guard willChange else { return }
        recordUndoSnapshot()
        for index in annotations.indices {
            let isSelectedBlur = selectedIDs.contains(annotations[index].id) && annotations[index].mode == .blur
            if isSelectedBlur {
                annotations[index].blurOpacity = clamped
            }
        }
    }

    public func updateSelectedBlurStyle(_ style: BlurStyle) {
        guard !selectedIDs.isEmpty else { return }
        let willChange = annotations.contains { item in
            let isSelectedBlur = selectedIDs.contains(item.id) && item.mode == .blur
            let differsFromTarget = item.blurStyle != style || item.isFilled
            return isSelectedBlur && differsFromTarget
        }
        guard willChange else { return }
        recordUndoSnapshot()
        for index in annotations.indices {
            let isSelectedBlur = selectedIDs.contains(annotations[index].id) && annotations[index].mode == .blur
            if isSelectedBlur {
                annotations[index].blurStyle = style
                annotations[index].isFilled = false
            }
        }
    }

    public func updateSelectedBlurTintColor(_ tintColor: RGBColor?) {
        guard !selectedIDs.isEmpty else { return }
        let willChange = annotations.contains { item in
            let isSelectedBlur = selectedIDs.contains(item.id) && item.mode == .blur
            return isSelectedBlur && item.blurTintColor != tintColor
        }
        guard willChange else { return }
        recordUndoSnapshot()
        for index in annotations.indices {
            let isSelectedBlur = selectedIDs.contains(annotations[index].id) && annotations[index].mode == .blur
            if isSelectedBlur {
                annotations[index].blurTintColor = tintColor
            }
        }
    }

    public func deleteSelectedOrClearAll() {
        lastCoalescedColorToken = nil
        if !selectedIDs.isEmpty {
            endInteractiveTransform()
            recordUndoSnapshot()
            annotations.removeAll { selectedIDs.contains($0.id) }
            selectedIDs.removeAll()
            selectionRectangle = nil
        } else {
            clearAll()
        }
    }

    public func clearAll() {
        lastCoalescedColorToken = nil
        endInteractiveTransform()
        guard !annotations.isEmpty || activeDraft != nil else { return }
        if !annotations.isEmpty {
            recordUndoSnapshot()
        }
        annotations.removeAll()
        activeDraft = nil
        selectedIDs.removeAll()
        selectionRectangle = nil
    }

    @discardableResult
    public func copySelectedAnnotations() -> Bool {
        let itemsToCopy = annotations.filter { selectedIDs.contains($0.id) }
        guard !itemsToCopy.isEmpty else { return false }
        copiedAnnotations = itemsToCopy
        pasteCount = 0
        return true
    }

    public func pasteAnnotations(offsetStep: CGFloat = 20.0) {
        guard !copiedAnnotations.isEmpty else { return }
        endInteractiveTransform()
        recordUndoSnapshot()
        pasteCount += 1
        let safeStep = offsetStep.isFinite ? Double(offsetStep) : 20.0
        let offset = Double(pasteCount) * safeStep

        var newlyPastedIDs: Set<UUID> = []
        for source in copiedAnnotations {
            var copy = source
            copy.id = UUID()
            copy.startPoint = Self.clampCanvasPoint(
                CGPoint(x: Double(source.startPoint.x) + offset, y: Double(source.startPoint.y) + offset)
            )
            copy.endPoint = Self.clampCanvasPoint(
                CGPoint(x: Double(source.endPoint.x) + offset, y: Double(source.endPoint.y) + offset)
            )
            copy.points = source.points.map { point in
                Self.clampCanvasPoint(
                    CGPoint(x: Double(point.x) + offset, y: Double(point.y) + offset)
                )
            }
            copy.createdAt = Date().timeIntervalSince1970
            annotations.append(copy)
            newlyPastedIDs.insert(copy.id)
        }
        selectedIDs = newlyPastedIDs
    }

    public func undo() {
        lastCoalescedColorToken = nil
        endInteractiveTransform()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        selectedIDs.removeAll()
        selectionRectangle = nil
    }

    public func redo() {
        lastCoalescedColorToken = nil
        endInteractiveTransform()
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        selectedIDs.removeAll()
        selectionRectangle = nil
    }

    public func pruneExpiredAnnotations(now: TimeInterval = Date().timeIntervalSince1970, delay: TimeInterval) {
        annotations.removeAll { item in
            ce_is_stroke_expired(item.createdAt, now, delay, item.isAutoErase)
        }
    }

    public func exportSessionData() -> Data? {
        try? JSONEncoder().encode(annotations)
    }

    public static func sanitizeRotationRadians(_ raw: Double) -> Double {
        guard raw.isFinite else { return 0.0 }
        let normalized = raw.remainder(dividingBy: 2.0 * .pi)
        if normalized == 0.0 {
            return 0.0
        }
        return normalized
    }

    fileprivate static func clampCanvasCoordinate(_ value: Double) -> Double {
        if value.isFinite {
            return min(max(value, -32_768.0), 32_768.0)
        }
        if value == .infinity {
            return 32_768.0
        }
        if value == -.infinity {
            return -32_768.0
        }
        return 0.0
    }

    fileprivate static func clampCanvasPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: clampCanvasCoordinate(Double(point.x)),
            y: clampCanvasCoordinate(Double(point.y))
        )
    }

    private static func closedStrokePoints(_ vertices: [CGPoint]) -> [CEPoint] {
        guard let first = vertices.first else { return [] }
        return (vertices + [first]).map { CEPoint(x: Double($0.x), y: Double($0.y)) }
    }

    private static func pointInPolygon(_ point: CGPoint, vertices: [CGPoint]) -> Bool {
        guard vertices.count >= 3 else { return false }
        let px = Double(point.x)
        let py = Double(point.y)
        guard px.isFinite && py.isFinite else { return false }
        var inside = false
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let xi = Double(vertices[i].x)
            let yi = Double(vertices[i].y)
            let xj = Double(vertices[j].x)
            let yj = Double(vertices[j].y)
            let hasFiniteEdge = xi.isFinite && yi.isFinite
            let hasFinitePrev = xj.isFinite && yj.isFinite
            guard hasFiniteEdge && hasFinitePrev else { return false }
            let spansY = (yi > py) != (yj > py)
            if spansY {
                let intersectX = (xj - xi) * (py - yi) / (yj - yi) + xi
                if px < intersectX {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    private static func rectIntersectsPolygon(_ normalized: CGRect, vertices: [CGPoint]) -> Bool {
        guard !vertices.isEmpty else { return false }
        let hasFiniteOrigin = normalized.origin.x.isFinite && normalized.origin.y.isFinite
        let hasFiniteSize = normalized.size.width.isFinite && normalized.size.height.isFinite
        guard hasFiniteOrigin && hasFiniteSize else { return false }
        let containsVertex = vertices.contains { vertex in
            let inXRange = vertex.x >= normalized.minX && vertex.x <= normalized.maxX
            let inYRange = vertex.y >= normalized.minY && vertex.y <= normalized.maxY
            return inXRange && inYRange
        }
        if containsVertex {
            return true
        }
        let samplePoints = [
            CGPoint(x: normalized.midX, y: normalized.midY),
            CGPoint(x: normalized.minX, y: normalized.minY),
            CGPoint(x: normalized.maxX, y: normalized.minY),
            CGPoint(x: normalized.maxX, y: normalized.maxY),
            CGPoint(x: normalized.minX, y: normalized.maxY)
        ]
        if samplePoints.contains(where: { pointInPolygon($0, vertices: vertices) }) {
            return true
        }
        let ceMarquee = CERect(
            x: Double(normalized.origin.x),
            y: Double(normalized.origin.y),
            width: Double(normalized.size.width),
            height: Double(normalized.size.height)
        )
        let closedEdges = closedStrokePoints(vertices)
        return closedEdges.withUnsafeBufferPointer { ptr in
            ce_rect_intersects_stroke(ceMarquee, ptr.baseAddress, ptr.count)
        }
    }

    private static func hasAllFinitePoints(_ item: AnnotationItem) -> Bool {
        let hasFiniteStart = item.startPoint.x.isFinite && item.startPoint.y.isFinite
        let hasFiniteEnd = item.endPoint.x.isFinite && item.endPoint.y.isFinite
        guard hasFiniteStart && hasFiniteEnd else { return false }
        return item.points.allSatisfy { $0.x.isFinite && $0.y.isFinite }
    }

    private static func rawPointBounds(for item: AnnotationItem) -> CGRect? {
        let allPoints = [item.startPoint, item.endPoint] + item.points
        var minX = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for pt in allPoints {
            let x = Double(pt.x)
            let y = Double(pt.y)
            guard x.isFinite && y.isFinite else { return nil }
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
        let width = maxX - minX
        let height = maxY - minY
        guard width.isFinite && height.isFinite else { return nil }
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    @discardableResult
    public func importSessionData(_ data: Data) -> Bool {
        guard data.count <= 4_194_304 else { return false }
        guard let decoded = try? JSONDecoder().decode([AnnotationItem].self, from: data) else {
            return false
        }
        guard decoded.count <= 2_000 else { return false }
        var sanitized: [AnnotationItem] = []
        sanitized.reserveCapacity(decoded.count)
        for var item in decoded {
            let isWithinItemLimits = item.points.count <= 10_000 && item.text.count <= AnnotationItem.maxTextLength
            guard isWithinItemLimits else {
                return false
            }
            for point in [item.startPoint, item.endPoint] {
                let isFinitePoint = point.x.isFinite && point.y.isFinite
                let isWithinCoordRange = abs(point.x) <= 32_768.0 && abs(point.y) <= 32_768.0
                guard isFinitePoint && isWithinCoordRange else {
                    return false
                }
            }
            for point in item.points {
                let isFinitePoint = point.x.isFinite && point.y.isFinite
                let isWithinCoordRange = abs(point.x) <= 32_768.0 && abs(point.y) <= 32_768.0
                guard isFinitePoint && isWithinCoordRange else {
                    return false
                }
            }
            if item.fontName.count > 256 {
                item.fontName = String(item.fontName.prefix(256))
            }
            item.lineWeight = item.lineWeight.isFinite ? min(max(item.lineWeight, 1.0), 64.0) : 6.0
            item.fontSize = AnnotationItem.sanitizeFontSize(item.fontSize)
            item.rotationRadians = Self.sanitizeRotationRadians(item.rotationRadians)
            if item.usesDirectionalHandles {
                if let rawHeadWidth = item.headWidth {
                    item.headWidth = AnnotationItem.sanitizeHeadWidth(rawHeadWidth)
                }
            } else {
                item.headWidth = nil
                item.tailFadeEnabled = false
            }
            if let rawOpacity = item.blurOpacity {
                item.blurOpacity = rawOpacity.isFinite ? min(max(rawOpacity, 0.10), 1.00) : 0.55
            }
            if let rawTint = item.blurTintColor {
                item.blurTintColor = RGBColor(
                    red: rawTint.red.isFinite ? rawTint.red : 0.08,
                    green: rawTint.green.isFinite ? rawTint.green : 0.52,
                    blue: rawTint.blue.isFinite ? rawTint.blue : 0.98,
                    alpha: 1.0
                )
            }
            sanitized.append(item)
        }
        endInteractiveTransform()
        recordUndoSnapshot()
        annotations = sanitized
        selectedIDs.removeAll()
        selectionRectangle = nil
        return true
    }

    private func recordTransformUndoSnapshotIfNeeded() {
        if isInteractiveTransformActive {
            guard !didRecordInteractiveSnapshot else { return }
            didRecordInteractiveSnapshot = true
        }
        recordUndoSnapshot()
    }

    private func recordUndoSnapshot() {
        lastCoalescedColorToken = nil
        undoStack.append(annotations)
        redoStack.removeAll()
    }
}
