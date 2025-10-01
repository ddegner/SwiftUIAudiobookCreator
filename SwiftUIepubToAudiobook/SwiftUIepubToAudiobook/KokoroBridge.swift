import Foundation
#if canImport(KokoroSwift)
import KokoroSwift

// Map app-level KokoroVoice to KokoroSwift's voice enumeration
extension KokoroVoice {
    var kokoroSwiftVoice: TTSVoice {
        switch self {
        case .afHeart: return .afHeart
        case .bmGeorge: return .bmGeorge
        }
    }
}

// Map app-level TTSLanguage to KokoroSwift's expected language
extension TTSLanguage {
    var kokoroSwiftLanguage: Language {
        switch self {
        case .enUS: return .enUS
        }
    }
}

#endif
