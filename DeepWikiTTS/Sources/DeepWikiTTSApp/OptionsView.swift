import SwiftUI
import DeepWikiTTS

struct OptionsView: View {
    @Binding var config: EpubParsingConfig
    @State private var rulesPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Title Mode", selection: bindingTitleMode) {
                Text("Auto").tag(0)
                Text("Tag Text").tag(1)
                Text("First Few").tag(2)
            }
            Picker("Newline Mode", selection: bindingNewlineMode) {
                Text("Single").tag(0)
                Text("Double").tag(1)
                Text("None").tag(2)
            }
            Toggle("Footnote Cleanup", isOn: bindingFootnotes)
            HStack {
                Button("Choose Rules JSON…") {
                    if let url = FilePicker.pickRules() {
                        rulesPath = url.path
                        config = EpubParsingConfig(titleMode: config.titleMode, newlineMode: config.newlineMode, breakString: config.breakString, applyFootnoteCleanup: config.applyFootnoteCleanup, searchReplaceRulesURL: url)
                    }
                }
                Text(rulesPath.isEmpty ? "No rules selected" : rulesPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var bindingTitleMode: Binding<Int> {
        Binding<Int>(
            get: {
                switch config.titleMode {
                case .auto: return 0
                case .tagText: return 1
                case .firstFew: return 2
                }
            }, set: { idx in
                switch idx {
                case 0: config = EpubParsingConfig(titleMode: .auto, newlineMode: config.newlineMode, breakString: config.breakString, applyFootnoteCleanup: config.applyFootnoteCleanup, searchReplaceRulesURL: config.searchReplaceRulesURL)
                case 1: config = EpubParsingConfig(titleMode: .tagText, newlineMode: config.newlineMode, breakString: config.breakString, applyFootnoteCleanup: config.applyFootnoteCleanup, searchReplaceRulesURL: config.searchReplaceRulesURL)
                default: config = EpubParsingConfig(titleMode: .firstFew, newlineMode: config.newlineMode, breakString: config.breakString, applyFootnoteCleanup: config.applyFootnoteCleanup, searchReplaceRulesURL: config.searchReplaceRulesURL)
                }
            }
        )
    }

    private var bindingNewlineMode: Binding<Int> {
        Binding<Int>(
            get: {
                switch config.newlineMode {
                case .single: return 0
                case .double: return 1
                case .none: return 2
                }
            }, set: { idx in
                let mode: NewlineMode = (idx == 0 ? .single : (idx == 1 ? .double : .none))
                config = EpubParsingConfig(titleMode: config.titleMode, newlineMode: mode, breakString: config.breakString, applyFootnoteCleanup: config.applyFootnoteCleanup, searchReplaceRulesURL: config.searchReplaceRulesURL)
            }
        )
    }

    private var bindingFootnotes: Binding<Bool> {
        Binding<Bool>(
            get: { config.applyFootnoteCleanup },
            set: { on in
                config = EpubParsingConfig(titleMode: config.titleMode, newlineMode: config.newlineMode, breakString: config.breakString, applyFootnoteCleanup: on, searchReplaceRulesURL: config.searchReplaceRulesURL)
            }
        )
    }
}

