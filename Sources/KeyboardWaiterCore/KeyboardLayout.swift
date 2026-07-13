import AppKit
import CoreGraphics

struct KeyboardKeySpec {
    let keyID: String
    let label: String
    let widthUnits: CGFloat
}

enum KeyboardLayoutItem {
    case key(KeyboardKeySpec)
    case spacer(CGFloat)
}

enum KeyboardLayout {
    static let rows: [[KeyboardLayoutItem]] = [
        [
            key(53, "Esc"),
            spacer(0.6),
            key(122, "F1"),
            key(120, "F2"),
            key(99, "F3"),
            key(118, "F4"),
            spacer(0.4),
            key(96, "F5"),
            key(97, "F6"),
            key(98, "F7"),
            key(100, "F8"),
            spacer(0.4),
            key(101, "F9"),
            key(109, "F10"),
            key(103, "F11"),
            key(111, "F12")
        ],
        [
            key(50, "`"),
            key(18, "1"),
            key(19, "2"),
            key(20, "3"),
            key(21, "4"),
            key(23, "5"),
            key(22, "6"),
            key(26, "7"),
            key(28, "8"),
            key(25, "9"),
            key(29, "0"),
            key(27, "-"),
            key(24, "="),
            key(51, "Delete", width: 2.0)
        ],
        [
            key(48, "Tab", width: 1.5),
            key(12, "Q"),
            key(13, "W"),
            key(14, "E"),
            key(15, "R"),
            key(17, "T"),
            key(16, "Y"),
            key(32, "U"),
            key(34, "I"),
            key(31, "O"),
            key(35, "P"),
            key(33, "["),
            key(30, "]"),
            key(42, "\\", width: 1.5)
        ],
        [
            key(57, "Caps", width: 1.75),
            key(0, "A"),
            key(1, "S"),
            key(2, "D"),
            key(3, "F"),
            key(5, "G"),
            key(4, "H"),
            key(38, "J"),
            key(40, "K"),
            key(37, "L"),
            key(41, ";"),
            key(39, "'"),
            key(36, "Return", width: 2.25)
        ],
        [
            key(56, "Shift", width: 2.25),
            key(6, "Z"),
            key(7, "X"),
            key(8, "C"),
            key(9, "V"),
            key(11, "B"),
            key(45, "N"),
            key(46, "M"),
            key(43, ","),
            key(47, "."),
            key(44, "/"),
            key(60, "R Shift", width: 2.75)
        ],
        [
            key(59, "Ctrl", width: 1.4),
            key(63, "Fn", width: 1.0),
            key(58, "Opt", width: 1.2),
            key(55, "Cmd", width: 1.5),
            key(49, "Space", width: 5.8),
            key(54, "R Cmd", width: 1.5),
            key(61, "R Opt", width: 1.2)
        ],
        [
            spacer(11.7),
            key(126, "Up")
        ],
        [
            spacer(10.5),
            key(123, "Left"),
            key(125, "Down"),
            key(124, "Right")
        ]
    ]

    static var keyCount: Int {
        rows.reduce(into: 0) { total, row in
            total += row.reduce(into: 0) { rowTotal, item in
                if case .key = item {
                    rowTotal += 1
                }
            }
        }
    }

    static var trackedKeyIDs: Set<String> {
        rows.reduce(into: Set<String>()) { partialResult, row in
            for item in row {
                if case .key(let spec) = item {
                    partialResult.insert(spec.keyID)
                }
            }
        }
    }

    private static func key(_ keyCode: UInt16, _ label: String, width: CGFloat = 1.0) -> KeyboardLayoutItem {
        .key(
            KeyboardKeySpec(
                keyID: KeyTranslator.keyID(for: CGKeyCode(keyCode)),
                label: label,
                widthUnits: width
            )
        )
    }

    private static func spacer(_ widthUnits: CGFloat) -> KeyboardLayoutItem {
        .spacer(widthUnits)
    }
}
