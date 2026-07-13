import Carbon
import CoreGraphics
import Foundation

enum KeyTranslator {
    private static let namedKeys: [CGKeyCode: String] = [
        36: "Return",
        48: "Tab",
        49: "Space",
        51: "Delete",
        53: "Escape",
        54: "Right Command",
        55: "Command",
        56: "Shift",
        57: "Caps Lock",
        58: "Option",
        59: "Control",
        60: "Right Shift",
        61: "Right Option",
        62: "Right Control",
        63: "Fn",
        64: "F17",
        71: "Clear",
        72: "Volume Up",
        73: "Volume Down",
        74: "Mute",
        79: "F18",
        80: "F19",
        90: "F20",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "Forward Delete",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "Left",
        124: "Right",
        125: "Down",
        126: "Up"
    ]

    static func descriptor(for keyCode: CGKeyCode) -> KeyDescriptor {
        KeyDescriptor(
            keyCode: keyCode,
            keyID: keyID(for: keyCode),
            displayName: displayName(for: keyCode)
        )
    }

    static func keyID(for keyCode: CGKeyCode) -> String {
        "kc_\(UInt16(keyCode))"
    }

    static func displayName(for keyID: String) -> String {
        guard
            keyID.hasPrefix("kc_"),
            let rawValue = UInt16(keyID.dropFirst(3))
        else {
            return keyID
        }

        return displayName(for: CGKeyCode(rawValue))
    }

    static func displayName(for keyCode: CGKeyCode) -> String {
        if let named = namedKeys[keyCode] {
            return AppLocalizer.keyDisplayName(for: keyCode, englishFallback: named)
        }

        if let translated = translatedCharacter(for: keyCode), !translated.isEmpty {
            return translated.uppercased()
        }

        return AppLocalizer.keyFallbackName(UInt16(keyCode))
    }

    private static func translatedCharacter(for keyCode: CGKeyCode) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let layoutDataPointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self) as Data

        return layoutData.withUnsafeBytes { rawBuffer in
            guard let keyboardLayout = rawBuffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }

            var deadKeyState: UInt32 = 0
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 4)

            let status = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                buffer.count,
                &length,
                &buffer
            )

            guard status == noErr, length > 0 else {
                return nil
            }

            return buffer.withUnsafeBufferPointer { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return nil }
                return String(utf16CodeUnits: baseAddress, count: length)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
