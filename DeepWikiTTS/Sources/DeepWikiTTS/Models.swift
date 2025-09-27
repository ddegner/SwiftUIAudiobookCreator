import Foundation

public struct Chapter: Sendable, Equatable {
    public let title: String
    public let text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

public enum TitleMode: Sendable {
    case auto
    case tagText
    case firstFew
}

public enum NewlineMode: Sendable {
    case single
    case double
    case none
}

public struct EpubParsingConfig: Sendable {
    public let titleMode: TitleMode
    public let newlineMode: NewlineMode
    public let breakString: String
    public let applyFootnoteCleanup: Bool
    public let searchReplaceRulesURL: URL?

    public init(
        titleMode: TitleMode = .auto,
        newlineMode: NewlineMode = .single,
        breakString: String = "\n\n",
        applyFootnoteCleanup: Bool = true,
        searchReplaceRulesURL: URL? = nil
    ) {
        self.titleMode = titleMode
        self.newlineMode = newlineMode
        self.breakString = breakString
        self.applyFootnoteCleanup = applyFootnoteCleanup
        self.searchReplaceRulesURL = searchReplaceRulesURL
    }
}

public struct TTSVoiceConfig: Sendable {
    public let identifier: String?
    public let rate: Double
    public let pitch: Double
    public let preUtteranceDelay: TimeInterval
    public let postUtteranceDelay: TimeInterval

    public init(
        identifier: String? = nil,
        rate: Double = 0.5,
        pitch: Double = 1.0,
        preUtteranceDelay: TimeInterval = 0.3,
        postUtteranceDelay: TimeInterval = 0.3
    ) {
        self.identifier = identifier
        self.rate = rate
        self.pitch = pitch
        self.preUtteranceDelay = preUtteranceDelay
        self.postUtteranceDelay = postUtteranceDelay
    }
}

public struct BookMetadata: Sendable {
    public let title: String
    public let author: String

    public init(title: String, author: String) {
        self.title = title
        self.author = author
    }
}

