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
        self.red = min(max(red, 0.0), 1.0)
        self.green = min(max(green, 0.0), 1.0)
        self.blue = min(max(blue, 0.0), 1.0)
        self.alpha = min(max(alpha, 0.0), 1.0)
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
        rotationRadians: Double = 0.0
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
        let hasFiniteCenter = center.x.isFinite && center.y.isFinite
        guard hasFiniteCenter else { return updated }
        let measuredRect = updated.textLayoutRect
        let newOrigin = CGPoint(
            x: center.x - measuredRect.width * 0.5,
            y: center.y - measuredRect.height * 0.5
        )
        updated.startPoint = newOrigin
        updated.endPoint = newOrigin
        updated.points = [newOrigin]
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
            let cePoints = [
                CEPoint(x: Double(startPoint.x), y: Double(startPoint.y)),
                CEPoint(x: Double(endPoint.x), y: Double(endPoint.y))
            ]
            let box = cePoints.withUnsafeBufferPointer { ptr in
                ce_compute_bounding_box(ptr.baseAddress, ptr.count, lineWeight * 2.0)
            }
            return CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
        case .freeHand, .highlighter:
            let cePoints = points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
            let box = cePoints.withUnsafeBufferPointer { ptr in
                ce_compute_bounding_box(ptr.baseAddress, ptr.count, lineWeight)
            }
            return CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
        }
    }

    public func arrowPolygonPoints() -> [CGPoint] {
        var buffer = Array(repeating: CEPoint(x: 0, y: 0), count: 7)
        let count = buffer.withUnsafeMutableBufferPointer { ptr in
            ce_build_arrow_polygon(
                CEPoint(x: Double(startPoint.x), y: Double(startPoint.y)),
                CEPoint(x: Double(endPoint.x), y: Double(endPoint.y)),
                lineWeight,
                ptr.baseAddress,
                7
            )
        }
        return buffer.prefix(count).map { CGPoint(x: $0.x, y: $0.y) }
    }
}

public final class AnnotationCanvasState: ObservableObject {
    @Published public var annotations: [AnnotationItem] = []
    @Published public var activeDraft: AnnotationItem?
    @Published public var selectedIDs: Set<UUID> = []
    @Published public var selectionRectangle: CGRect?
    @Published public private(set) var copiedAnnotations: [AnnotationItem] = []
    @Published public private(set) var pasteCount: Int = 0
    @Published public private(set) var undoStack: [[AnnotationItem]] = []
    @Published public private(set) var redoStack: [[AnnotationItem]] = []

    private var isInteractiveTransformActive = false
    private var didRecordInteractiveSnapshot = false
    private var interactiveTextCenters: [UUID: CGPoint] = [:]

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

    public func finishStroke() {
        guard var draft = activeDraft else { return }
        activeDraft = nil

        if draft.mode == .blur {
            let bounds = draft.boundingRect
            let hasFiniteBounds = bounds.width.isFinite && bounds.height.isFinite
            let hasMinimumBlurSize = bounds.width >= 2.0 && bounds.height >= 2.0
            guard hasFiniteBounds && hasMinimumBlurSize else { return }
        }

        let isFreeformStroke = (draft.mode == .freeHand || draft.mode == .highlighter) && !draft.isConstrained
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

        recordUndoSnapshot()
        annotations.append(draft)
    }

    public func addOrUpdateTextAnnotation(
        id: UUID? = nil,
        at point: CGPoint,
        text: String,
        color: RGBColor,
        fontName: String = AnnotateFontOption.systemDefault.fontName,
        fontSize: Double = 24.0,
        isAutoErase: Bool = false,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        let hasFinitePoint = point.x.isFinite && point.y.isFinite
        guard hasFinitePoint else { return }
        let boundedText = AnnotationItem.clampText(text)
        let safeFontSize = AnnotationItem.sanitizeFontSize(fontSize)
        let trimmed = boundedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingID = id, let index = annotations.firstIndex(where: { $0.id == existingID }) {
            recordUndoSnapshot()
            if trimmed.isEmpty {
                annotations.remove(at: index)
                selectedIDs.remove(existingID)
            } else {
                annotations[index].text = boundedText
                annotations[index].strokeColor = color
                annotations[index].fontName = fontName
                annotations[index].fontSize = safeFontSize
                annotations[index].rotationRadians = Self.sanitizeRotationRadians(annotations[index].rotationRadians)
                annotations[index].createdAt = now
            }
            return
        }

        guard !trimmed.isEmpty else { return }
        recordUndoSnapshot()
        let item = AnnotationItem(
            id: id ?? UUID(),
            mode: .text,
            points: [point],
            startPoint: point,
            endPoint: point,
            strokeColor: color,
            lineWeight: 2.0,
            isAutoErase: isAutoErase,
            createdAt: now,
            text: boundedText,
            fontName: fontName,
            fontSize: safeFontSize
        )
        annotations.append(item)
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
                let segment = [
                    CEPoint(x: Double(item.startPoint.x), y: Double(item.startPoint.y)),
                    CEPoint(x: Double(item.endPoint.x), y: Double(item.endPoint.y))
                ]
                let isHit = segment.withUnsafeBufferPointer { ptr in
                    ce_hit_test_stroke(ptr.baseAddress, ptr.count, item.lineWeight * 1.5, testPoint, tolerance)
                }
                if isHit {
                    return item.id
                }
            case .freeHand, .highlighter:
                let strokePoints = item.points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
                let isHit = strokePoints.withUnsafeBufferPointer { ptr in
                    ce_hit_test_stroke(ptr.baseAddress, ptr.count, item.lineWeight, testPoint, tolerance)
                }
                if isHit {
                    return item.id
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
            case .freeHand, .highlighter, .arrow:
                let pts = item.points.map { CEPoint(x: Double($0.x), y: Double($0.y)) }
                let intersects = pts.withUnsafeBufferPointer { ptr in
                    ce_rect_intersects_stroke(ceMarquee, ptr.baseAddress, ptr.count)
                }
                if intersects {
                    matched.insert(item.id)
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

        recordTransformUndoSnapshotIfNeeded()
        for index in annotations.indices where selectedIDs.contains(annotations[index].id) {
            annotations[index].startPoint.x += delta.width
            annotations[index].startPoint.y += delta.height
            annotations[index].endPoint.x += delta.width
            annotations[index].endPoint.y += delta.height
            annotations[index].points = annotations[index].points.map {
                CGPoint(x: $0.x + delta.width, y: $0.y + delta.height)
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
            if !isCurrentFinite {
                return true
            }
            return abs(clamped - item.fontSize) > 1e-6
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
            let sizeChanged = !isCurrentFinite || abs(clamped - item.fontSize) > 1e-6
            if sizeChanged {
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
        let offset = CGFloat(pasteCount) * offsetStep

        var newlyPastedIDs: Set<UUID> = []
        for source in copiedAnnotations {
            var copy = source
            copy.id = UUID()
            copy.startPoint = CGPoint(x: source.startPoint.x + offset, y: source.startPoint.y + offset)
            copy.endPoint = CGPoint(x: source.endPoint.x + offset, y: source.endPoint.y + offset)
            copy.points = source.points.map { CGPoint(x: $0.x + offset, y: $0.y + offset) }
            copy.createdAt = Date().timeIntervalSince1970
            annotations.append(copy)
            newlyPastedIDs.insert(copy.id)
        }
        selectedIDs = newlyPastedIDs
    }

    public func undo() {
        endInteractiveTransform()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        selectedIDs.removeAll()
        selectionRectangle = nil
    }

    public func redo() {
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
        undoStack.append(annotations)
        redoStack.removeAll()
    }
}
