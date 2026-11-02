import AppKit
import Carbon
import Combine
import Foundation

public enum ShortcutCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case global
    case annotate
    case cursor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .global: return "Global Shortcuts"
        case .annotate: return "Annotate Screen Shortcuts"
        case .cursor: return "Highlight & Zoom Cursor Shortcuts"
        }
    }

    public var commands: [ShortcutCommand] {
        ShortcutCommand.allCases.filter { $0.category == self }
    }
}

public enum ShortcutCommand: String, CaseIterable, Codable, Identifiable, Sendable {
    case toggleAnnotateScreen
    case toggleAnnotateControls
    case toggleHighlightCursor
    case toggleSpotlightCursor
    case toggleZoomCursor

    case firstFavColor
    case secondFavColor
    case thirdFavColor
    case fourthFavColor
    case fifthFavColor
    case randomColors
    case freeHand
    case arrow
    case rectangle
    case circle
    case text
    case clearAnnotate
    case highlighter
    case blur
    case decreaseLineWeight
    case increaseLineWeight
    case setLineWeight
    case touchDraw
    case annotateWhiteboard
    case saveScreenshot
    case copyScreenshot
    case pasteAnnotations
    case annotateShortcuts

    case decreaseCursorSize
    case increaseCursorSize
    case decreaseZoomLevel
    case increaseZoomLevel
    case toggleZoomFullScreen

    public var id: String { rawValue }

    public var category: ShortcutCategory {
        switch self {
        case .toggleAnnotateScreen,
             .toggleAnnotateControls,
             .toggleHighlightCursor,
             .toggleSpotlightCursor,
             .toggleZoomCursor:
            return .global
        case .firstFavColor,
             .secondFavColor,
             .thirdFavColor,
             .fourthFavColor,
             .fifthFavColor,
             .randomColors,
             .freeHand,
             .arrow,
             .rectangle,
             .circle,
             .text,
             .clearAnnotate,
             .highlighter,
             .blur,
             .decreaseLineWeight,
             .increaseLineWeight,
             .setLineWeight,
             .touchDraw,
             .annotateWhiteboard,
             .saveScreenshot,
             .copyScreenshot,
             .pasteAnnotations,
             .annotateShortcuts:
            return .annotate
        case .decreaseCursorSize,
             .increaseCursorSize,
             .decreaseZoomLevel,
             .increaseZoomLevel,
             .toggleZoomFullScreen:
            return .cursor
        }
    }

    public var title: String {
        switch self {
        case .toggleAnnotateScreen: return "Toggle Annotate Screen"
        case .toggleAnnotateControls: return "Toggle Annotate Controls"
        case .toggleHighlightCursor: return "Toggle Highlight Cursor"
        case .toggleSpotlightCursor: return "Toggle Spotlight Cursor"
        case .toggleZoomCursor: return "Toggle Zoom Cursor"
        case .firstFavColor: return "First Fav Color"
        case .secondFavColor: return "Second Fav Color"
        case .thirdFavColor: return "Third Fav Color"
        case .fourthFavColor: return "Fourth Fav Color"
        case .fifthFavColor: return "Fifth Fav Color"
        case .randomColors: return "Random Colors / Gradients"
        case .freeHand: return "Free Hand"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .text: return "Text"
        case .clearAnnotate: return "Clear Annotations"
        case .highlighter: return "Highlighter"
        case .blur: return "Blur"
        case .decreaseLineWeight: return "Decrease Line Weight"
        case .increaseLineWeight: return "Increase Line Weight"
        case .setLineWeight: return "Set Line Weight (1-9)"
        case .touchDraw: return "Touch Draw"
        case .annotateWhiteboard: return "Annotate Whiteboard"
        case .saveScreenshot: return "Save Screenshot"
        case .copyScreenshot: return "Copy Screenshot / Selection"
        case .pasteAnnotations: return "Paste Annotations"
        case .annotateShortcuts: return "Annotate Shortcuts Cheatsheet"
        case .decreaseCursorSize: return "Decrease Cursor Size"
        case .increaseCursorSize: return "Increase Cursor Size"
        case .decreaseZoomLevel: return "Decrease Zoom Level"
        case .increaseZoomLevel: return "Increase Zoom Level"
        case .toggleZoomFullScreen: return "Toggle Zoom Full Screen"
        }
    }

