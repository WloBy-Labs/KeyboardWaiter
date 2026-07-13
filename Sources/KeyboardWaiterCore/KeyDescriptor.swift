import CoreGraphics
import Foundation

public struct KeyDescriptor: Equatable {
    public let keyCode: UInt16
    public let keyID: String
    public let displayName: String

    init(keyCode: CGKeyCode, keyID: String, displayName: String) {
        self.keyCode = UInt16(keyCode)
        self.keyID = keyID
        self.displayName = displayName
    }
}
