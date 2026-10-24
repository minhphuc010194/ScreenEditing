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

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .freeHand: return "Free Hand"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .text: return "Text"
        case .highlighter: return "Highlighter"
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
        }
    }

    public var iconName: String { systemImage }
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

public struct AnnotationItem: Identifiable, Codable, Equatable, Sendable {
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
        fontSize: Double = 24.0
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
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
    }

    public var boundingRect: CGRect {
        switch mode {
        case .rectangle, .circle:
            let ceRect = ce_make_rect(
                CEPoint(x: Double(startPoint.x), y: Double(startPoint.y)),
                CEPoint(x: Double(endPoint.x), y: Double(endPoint.y)),
                isConstrained
            )
            return CGRect(x: ceRect.x, y: ceRect.y, width: ceRect.width, height: ceRect.height)
        case .text:
            let charCount = max(1, text.count)
            let estimatedWidth = max(60.0, Double(charCount) * fontSize * 0.62)
            let estimatedHeight = max(28.0, fontSize * 1.4)
            return CGRect(x: Double(startPoint.x), y: Double(startPoint.y), width: estimatedWidth, height: estimatedHeight)
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
            createdAt: now
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
        case .rectangle, .circle:
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingID = id, let index = annotations.firstIndex(where: { $0.id == existingID }) {
            recordUndoSnapshot()
            if trimmed.isEmpty {
                annotations.remove(at: index)
                selectedIDs.remove(existingID)
            } else {
                annotations[index].text = text
                annotations[index].strokeColor = color
                annotations[index].fontName = fontName
                annotations[index].fontSize = fontSize
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
            text: text,
            fontName: fontName,
            fontSize: fontSize
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
            case .text:
                let bounds = item.boundingRect
                let rect = CERect(
                    x: Double(bounds.origin.x),
                    y: Double(bounds.origin.y),
                    width: Double(bounds.size.width),
                    height: Double(bounds.size.height)
                )
                if ce_hit_test_rect(rect, true, 2.0, testPoint, tolerance) {
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
            case .rectangle, .circle, .text:
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

    public func moveSelectedAnnotations(by delta: CGSize) {
        let hasNonZeroDelta = delta.width != 0 || delta.height != 0
        guard !selectedIDs.isEmpty, hasNonZeroDelta else { return }

        recordUndoSnapshot()
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

    public func deleteSelectedOrClearAll() {
        if !selectedIDs.isEmpty {
            recordUndoSnapshot()
            annotations.removeAll { selectedIDs.contains($0.id) }
            selectedIDs.removeAll()
            selectionRectangle = nil
        } else {
            clearAll()
        }
    }

    public func clearAll() {
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
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        selectedIDs.removeAll()
        selectionRectangle = nil
    }

    public func redo() {
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

    @discardableResult
    public func importSessionData(_ data: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode([AnnotationItem].self, from: data) else {
            return false
        }
        recordUndoSnapshot()
        annotations = decoded
        selectedIDs.removeAll()
        selectionRectangle = nil
        return true
    }

    private func recordUndoSnapshot() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }
}