    public var defaultBinding: KeyBinding {
        let ctrlOpt = KeyBinding.controlMask | KeyBinding.optionMask
        let cmd = KeyBinding.commandMask
        let opt = KeyBinding.optionMask

        switch self {
        case .toggleAnnotateScreen: return KeyBinding(keyCode: 0x00, modifiers: ctrlOpt)
        case .toggleAnnotateControls: return KeyBinding(keyCode: 0x0D, modifiers: ctrlOpt)
        case .toggleHighlightCursor: return KeyBinding(keyCode: 0x04, modifiers: ctrlOpt)
        case .toggleSpotlightCursor: return KeyBinding(keyCode: 0x01, modifiers: ctrlOpt)
        case .toggleZoomCursor: return KeyBinding(keyCode: 0x06, modifiers: ctrlOpt)

        case .firstFavColor: return KeyBinding(keyCode: 0x12, modifiers: 0)
        case .secondFavColor: return KeyBinding(keyCode: 0x13, modifiers: 0)
        case .thirdFavColor: return KeyBinding(keyCode: 0x14, modifiers: 0)
        case .fourthFavColor: return KeyBinding(keyCode: 0x15, modifiers: 0)
        case .fifthFavColor: return KeyBinding(keyCode: 0x17, modifiers: 0)
        case .randomColors: return KeyBinding(keyCode: 0x16, modifiers: 0)
        case .freeHand: return KeyBinding(keyCode: 0x03, modifiers: 0)
        case .arrow: return KeyBinding(keyCode: 0x00, modifiers: 0)
        case .rectangle: return KeyBinding(keyCode: 0x0F, modifiers: 0)
        case .circle: return KeyBinding(keyCode: 0x08, modifiers: 0)
        case .text: return KeyBinding(keyCode: 0x11, modifiers: 0)
        case .clearAnnotate: return KeyBinding(keyCode: 0x33, modifiers: 0)
        case .highlighter: return KeyBinding(keyCode: 0x04, modifiers: 0)
        case .blur: return KeyBinding(keyCode: 0x0B, modifiers: 0)
        case .decreaseLineWeight: return KeyBinding(keyCode: 0x21, modifiers: 0)
        case .increaseLineWeight: return KeyBinding(keyCode: 0x1E, modifiers: 0)
        case .setLineWeight: return KeyBinding(keyCode: 0x12, modifiers: ctrlOpt)
        case .touchDraw: return KeyBinding(keyCode: 0x02, modifiers: 0)
        case .annotateWhiteboard: return KeyBinding(keyCode: 0x0D, modifiers: 0)
        case .saveScreenshot: return KeyBinding(keyCode: 0x01, modifiers: 0)
        case .copyScreenshot: return KeyBinding(keyCode: 0x08, modifiers: cmd)
        case .pasteAnnotations: return KeyBinding(keyCode: 0x09, modifiers: cmd)
        case .annotateShortcuts: return KeyBinding(keyCode: 0x2C, modifiers: 0)

        case .decreaseCursorSize: return KeyBinding(keyCode: 0x1B, modifiers: 0)
        case .increaseCursorSize: return KeyBinding(keyCode: 0x18, modifiers: 0)
        case .decreaseZoomLevel: return KeyBinding(keyCode: 0x1B, modifiers: opt)
        case .increaseZoomLevel: return KeyBinding(keyCode: 0x18, modifiers: opt)
        case .toggleZoomFullScreen: return KeyBinding(keyCode: 0x1D, modifiers: opt)
        }
    }
}

public struct KeyBinding: Codable, Equatable, Hashable, Sendable {
    public static let shiftMask: UInt = NSEvent.ModifierFlags.shift.rawValue
    public static let controlMask: UInt = NSEvent.ModifierFlags.control.rawValue
    public static let optionMask: UInt = NSEvent.ModifierFlags.option.rawValue
    public static let commandMask: UInt = NSEvent.ModifierFlags.command.rawValue
    public static let relevantModifiersMask: UInt = shiftMask | controlMask | optionMask | commandMask

    public var keyCode: UInt16
    public var modifiers: UInt

    public init(keyCode: UInt16, modifiers: UInt = 0) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.relevantModifiersMask
    }

    public init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        self.init(keyCode: keyCode, modifiers: flags.rawValue)
    }

    public var displayString: String {
        var result = ""
        if (modifiers & Self.controlMask) != 0 { result += "⌃" }
        if (modifiers & Self.optionMask) != 0 { result += "⌥" }
        if (modifiers & Self.shiftMask) != 0 { result += "⇧" }
        if (modifiers & Self.commandMask) != 0 { result += "⌘" }
        result += Self.keySymbol(for: keyCode)
        return result
    }

    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if (modifiers & Self.controlMask) != 0 { mask |= UInt32(controlKey) }
        if (modifiers & Self.optionMask) != 0 { mask |= UInt32(optionKey) }
        if (modifiers & Self.shiftMask) != 0 { mask |= UInt32(shiftKey) }
        if (modifiers & Self.commandMask) != 0 { mask |= UInt32(cmdKey) }
        return mask
    }

    public static func digitForKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 0x1D: return 0
        case 0x12: return 1
        case 0x13: return 2
        case 0x14: return 3
        case 0x15: return 4
        case 0x17: return 5
        case 0x16: return 6
        case 0x1A: return 7
        case 0x1C: return 8
        case 0x19: return 9
        default: return nil
        }
    }

    public static func keySymbol(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x24: return "Return"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "\\"
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x30: return "Tab"
        case 0x31: return "Space"
        case 0x32: return "`"
        case 0x33: return "Delete"
        case 0x35: return "Esc"
        case 0x75: return "Forward Delete"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7D: return "↓"
        case 0x7E: return "↑"
        default: return String(format: "Key(0x%02X)", keyCode)
        }
    }
}

