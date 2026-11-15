import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Reports whether Apple's on-device model exists on this phone. It is not used for extraction yet: the rules are
// enough for the demo, and the model could override a deliberate blank (see docs/ios/extraction.md).
enum ModelAssist {
    static var availability: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return "available (not used)"
        case let .unavailable(reason): return "unavailable (\(reason))"
        }
        #else
        return "not in this SDK"
        #endif
    }
}
