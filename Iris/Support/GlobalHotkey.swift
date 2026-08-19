//
//  GlobalHotkey.swift
//  Iris
//
//  One user-configurable global shortcut that starts a break immediately.
//
//  Carbon's RegisterEventHotKey rather than an NSEvent global monitor, for two
//  reasons: it does not need Accessibility permission, and it tells you when the
//  combination is already taken instead of silently never firing. A shortcut
//  that quietly does nothing is worse than one that says it is unavailable.
//
//  No new dependency. Carbon.HIToolbox ships with the OS.
//

import AppKit
import Carbon.HIToolbox

// MARK: - A combination

struct HotkeyCombo: Equatable, Codable {
    /// Virtual key code, as Carbon and NSEvent both understand it.
    var keyCode: UInt32
    /// Cocoa modifier flags, stored raw so the value survives in defaults.
    var modifierFlags: UInt

    static let optionCommandB = HotkeyCombo(
        keyCode: UInt32(kVK_ANSI_B),
        modifierFlags: NSEvent.ModifierFlags([.option, .command]).rawValue
    )

    var cocoaModifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    /// Carbon wants its own bitfield.
    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if cocoaModifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if cocoaModifiers.contains(.option)  { flags |= UInt32(optionKey) }
        if cocoaModifiers.contains(.control) { flags |= UInt32(controlKey) }
        if cocoaModifiers.contains(.shift)   { flags |= UInt32(shiftKey) }
        return flags
    }

    /// How the shortcut reads in settings, in the usual Mac order.
    var displayString: String {
        var text = ""
        if cocoaModifiers.contains(.control) { text += "⌃" }
        if cocoaModifiers.contains(.option)  { text += "⌥" }
        if cocoaModifiers.contains(.shift)   { text += "⇧" }
        if cocoaModifiers.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    /// At least one of command, option or control, or the shortcut would eat an
    /// ordinary keystroke everywhere in the system.
    var isUsable: Bool {
        !cocoaModifiers.intersection([.command, .option, .control]).isEmpty
    }

    static func keyName(for keyCode: UInt32) -> String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "Return", kVK_Escape: "Esc", kVK_Tab: "Tab",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
            kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
            kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[Int(keyCode)] { return name }

        // Ask the current keyboard layout, so a Dvorak user sees their own key.
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "?" }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

// MARK: - Registration

final class GlobalHotkey {

    enum Failure: Equatable {
        case alreadyTaken
        case needsAModifier
        case systemRefused(OSStatus)

        /// Said plainly, because this shows up in settings.
        var message: String {
            switch self {
            case .alreadyTaken:      return "Another app already uses that shortcut"
            case .needsAModifier:    return "Add Command, Option or Control"
            case .systemRefused(let code): return "macOS refused that shortcut (error \(code))"
            }
        }
    }

    static let shared = GlobalHotkey()

    /// Runs on the main thread when the shortcut fires.
    var onFire: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x49524953   // 'IRIS'

    private init() {}

    /// Register a combination, replacing whatever was registered before.
    /// Returns nil on success, or why it could not be done.
    @discardableResult
    func register(_ combo: HotkeyCombo) -> Failure? {
        unregister()
        guard combo.isUsable else { return .needsAModifier }

        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id,
                                         GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else {
            // eventHotKeyExistsErr is what a taken combination reports.
            return status == OSStatus(eventHotKeyExistsErr) ? .alreadyTaken : .systemRefused(status)
        }
        hotKeyRef = ref
        return nil
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, context in
            guard let context, let event else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { hotkey.onFire?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}

// MARK: - Status for the settings UI

/// Why the shortcut is not working, if it is not. Observable so the recorder row
/// can say so instead of the shortcut silently never firing.
final class HotkeyStatus: ObservableObject {
    static let shared = HotkeyStatus()
    @Published var failure: GlobalHotkey.Failure?
    private init() {}
}