public final class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()
    private static let storageKey = "presentify.customShortcutBindings"
    private static let hotKeySignature: OSType = 0x5052_5354

    @Published public private(set) var bindings: [ShortcutCommand: KeyBinding]
    public var onGlobalCommand: ((ShortcutCommand) -> Void)?

    private let defaults: UserDefaults
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotKeyCommands: [UInt32: ShortcutCommand] = [:]
    private var eventHandlerRef: EventHandlerRef?

    public init(defaults: UserDefaults = UserDefaults(suiteName: AppSettings.defaultSuiteName) ?? .standard) {
        self.defaults = defaults
        var initial: [ShortcutCommand: KeyBinding] = [:]
        for command in ShortcutCommand.allCases {
            initial[command] = command.defaultBinding
        }

        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([String: KeyBinding].self, from: data) {
            for (rawKey, binding) in stored {
                if let command = ShortcutCommand(rawValue: rawKey) {
                    initial[command] = binding
                }
            }
        }
        self.bindings = initial
    }

    deinit {
        unregisterGlobalHotKeys()
    }

    public func binding(for command: ShortcutCommand) -> KeyBinding {
        bindings[command] ?? command.defaultBinding
    }

    public func setBinding(_ newBinding: KeyBinding, for command: ShortcutCommand) {
        bindings[command] = newBinding
        saveBindings()
        if command.category == .global && !hotKeyRefs.isEmpty {
            registerGlobalHotKeys()
        }
    }

    public func resetToDefault(for command: ShortcutCommand) {
        bindings[command] = command.defaultBinding
        saveBindings()
        if command.category == .global && !hotKeyRefs.isEmpty {
            registerGlobalHotKeys()
        }
    }

    public func resetAllToDefaults() {
        var resetMap: [ShortcutCommand: KeyBinding] = [:]
        for command in ShortcutCommand.allCases {
            resetMap[command] = command.defaultBinding
        }
        bindings = resetMap
        defaults.removeObject(forKey: Self.storageKey)
        if !hotKeyRefs.isEmpty {
            registerGlobalHotKeys()
        }
    }

    public func matchGlobalCommand(keyCode: UInt16, modifiers: UInt) -> ShortcutCommand? {
        let normalizedModifiers = modifiers & KeyBinding.relevantModifiersMask
        for command in ShortcutCategory.global.commands {
            let bound = binding(for: command)
            if bound.keyCode == keyCode && bound.modifiers == normalizedModifiers {
                return command
            }
        }
        return nil
    }

    public func matchLocalAnnotateCommand(keyCode: UInt16, modifiers: UInt) -> (command: ShortcutCommand, lineWeightDigit: Int?)? {
        let normalizedModifiers = modifiers & KeyBinding.relevantModifiersMask
        let setWeightModifiers = binding(for: .setLineWeight).modifiers

        if normalizedModifiers == setWeightModifiers,
           let digit = KeyBinding.digitForKeyCode(keyCode),
           (1...9).contains(digit) {
            return (.setLineWeight, digit)
        }

        for command in ShortcutCategory.annotate.commands where command != .setLineWeight {
            let bound = binding(for: command)
            if bound.keyCode == keyCode && bound.modifiers == normalizedModifiers {
                return (command, nil)
            }
        }
        return nil
    }

    public func matchCursorCommand(keyCode: UInt16, modifiers: UInt, isZoomActive: Bool = true) -> ShortcutCommand? {
        let normalizedModifiers = modifiers & KeyBinding.relevantModifiersMask
        for command in ShortcutCategory.cursor.commands {
            let isZoomOnlyCommand = (command == .decreaseZoomLevel || command == .increaseZoomLevel || command == .toggleZoomFullScreen)
            if isZoomOnlyCommand && !isZoomActive {
                continue
            }
            let bound = binding(for: command)
            if bound.keyCode == keyCode && bound.modifiers == normalizedModifiers {
                return command
            }
        }
        return nil
    }

    public func registerGlobalHotKeys() {
        unregisterGlobalHotKeys()

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerCallback: EventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr,
               hotKeyID.signature == ShortcutManager.hotKeySignature,
               let command = manager.hotKeyCommands[hotKeyID.id] {
                manager.onGlobalCommand?(command)
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventSpec,
            selfPointer,
            &eventHandlerRef
        )

        var nextID: UInt32 = 1
        for command in ShortcutCategory.global.commands {
            let bound = binding(for: command)
            let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: nextID)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(bound.keyCode),
                bound.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                hotKeyRefs[nextID] = ref
                hotKeyCommands[nextID] = command
            }
            nextID += 1
        }
    }

    public func unregisterGlobalHotKeys() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        hotKeyCommands.removeAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    private func saveBindings() {
        var rawDict: [String: KeyBinding] = [:]
        for (command, binding) in bindings {
            rawDict[command.rawValue] = binding
        }
        if let data = try? JSONEncoder().encode(rawDict) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
