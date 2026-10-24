import Combine
import Foundation
import ServiceManagement

public final class AppSettings: ObservableObject {
    public static let defaultSuiteName = "presentify-user-defaults-suite"
    public static let shared = AppSettings()

    public static let defaultFavColors: [RGBColor] = [
        .red,
        .yellow,
        .green,
        .blue,
        .blue
    ]
    public static let defaultHighlightColor: RGBColor = .blue

    public let defaults: UserDefaults
    private var isRestoring = false

    @Published public var launchAtLogin: Bool {
        didSet {
            persist(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLoginItemIfNeeded(launchAtLogin)
        }
    }
    @Published public var highlightCursorAtLogin: Bool {
        didSet { persist(highlightCursorAtLogin, forKey: Keys.highlightCursorAtLogin) }
    }
    @Published public var showMenuBarIcon: Bool {
        didSet { persist(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }
    @Published public var showDockIcon: Bool {
        didSet { persist(showDockIcon, forKey: Keys.showDockIcon) }
    }
    @Published public var autoCheckUpdates: Bool {
        didSet { persist(autoCheckUpdates, forKey: Keys.autoCheckUpdates) }
    }
    @Published public var automaticallyCheckForUpdates: Bool {
        didSet { persist(automaticallyCheckForUpdates, forKey: Keys.automaticallyCheckForUpdates) }
    }
    @Published public var skippedUpdateVersion: String {
        didSet { persist(skippedUpdateVersion, forKey: Keys.skippedUpdateVersion) }
    }
    @Published public var hasCompletedWelcomeTour: Bool {
        didSet { persist(hasCompletedWelcomeTour, forKey: Keys.hasCompletedWelcomeTour) }
    }
    @Published public var interactiveModeKey: InteractiveModeKey {
        didSet { persistCodable(interactiveModeKey, forKey: Keys.interactiveModeKey) }
    }
    @Published public var annotateInteractiveMode: Bool {
        didSet { persist(annotateInteractiveMode, forKey: Keys.annotateInteractiveMode) }
    }
    @Published public var selectedSettingsTab: SettingsTab {
        didSet { persistCodable(selectedSettingsTab, forKey: Keys.selectedSettingsTab) }
    }

    @Published public var favColors: [RGBColor] {
        didSet { persistCodable(favColors, forKey: Keys.favColors) }
    }
    @Published public var selectedColorIndex: Int {
        didSet { persist(selectedColorIndex, forKey: Keys.selectedColorIndex) }
    }
    @Published public var useRandomColors: Bool {
        didSet { persist(useRandomColors, forKey: Keys.useRandomColors) }
    }
    @Published public var enableGradients: Bool {
        didSet { persist(enableGradients, forKey: Keys.enableGradients) }
    }
    @Published public var activeGradient: GradientPair {
        didSet { persistCodable(activeGradient, forKey: Keys.activeGradient) }
    }
    @Published public var currentDrawMode: DrawMode {
        didSet { persistCodable(currentDrawMode, forKey: Keys.currentDrawMode) }
    }
    @Published public var minLineWeight: Double {
        didSet { persist(minLineWeight, forKey: Keys.minLineWeight) }
    }
    @Published public var maxLineWeight: Double {
        didSet { persist(maxLineWeight, forKey: Keys.maxLineWeight) }
    }
    @Published public var lineWeight: Double {
        didSet {
            let clamped = min(max(lineWeight, minLineWeight), maxLineWeight)
            if clamped != lineWeight {
                lineWeight = clamped
                return
            }
            persist(lineWeight, forKey: Keys.lineWeight)
        }
    }
    @Published public var autoEraseEnabled: Bool {
        didSet { persist(autoEraseEnabled, forKey: Keys.autoEraseEnabled) }
    }
    @Published public var autoEraseDelay: Double {
        didSet {
            let clamped = min(max(autoEraseDelay, 0.5), 60.0)
            if clamped != autoEraseDelay {
                autoEraseDelay = clamped
                return
            }
            persist(autoEraseDelay, forKey: Keys.autoEraseDelay)
        }
    }
    @Published public var showAnnotateControls: Bool {
        didSet { persist(showAnnotateControls, forKey: Keys.showAnnotateControls) }
    }
    @Published public var annotateControlsVertical: Bool {
        didSet { persist(annotateControlsVertical, forKey: Keys.annotateControlsVertical) }
    }
    @Published public var autoHideAnnotateControls: Bool {
        didSet { persist(autoHideAnnotateControls, forKey: Keys.autoHideAnnotateControls) }
    }
    @Published public var whiteboardEnabled: Bool {
        didSet { persist(whiteboardEnabled, forKey: Keys.whiteboardEnabled) }
    }
    @Published public var whiteboardColor: RGBColor {
        didSet { persistCodable(whiteboardColor, forKey: Keys.whiteboardColor) }
    }
    @Published public var whiteboardOpacity: Double {
        didSet { persist(min(max(whiteboardOpacity, 0.1), 1.0), forKey: Keys.whiteboardOpacity) }
    }
    @Published public var touchDrawEnabled: Bool {
        didSet { persist(touchDrawEnabled, forKey: Keys.touchDrawEnabled) }
    }
    @Published public var annotateToolIndicator: Bool {
        didSet { persist(annotateToolIndicator, forKey: Keys.annotateToolIndicator) }
    }
    @Published public var annotateFont: AnnotateFontOption {
        didSet { persistCodable(annotateFont, forKey: Keys.annotateFont) }
    }
    @Published public var annotateFontSize: Double {
        didSet { persist(min(max(annotateFontSize, 10.0), 96.0), forKey: Keys.annotateFontSize) }
    }
    @Published public var annotateTextPlaceholder: Bool {
        didSet { persist(annotateTextPlaceholder, forKey: Keys.annotateTextPlaceholder) }
    }
    @Published public var annotateSaveSession: Bool {
        didSet { persist(annotateSaveSession, forKey: Keys.annotateSaveSession) }
    }
    @Published public var screenshotSaveDirectoryPath: String {
        didSet { persist(screenshotSaveDirectoryPath, forKey: Keys.screenshotSaveDirectoryPath) }
    }
    @Published public var dimScreenOnAnnotate: Bool {
        didSet { persist(dimScreenOnAnnotate, forKey: Keys.dimScreenOnAnnotate) }
    }
    @Published public var dimScreenOpacity: Double {
        didSet { persist(min(max(dimScreenOpacity, 0.05), 0.95), forKey: Keys.dimScreenOpacity) }
    }

    @Published public var toastInteractiveMode: Bool {
        didSet { persist(toastInteractiveMode, forKey: Keys.toastInteractiveMode) }
    }
    @Published public var toastHighlightMode: Bool {
        didSet { persist(toastHighlightMode, forKey: Keys.toastHighlightMode) }
    }
    @Published public var toastTouchDraw: Bool {
        didSet { persist(toastTouchDraw, forKey: Keys.toastTouchDraw) }
    }
    @Published public var toastLineWeight: Bool {
        didSet { persist(toastLineWeight, forKey: Keys.toastLineWeight) }
    }

    @Published public var cursorHighlightShape: OverlayShape {
        didSet { persistCodable(cursorHighlightShape, forKey: Keys.cursorHighlightShape) }
    }
    @Published public var cursorHighlightSize: Double {
        didSet {
            let clamped = min(max(cursorHighlightSize, 20.0), 300.0)
            if clamped != cursorHighlightSize {
                cursorHighlightSize = clamped
                return
            }
            persist(cursorHighlightSize, forKey: Keys.cursorHighlightSize)
        }
    }
    @Published public var cursorHighlightColor: RGBColor {
        didSet { persistCodable(cursorHighlightColor, forKey: Keys.cursorHighlightColor) }
    }
    @Published public var cursorHighlightBorderStyle: CursorBorderStyle {
        didSet { persistCodable(cursorHighlightBorderStyle, forKey: Keys.cursorHighlightBorderStyle) }
    }
    @Published public var cursorHighlightBorderWidth: Double {
        didSet { persist(min(max(cursorHighlightBorderWidth, 0.0), 20.0), forKey: Keys.cursorHighlightBorderWidth) }
    }
    @Published public var cursorHighlightFillOpacity: Double {
        didSet { persist(min(max(cursorHighlightFillOpacity, 0.0), 1.0), forKey: Keys.cursorHighlightFillOpacity) }
    }
    @Published public var highlightGlow: Bool {
        didSet { persist(highlightGlow, forKey: Keys.highlightGlow) }
    }
    @Published public var cursorClickAnimation: CursorClickAnimation {
        didSet { persistCodable(cursorClickAnimation, forKey: Keys.cursorClickAnimation) }
    }
    @Published public var cursorClickHighlightColor: RGBColor {
        didSet { persistCodable(cursorClickHighlightColor, forKey: Keys.cursorClickHighlightColor) }
    }
    @Published public var highlightShowOnlyOnClick: Bool {
        didSet { persist(highlightShowOnlyOnClick, forKey: Keys.highlightShowOnlyOnClick) }
    }
    @Published public var autoHideCursorHighlightWhenIdle: Bool {
        didSet { persist(autoHideCursorHighlightWhenIdle, forKey: Keys.autoHideCursorHighlightWhenIdle) }
    }
    @Published public var cursorIdleTimeout: Double {
        didSet { persist(min(max(cursorIdleTimeout, 0.5), 30.0), forKey: Keys.cursorIdleTimeout) }
    }

    @Published public var spotlightShape: OverlayShape {
        didSet { persistCodable(spotlightShape, forKey: Keys.spotlightShape) }
    }
    @Published public var spotlightSize: Double {
        didSet {
            let clamped = min(max(spotlightSize, 40.0), 500.0)
            if clamped != spotlightSize {
                spotlightSize = clamped
                return
            }
            persist(spotlightSize, forKey: Keys.spotlightSize)
        }
    }
    @Published public var spotlightCurtainOpacity: Double {
        didSet { persist(min(max(spotlightCurtainOpacity, 0.1), 0.95), forKey: Keys.spotlightCurtainOpacity) }
    }
    @Published public var spotlightBorderWidth: Double {
        didSet { persist(min(max(spotlightBorderWidth, 0.0), 20.0), forKey: Keys.spotlightBorderWidth) }
    }
    @Published public var spotlightBorderColor: RGBColor {
        didSet { persistCodable(spotlightBorderColor, forKey: Keys.spotlightBorderColor) }
    }

    @Published public var zoomShape: OverlayShape {
        didSet { persistCodable(zoomShape, forKey: Keys.zoomShape) }
    }
    @Published public var zoomSize: Double {
        didSet {
            let clamped = min(max(zoomSize, 60.0), 600.0)
            if clamped != zoomSize {
                zoomSize = clamped
                return
            }
            persist(zoomSize, forKey: Keys.zoomSize)
        }
    }
    @Published public var zoomLevel: Double {
        didSet {
            let clamped = min(max(zoomLevel, 1.25), 5.0)
            if clamped != zoomLevel {
                zoomLevel = clamped
                return
            }
            persist(zoomLevel, forKey: Keys.zoomLevel)
        }
    }
    @Published public var zoomFullScreen: Bool {
        didSet { persist(zoomFullScreen, forKey: Keys.zoomFullScreen) }
    }
    @Published public var zoomDimBackground: Bool {
        didSet { persist(zoomDimBackground, forKey: Keys.zoomDimBackground) }
    }
    @Published public var zoomBorderWidth: Double {
        didSet { persist(min(max(zoomBorderWidth, 0.0), 20.0), forKey: Keys.zoomBorderWidth) }
    }
    @Published public var zoomBorderColor: RGBColor {
        didSet { persistCodable(zoomBorderColor, forKey: Keys.zoomBorderColor) }
    }

    @Published public var isAnnotating: Bool = false
    @Published public var isHighlightingCursor: Bool = false
    @Published public var isSpotlightingCursor: Bool = false
    @Published public var isZoomingCursor: Bool = false
    @Published public var isShowingShortcutsCheatsheet: Bool = false

    public var startAtLogin: Bool {
        get { launchAtLogin }
        set { launchAtLogin = newValue }
    }

    public var favoriteColors: [RGBColor] {
        get { favColors }
        set { favColors = newValue }
    }

    public var isWhiteboardActive: Bool {
        get { whiteboardEnabled }
        set { whiteboardEnabled = newValue }
    }

    public var annotateWhiteboardColor: RGBColor {
        get { whiteboardColor }
        set { whiteboardColor = newValue }
    }

    public var isTouchDrawActive: Bool {
        get { touchDrawEnabled }
        set { touchDrawEnabled = newValue }
    }

    public var annotateCursorCrosshair: Bool {
        get { annotateToolIndicator }
        set { annotateToolIndicator = newValue }
    }

    public var annotateTextFont: AnnotateFontOption {
        get { annotateFont }
        set { annotateFont = newValue }
    }

    public var annotateTextSize: Double {
        get { annotateFontSize }
        set { annotateFontSize = newValue }
    }

    public var annotateAutoErase: Bool {
        get { autoEraseEnabled }
        set { autoEraseEnabled = newValue }
    }

    public var annotateAutoEraseDelay: Double {
        get { autoEraseDelay }
        set { autoEraseDelay = newValue }
    }

    public var highlightShape: OverlayShape {
        get { cursorHighlightShape }
        set { cursorHighlightShape = newValue }
    }

    public var highlightColor: RGBColor {
        get { cursorHighlightColor }
        set { cursorHighlightColor = newValue }
    }

    public var highlightOpacity: Double {
        get { cursorHighlightFillOpacity }
        set { cursorHighlightFillOpacity = newValue }
    }

    public var highlightSize: Double {
        get { cursorHighlightSize }
        set { cursorHighlightSize = newValue }
    }

    public var highlightBorderStyle: CursorBorderStyle {
        get { cursorHighlightBorderStyle }
        set { cursorHighlightBorderStyle = newValue }
    }

    public var highlightClickAnimation: CursorClickAnimation {
        get { cursorClickAnimation }
        set { cursorClickAnimation = newValue }
    }

    public var highlightOffWhenInactive: Bool {
        get { autoHideCursorHighlightWhenIdle }
        set { autoHideCursorHighlightWhenIdle = newValue }
    }

    public var spotlightOpacity: Double {
        get { spotlightCurtainOpacity }
        set { spotlightCurtainOpacity = newValue }
    }

    public static var defaultScreenshotDirectory: String {
        NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
    }

    public init(defaults: UserDefaults = UserDefaults(suiteName: AppSettings.defaultSuiteName) ?? .standard) {
        self.defaults = defaults

        let minWeight = Self.loadDouble(from: defaults, key: Keys.minLineWeight, fallback: 2.0)
        let maxWeight = Self.loadDouble(from: defaults, key: Keys.maxLineWeight, fallback: 24.0)

        self.launchAtLogin = Self.loadBool(from: defaults, key: Keys.launchAtLogin, fallback: false)
        self.highlightCursorAtLogin = Self.loadBool(from: defaults, key: Keys.highlightCursorAtLogin, fallback: false)
        self.showMenuBarIcon = Self.loadBool(from: defaults, key: Keys.showMenuBarIcon, fallback: true)
        self.showDockIcon = Self.loadBool(from: defaults, key: Keys.showDockIcon, fallback: false)
        self.autoCheckUpdates = Self.loadBool(from: defaults, key: Keys.autoCheckUpdates, fallback: true)
        self.automaticallyCheckForUpdates = Self.loadBool(from: defaults, key: Keys.automaticallyCheckForUpdates, fallback: true)
        self.skippedUpdateVersion = Self.loadString(from: defaults, key: Keys.skippedUpdateVersion, fallback: "")
        self.hasCompletedWelcomeTour = Self.loadBool(from: defaults, key: Keys.hasCompletedWelcomeTour, fallback: false)
        self.interactiveModeKey = Self.loadCodable(from: defaults, key: Keys.interactiveModeKey, fallback: .fn)
        self.annotateInteractiveMode = Self.loadBool(from: defaults, key: Keys.annotateInteractiveMode, fallback: false)
        self.selectedSettingsTab = Self.loadCodable(from: defaults, key: Keys.selectedSettingsTab, fallback: .general)

        self.favColors = Self.loadCodable(from: defaults, key: Keys.favColors, fallback: Self.defaultFavColors)
        self.selectedColorIndex = Self.loadInt(from: defaults, key: Keys.selectedColorIndex, fallback: 0)
        self.useRandomColors = Self.loadBool(from: defaults, key: Keys.useRandomColors, fallback: false)
        self.enableGradients = Self.loadBool(from: defaults, key: Keys.enableGradients, fallback: false)
        self.activeGradient = Self.loadCodable(from: defaults, key: Keys.activeGradient, fallback: GradientGenerator.presets[0])
        self.currentDrawMode = Self.loadCodable(from: defaults, key: Keys.currentDrawMode, fallback: .freeHand)
        self.minLineWeight = minWeight
        self.maxLineWeight = maxWeight
        self.lineWeight = min(max(Self.loadDouble(from: defaults, key: Keys.lineWeight, fallback: 6.0), minWeight), maxWeight)
        self.autoEraseEnabled = Self.loadBool(from: defaults, key: Keys.autoEraseEnabled, fallback: false)
        self.autoEraseDelay = Self.loadDouble(from: defaults, key: Keys.autoEraseDelay, fallback: 3.0)
        self.showAnnotateControls = Self.loadBool(from: defaults, key: Keys.showAnnotateControls, fallback: true)
        self.annotateControlsVertical = Self.loadBool(from: defaults, key: Keys.annotateControlsVertical, fallback: false)
        self.autoHideAnnotateControls = Self.loadBool(from: defaults, key: Keys.autoHideAnnotateControls, fallback: false)
        self.whiteboardEnabled = Self.loadBool(from: defaults, key: Keys.whiteboardEnabled, fallback: false)
        self.whiteboardColor = Self.loadCodable(from: defaults, key: Keys.whiteboardColor, fallback: RGBColor(red: 0.12, green: 0.12, blue: 0.14))
        self.whiteboardOpacity = Self.loadDouble(from: defaults, key: Keys.whiteboardOpacity, fallback: 1.0)
        self.touchDrawEnabled = Self.loadBool(from: defaults, key: Keys.touchDrawEnabled, fallback: false)
        self.annotateToolIndicator = Self.loadBool(from: defaults, key: Keys.annotateToolIndicator, fallback: true)
        self.annotateFont = Self.loadCodable(from: defaults, key: Keys.annotateFont, fallback: .systemDefault)
        self.annotateFontSize = Self.loadDouble(from: defaults, key: Keys.annotateFontSize, fallback: 24.0)
        self.annotateTextPlaceholder = Self.loadBool(from: defaults, key: Keys.annotateTextPlaceholder, fallback: true)
        self.annotateSaveSession = Self.loadBool(from: defaults, key: Keys.annotateSaveSession, fallback: false)
        self.screenshotSaveDirectoryPath = Self.loadString(
            from: defaults,
            key: Keys.screenshotSaveDirectoryPath,
            fallback: Self.defaultScreenshotDirectory
        )
        self.dimScreenOnAnnotate = Self.loadBool(from: defaults, key: Keys.dimScreenOnAnnotate, fallback: false)
        self.dimScreenOpacity = Self.loadDouble(from: defaults, key: Keys.dimScreenOpacity, fallback: 0.35)

        self.toastInteractiveMode = Self.loadBool(from: defaults, key: Keys.toastInteractiveMode, fallback: true)
        self.toastHighlightMode = Self.loadBool(from: defaults, key: Keys.toastHighlightMode, fallback: true)
        self.toastTouchDraw = Self.loadBool(from: defaults, key: Keys.toastTouchDraw, fallback: true)
        self.toastLineWeight = Self.loadBool(from: defaults, key: Keys.toastLineWeight, fallback: true)

        self.cursorHighlightShape = Self.loadCodable(from: defaults, key: Keys.cursorHighlightShape, fallback: .circle)
        self.cursorHighlightSize = Self.loadDouble(from: defaults, key: Keys.cursorHighlightSize, fallback: 60.0)
        self.cursorHighlightColor = Self.loadCodable(from: defaults, key: Keys.cursorHighlightColor, fallback: .yellow)
        self.cursorHighlightBorderStyle = Self.loadCodable(from: defaults, key: Keys.cursorHighlightBorderStyle, fallback: .solid)
        self.cursorHighlightBorderWidth = Self.loadDouble(from: defaults, key: Keys.cursorHighlightBorderWidth, fallback: 3.0)
        self.cursorHighlightFillOpacity = Self.loadDouble(from: defaults, key: Keys.cursorHighlightFillOpacity, fallback: 0.25)
        self.highlightGlow = Self.loadBool(from: defaults, key: Keys.highlightGlow, fallback: true)
        self.cursorClickAnimation = Self.loadCodable(from: defaults, key: Keys.cursorClickAnimation, fallback: .scale)
        self.cursorClickHighlightColor = Self.loadCodable(from: defaults, key: Keys.cursorClickHighlightColor, fallback: .pink)
        self.highlightShowOnlyOnClick = Self.loadBool(from: defaults, key: Keys.highlightShowOnlyOnClick, fallback: false)
        self.autoHideCursorHighlightWhenIdle = Self.loadBool(from: defaults, key: Keys.autoHideCursorHighlightWhenIdle, fallback: true)
        self.cursorIdleTimeout = Self.loadDouble(from: defaults, key: Keys.cursorIdleTimeout, fallback: 2.0)

        self.spotlightShape = Self.loadCodable(from: defaults, key: Keys.spotlightShape, fallback: .circle)
        self.spotlightSize = Self.loadDouble(from: defaults, key: Keys.spotlightSize, fallback: 140.0)
        self.spotlightCurtainOpacity = Self.loadDouble(from: defaults, key: Keys.spotlightCurtainOpacity, fallback: 0.65)
        self.spotlightBorderWidth = Self.loadDouble(from: defaults, key: Keys.spotlightBorderWidth, fallback: 2.0)
        self.spotlightBorderColor = Self.loadCodable(from: defaults, key: Keys.spotlightBorderColor, fallback: .white)

        self.zoomShape = Self.loadCodable(from: defaults, key: Keys.zoomShape, fallback: .circle)
        self.zoomSize = Self.loadDouble(from: defaults, key: Keys.zoomSize, fallback: 180.0)
        self.zoomLevel = Self.loadDouble(from: defaults, key: Keys.zoomLevel, fallback: 2.0)
        self.zoomFullScreen = Self.loadBool(from: defaults, key: Keys.zoomFullScreen, fallback: false)
        self.zoomDimBackground = Self.loadBool(from: defaults, key: Keys.zoomDimBackground, fallback: false)
        self.zoomBorderWidth = Self.loadDouble(from: defaults, key: Keys.zoomBorderWidth, fallback: 3.0)
        self.zoomBorderColor = Self.loadCodable(from: defaults, key: Keys.zoomBorderColor, fallback: .white)
    }

    public var activeStrokeColor: RGBColor {
        if useRandomColors {
            return GradientGenerator.randomVividColor()
        }
        guard !favColors.isEmpty else { return .red }
        let safeIndex = min(max(selectedColorIndex, 0), favColors.count - 1)
        return favColors[safeIndex]
    }

    public var activeStrokeGradient: GradientPair? {
        guard enableGradients else { return nil }
        if useRandomColors {
            return GradientGenerator.randomVividGradient()
        }
        return activeGradient
    }

    public func selectFavoriteColor(index: Int) {
        guard index >= 0 && index < favColors.count else { return }
        useRandomColors = false
        selectedColorIndex = index
    }

    public func selectRandomColors() {
        useRandomColors = true
        if enableGradients {
            activeGradient = GradientGenerator.randomVividGradient()
        }
    }

    public func selectOrToggleDrawMode(_ mode: DrawMode) {
        if mode == .highlighter {
            if currentDrawMode == .highlighter {
                currentDrawMode = .freeHand
            } else {
                currentDrawMode = .highlighter
            }
        } else {
            currentDrawMode = mode
        }
    }

    public func increaseLineWeight(step: Double = 2.0) {
        lineWeight = min(maxLineWeight, lineWeight + step)
    }

    public func decreaseLineWeight(step: Double = 2.0) {
        lineWeight = max(minLineWeight, lineWeight - step)
    }

    public func setLineWeightFromDigit(_ digit: Int) {
        let clampedDigit = min(max(digit, 1), 9)
        let fraction = Double(clampedDigit - 1) / 8.0
        let computed = minLineWeight + fraction * (maxLineWeight - minLineWeight)
        lineWeight = (computed * 10.0).rounded() / 10.0
    }

    public func setLineWeight(fromDigit digit: Int) {
        setLineWeightFromDigit(digit)
    }

    public func increaseCursorSize(step: Double = 10.0) {
        cursorHighlightSize = min(300.0, cursorHighlightSize + step)
        spotlightSize = min(500.0, spotlightSize + step)
        zoomSize = min(600.0, zoomSize + step)
    }

    public func decreaseCursorSize(step: Double = 10.0) {
        cursorHighlightSize = max(20.0, cursorHighlightSize - step)
        spotlightSize = max(40.0, spotlightSize - step)
        zoomSize = max(60.0, zoomSize - step)
    }

    public func increaseZoomLevel(step: Double = 0.25) {
        zoomLevel = min(5.0, zoomLevel + step)
    }

    public func decreaseZoomLevel(step: Double = 0.25) {
        zoomLevel = max(1.25, zoomLevel - step)
    }

    public func restoreDefaults() {
        isRestoring = true
        for key in Keys.all {
            defaults.removeObject(forKey: key)
        }
        isRestoring = false

        launchAtLogin = false
        highlightCursorAtLogin = false
        showMenuBarIcon = true
        showDockIcon = false
        autoCheckUpdates = true
        automaticallyCheckForUpdates = true
        skippedUpdateVersion = ""
        hasCompletedWelcomeTour = false
        interactiveModeKey = .fn
        annotateInteractiveMode = false
        selectedSettingsTab = .general

        favColors = Self.defaultFavColors
        selectedColorIndex = 0
        useRandomColors = false
        enableGradients = false
        activeGradient = GradientGenerator.presets[0]
        currentDrawMode = .freeHand
        minLineWeight = 2.0
        maxLineWeight = 24.0
        lineWeight = 6.0
        autoEraseEnabled = false
        autoEraseDelay = 3.0
        showAnnotateControls = true
        annotateControlsVertical = false
        autoHideAnnotateControls = false
        whiteboardEnabled = false
        whiteboardColor = RGBColor(red: 0.12, green: 0.12, blue: 0.14)
        whiteboardOpacity = 1.0
        touchDrawEnabled = false
        annotateToolIndicator = true
        annotateFont = .systemDefault
        annotateFontSize = 24.0
        annotateTextPlaceholder = true
        annotateSaveSession = false
        screenshotSaveDirectoryPath = Self.defaultScreenshotDirectory
        dimScreenOnAnnotate = false
        dimScreenOpacity = 0.35

        toastInteractiveMode = true
        toastHighlightMode = true
        toastTouchDraw = true
        toastLineWeight = true

        cursorHighlightShape = .circle
        cursorHighlightSize = 60.0
        cursorHighlightColor = .yellow
        cursorHighlightBorderStyle = .solid
        cursorHighlightBorderWidth = 3.0
        cursorHighlightFillOpacity = 0.25
        highlightGlow = true
        cursorClickAnimation = .scale
        cursorClickHighlightColor = .pink
        highlightShowOnlyOnClick = false
        autoHideCursorHighlightWhenIdle = true
        cursorIdleTimeout = 2.0

        spotlightShape = .circle
        spotlightSize = 140.0
        spotlightCurtainOpacity = 0.65
        spotlightBorderWidth = 2.0
        spotlightBorderColor = .white

        zoomShape = .circle
        zoomSize = 180.0
        zoomLevel = 2.0
        zoomFullScreen = false
        zoomDimBackground = false
        zoomBorderWidth = 3.0
        zoomBorderColor = .white

        isAnnotating = false
        isHighlightingCursor = false
        isSpotlightingCursor = false
        isZoomingCursor = false
        isShowingShortcutsCheatsheet = false
    }

    private func updateLoginItemIfNeeded(_ enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    private func persist(_ value: Any, forKey key: String) {
        guard !isRestoring else { return }
        defaults.set(value, forKey: key)
    }

    private func persistCodable<T: Encodable>(_ value: T, forKey key: String) {
        guard !isRestoring, let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadBool(from defaults: UserDefaults, key: String, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.bool(forKey: key)
    }

    private static func loadInt(from defaults: UserDefaults, key: String, fallback: Int) -> Int {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.integer(forKey: key)
    }

    private static func loadDouble(from defaults: UserDefaults, key: String, fallback: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.double(forKey: key)
    }

    private static func loadString(from defaults: UserDefaults, key: String, fallback: String) -> String {
        defaults.string(forKey: key) ?? fallback
    }

    private static func loadCodable<T: Decodable>(from defaults: UserDefaults, key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return fallback
        }
        return decoded
    }

    private enum Keys {
        static let launchAtLogin = "presentify.launchAtLogin"
        static let highlightCursorAtLogin = "presentify.highlightCursorAtLogin"
        static let showMenuBarIcon = "presentify.showMenuBarIcon"
        static let showDockIcon = "presentify.showDockIcon"
        static let autoCheckUpdates = "presentify.autoCheckUpdates"
        static let automaticallyCheckForUpdates = "presentify.automaticallyCheckForUpdates"
        static let skippedUpdateVersion = "presentify.skippedUpdateVersion"
        static let hasCompletedWelcomeTour = "presentify.hasCompletedWelcomeTour"
        static let interactiveModeKey = "presentify.interactiveModeKey"
        static let annotateInteractiveMode = "presentify.annotateInteractiveMode"
        static let selectedSettingsTab = "presentify.selectedSettingsTab"
        static let favColors = "presentify.favColors"
        static let selectedColorIndex = "presentify.selectedColorIndex"
        static let useRandomColors = "presentify.useRandomColors"
        static let enableGradients = "presentify.enableGradients"
        static let activeGradient = "presentify.activeGradient"
        static let currentDrawMode = "presentify.currentDrawMode"
        static let minLineWeight = "presentify.minLineWeight"
        static let maxLineWeight = "presentify.maxLineWeight"
        static let lineWeight = "presentify.lineWeight"
        static let autoEraseEnabled = "presentify.autoEraseEnabled"
        static let autoEraseDelay = "presentify.autoEraseDelay"
        static let showAnnotateControls = "presentify.showAnnotateControls"
        static let annotateControlsVertical = "presentify.annotateControlsVertical"
        static let autoHideAnnotateControls = "presentify.autoHideAnnotateControls"
        static let whiteboardEnabled = "presentify.whiteboardEnabled"
        static let whiteboardColor = "presentify.whiteboardColor"
        static let whiteboardOpacity = "presentify.whiteboardOpacity"
        static let touchDrawEnabled = "presentify.touchDrawEnabled"
        static let annotateToolIndicator = "presentify.annotateToolIndicator"
        static let annotateFont = "presentify.annotateFont"
        static let annotateFontSize = "presentify.annotateFontSize"
        static let annotateTextPlaceholder = "presentify.annotateTextPlaceholder"
        static let annotateSaveSession = "presentify.annotateSaveSession"
        static let screenshotSaveDirectoryPath = "presentify.screenshotSaveDirectoryPath"
        static let dimScreenOnAnnotate = "presentify.dimScreenOnAnnotate"
        static let dimScreenOpacity = "presentify.dimScreenOpacity"
        static let toastInteractiveMode = "presentify.toastInteractiveMode"
        static let toastHighlightMode = "presentify.toastHighlightMode"
        static let toastTouchDraw = "presentify.toastTouchDraw"
        static let toastLineWeight = "presentify.toastLineWeight"
        static let cursorHighlightShape = "presentify.cursorHighlightShape"
        static let cursorHighlightSize = "presentify.cursorHighlightSize"
        static let cursorHighlightColor = "presentify.cursorHighlightColor"
        static let cursorHighlightBorderStyle = "presentify.cursorHighlightBorderStyle"
        static let cursorHighlightBorderWidth = "presentify.cursorHighlightBorderWidth"
        static let cursorHighlightFillOpacity = "presentify.cursorHighlightFillOpacity"
        static let highlightGlow = "presentify.highlightGlow"
        static let cursorClickAnimation = "presentify.cursorClickAnimation"
        static let cursorClickHighlightColor = "presentify.cursorClickHighlightColor"
        static let highlightShowOnlyOnClick = "presentify.highlightShowOnlyOnClick"
        static let autoHideCursorHighlightWhenIdle = "presentify.autoHideCursorHighlightWhenIdle"
        static let cursorIdleTimeout = "presentify.cursorIdleTimeout"
        static let spotlightShape = "presentify.spotlightShape"
        static let spotlightSize = "presentify.spotlightSize"
        static let spotlightCurtainOpacity = "presentify.spotlightCurtainOpacity"
        static let spotlightBorderWidth = "presentify.spotlightBorderWidth"
        static let spotlightBorderColor = "presentify.spotlightBorderColor"
        static let zoomShape = "presentify.zoomShape"
        static let zoomSize = "presentify.zoomSize"
        static let zoomLevel = "presentify.zoomLevel"
        static let zoomFullScreen = "presentify.zoomFullScreen"
        static let zoomDimBackground = "presentify.zoomDimBackground"
        static let zoomBorderWidth = "presentify.zoomBorderWidth"
        static let zoomBorderColor = "presentify.zoomBorderColor"

        static let all: [String] = [
            launchAtLogin, highlightCursorAtLogin, showMenuBarIcon, showDockIcon,
            autoCheckUpdates, automaticallyCheckForUpdates, skippedUpdateVersion,
            hasCompletedWelcomeTour, interactiveModeKey,
            annotateInteractiveMode, selectedSettingsTab, favColors,
            selectedColorIndex, useRandomColors, enableGradients, activeGradient,
            currentDrawMode, minLineWeight, maxLineWeight, lineWeight,
            autoEraseEnabled, autoEraseDelay, showAnnotateControls,
            annotateControlsVertical, autoHideAnnotateControls, whiteboardEnabled,
            whiteboardColor, whiteboardOpacity, touchDrawEnabled,
            annotateToolIndicator, annotateFont, annotateFontSize,
            annotateTextPlaceholder, annotateSaveSession,
            screenshotSaveDirectoryPath, dimScreenOnAnnotate, dimScreenOpacity,
            toastInteractiveMode, toastHighlightMode, toastTouchDraw,
            toastLineWeight, cursorHighlightShape, cursorHighlightSize,
            cursorHighlightColor, cursorHighlightBorderStyle,
            cursorHighlightBorderWidth, cursorHighlightFillOpacity, highlightGlow,
            cursorClickAnimation, cursorClickHighlightColor,
            highlightShowOnlyOnClick, autoHideCursorHighlightWhenIdle,
            cursorIdleTimeout, spotlightShape, spotlightSize,
            spotlightCurtainOpacity, spotlightBorderWidth, spotlightBorderColor,
            zoomShape, zoomSize, zoomLevel, zoomFullScreen, zoomDimBackground,
            zoomBorderWidth, zoomBorderColor
        ]
    }
}
