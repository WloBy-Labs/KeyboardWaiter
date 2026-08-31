import Foundation
#if SWIFT_PACKAGE
import KeyboardWaiterCore
#endif

/// 宠物模块依赖 Core，所以直接消费它的 `DailyInputSummary`，不再重复定义一份。
/// 成长逻辑仍然是纯函数，测试里可以随便造数据。

public enum PetLanguage {
    case english
    case simplifiedChinese
}
