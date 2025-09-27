# cursor.md — macOS EPUB → Audiobook (SwiftUI + AVFoundation)

**Purpose**  
This file guides Cursor to build a **macOS** SwiftUI app that converts **DRM‑free EPUBs** into narrated audio **on‑device** using **AVFoundation** (not Apple Foundation Models), then helps users open/import results into **Apple Books**. It also captures the **reference repo’s EPUB‑parsing behaviors** so the Swift implementation mirrors its output.

---

## TL;DR (conceptual checklist)
- **Ingest & parse** EPUB → ordered chapters (title + clean text) with user‑selectable cleanup modes.  
- **Prepare narration**: detect language, pick voice, segment text to utterance‑sized chunks.  
- **Synthesize & record**: use `AVSpeechSynthesizer.write(_:toBufferCallback:)` to stream audio to disk.  
- **Package output**: save **per‑chapter `.m4a`** or a single `.m4a`; (optional) chapters sidecar.  
- **Export & hand‑off**: Share/Open via Finder; “Open Books” helper and import instructions for Apple Books.  
- **Polish**: progress, resume, accessibility, robust error handling & tests.

> **Non‑goals**:  
> - Direct, programmatic insertion into Apple Books’ library (no public macOS API).  
> - Cloud TTS. Support **on‑device** AVFoundation only.  
> - DRM‑protected EPUBs.

---

## Target & platform
- **App**: macOS (SwiftUI lifecycle), **macOS 13+** recommended.  
- **Entitlements**: App Sandbox **ON**, “User‑selected files (read/write)”.  
- **File access**: Use **NSOpenPanel** and **security‑scoped bookmarks** to persist access.

---

## Dependencies (SwiftPM)
- **Readium Swift Toolkit** — robust EPUB reading (spine/TOC) *or* DIY unzip + OPF parse if you prefer.  
- **SwiftSoup** — HTML to text cleanup (strip tags, keep headings).  
- **(Optional)**: A lightweight ZIP library only if you don’t use Readium.

---

## Architecture

### Modules
1. **Import**: NSOpenPanel, Drop‑to‑import, bookmark persistence.  
2. **Parse**: `EpubParser` protocol; `ReadiumEpubParser` (preferred) or `LightweightEpubParser` (ZIP + SwiftSoup).  
3. **Normalize**: Apply newline mode, footnote cleanup, search/replace rules, title strategies.  
4. **Synthesize**: `SpeechEngine` streaming AVSpeech buffers → `AVAudioFile` (AAC).  
5. **Package**: Per‑chapter `.m4a` (default) or concatenate; optional chapter sidecar JSON.  
6. **Books hand‑off**: Reveal in Finder, “Open Books” (bring Books to front), import instructions.  
7. **UI**: SwiftUI views: Import → TOC preview → Options → Convert → Progress → Results.

### Data models
```swift
struct Chapter: Identifiable, Codable {
    let id: Int
    let title: String
    let text: String
    let estimatedCharacters: Int
}

struct BookMeta: Codable {
    let title: String
    let author: String?
}

enum NewlineMode: String, Codable { case single, double, none }
enum TitleMode: String, Codable { case auto, tagText, firstFew }

struct ParseOptions: Codable {
    var newlineMode: NewlineMode
    var removeFootnoteMarkers: Bool
    var searchReplaceRules: [SearchReplaceRule] // regex -> replacement
    var titleMode: TitleMode
}

struct SpeechOptions: Codable {
    var voiceIdentifier: String?
    var rate: Float // 0.0–1.0 mapped to AVSpeechUtteranceMaximumSpeechRate bounds
    var pitch: Float // 0.5–2.0
    var languageHint: String? // BCP-47
    var outputBitrateKbps: Int // e.g. 64–96
}
```

---

## Reference repo — EPUB parsing behaviors to mirror

The reference implementation (Python CLI) prepares text for TTS with several **key behaviors**. Reproduce these in Swift so audio matches user expectations:

1. **Title extraction (3 modes)**
   - **auto**: prefer `<title>`, else `h1` → `h2` → `h3`; fallback to first ~60 chars of body.  
   - **tag_text**: strictly use tag text; if none, use a placeholder.  
   - **first_few**: always first ~60 chars of cleaned body.  
   In all cases, sanitize titles (collapse whitespace, strip special chars).

2. **Newline handling (3 modes)**
   - **single**: collapse any run of `\n+` into a break marker.  
   - **double**: collapse only `\n\n+` into a break marker.  
   - **none**: replace all newlines with spaces.

3. **Footnote/reference cleanup (optional)**
   - Remove superscript‑style numeric markers (e.g., “word¹”, “word2”).  
   - Remove bracketed numeric refs like `[1]`, `[2.3]`.

4. **Search & replace rules**
   - Load user‑provided regex rules and apply to each chapter during normalization.

5. **Reading order**
   - Iterate **spine/reading order** (not filename order) to build the chapter list.

> **Mapping to Swift**: Implement these as `ParseOptions` with defaults and a settings screen. Provide a live preview on sample chapters.

---

## Parsing strategy in Swift

### Option A — Readium (recommended)
- Open EPUB → enumerate **reading order** items and ToC.  
- For each XHTML item: extract title candidates (`<title>`, `h1/h2/h3>`), strip HTML with **SwiftSoup**, produce plain text.  
- Apply **Normalize** pipeline: newline mode, footnotes cleanup, search/replace, title mode.

### Option B — Lightweight (DIY)
- Unzip `.epub` → locate `.opf` → compute **spine order** → load XHTML files.  
- Parse with **SwiftSoup**, same normalization pipeline as above.

**Normalization pseudocode**
```swift
func normalize(_ raw: String, options: ParseOptions) -> String {
    var s = raw
    if options.removeFootnoteMarkers {
        s = removeSuperscriptsAndBracketedRefs(s)
    }
    for rule in options.searchReplaceRules {
        s = s.replacingOccurrences(of: rule.pattern, with: rule.replacement, options: .regularExpression)
    }
    s = applyNewlineMode(s, mode: options.newlineMode) // single/double/none
    s = collapseWhitespace(s)
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

---

## Speech synthesis & audio writing

- Use `AVSpeechSynthesizer.write(_:toBufferCallback:)` to receive **PCM** buffers.  
- Append buffers to an `AVAudioFile` (mono) and export as **AAC `.m4a`** (e.g., 22.05 or 24 kHz, 64–96 kbps).  
- Chunk input by **paragraph/sentence** to keep memory stable and enable progress + cancellation.  
- Provide controls for **voice**, **rate**, **pitch**, **language** (BCP‑47).  
- Expose a **Preview 30s** button per chapter before full conversion.

**Streaming skeleton**
```swift
final class SpeechEngine: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    func synthesize(chapter: Chapter, opts: SpeechOptions, to fileURL: URL, progress: @escaping (Double)->Void, completion: @escaping (Result<Void, Error>)->Void) {
        let utterances = chunkedUtterances(from: chapter.text, opts: opts)
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 24000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ])
            var total = utterances.count
            var done = 0
            for u in utterances {
                try synth.write(u) { buf in
                    if let pcm = buf as? AVAudioPCMBuffer {
                        try? audioFile.write(from: pcm)
                    } else if buf.audioBufferList.pointee.mNumberBuffers == 0 {
                        done += 1
                        progress(Double(done) / Double(total))
                    }
                }
            }
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}
```
> **Note**: In production, use a separate **encoding step** to AAC `.m4a` if you collect PCM first; or write directly via an `AVAssetWriter` pipeline.

---

## Packaging & chapters

- **Default**: **per‑chapter `.m4a` files** (easiest and reliable for Books import).  
- **Single file** (optional): concatenate PCM then encode; maintain a **sidecar JSON** with chapter start offsets.  
- **Embedded chapters** (advanced): can be done via a timed metadata track; ship later due to complexity.

**Minimal metadata** (album/artist/track) can be set when exporting or by writing ID3/QuickTime metadata where supported.

---

## Apple Books hand‑off (macOS)

- Provide **“Reveal in Finder”** and **“Open Books”** buttons.  
- **Bring Books to front** (e.g., `NSWorkspace.shared.openApplication(at:)` with the Books app URL) and show an in‑app **Import help**:  
  1) Open **Books**.  
  2) Choose **File → Import…**.  
  3) Select the exported `.m4a` (or folder of chapters).  
- Avoid claiming one‑tap, programmatic library insertion.

---

## UI flow

1. **Home**: Drop file or “Import EPUB”.  
2. **Preview**: Show metadata (title/author), TOC with estimated durations.  
3. **Options**: Title mode, newline mode, footnote cleanup, voice/rate/pitch, per‑chapter vs single file.  
4. **Convert**: Progress per chapter (queue), cancel/resume.  
5. **Result**: List of output files, actions: Preview, Reveal in Finder, Open Books, Delete, Re‑render.

---

## Errors & resilience

- Malformed EPUB (missing OPF/spine) → friendly error + log.  
- DRM‑protected EPUB → explain not supported.  
- Voice unavailable → fallback to default system voice.  
- Low disk space → stop current chapter, show guidance.  
- Crash‑safe: write temp files, atomically move on success; resume at last finished chapter.

---

## Testing (definition of done)

- **Parsing**: Validates reading order, titles, and normalization modes on 5 diverse EPUBs.  
- **Synthesis**: Converts a multi‑chapter book; audio is gap‑free; cancel/resume works.  
- **Export**: Files open in Finder; Books import instructions are correct; at least one chapter imports and plays in Books.  
- **Accessibility**: VoiceOver reads all controls; keyboard navigation; dynamic type respected.  
- **Performance**: Memory steady during long synth; UI responsive.

---

## Suggested file structure

```
EpubToAudio/
  App/
    EpubToAudioApp.swift
    AppState.swift
  Features/
    Import/
    Parse/
      EpubParser.swift
      ReadiumEpubParser.swift
      LightweightEpubParser.swift
      Normalize.swift
    Synthesis/
      SpeechEngine.swift
    Packaging/
      AudioExporter.swift
      ChapterSidecar.swift
    Books/
      BooksHandOff.swift
    UI/
      HomeView.swift
      TocView.swift
      OptionsView.swift
      ConvertView.swift
      ResultsView.swift
  Shared/
    Models.swift
    Utilities.swift
  Resources/
    Assets.xcassets
    SampleEPUBs/
```

---

## Cursor guardrails

- **Do**: Use Swift 5.9+, SwiftUI, AVFoundation; write small, composable types with doc comments and unit tests.  
- **Do**: Keep TTS **on‑device**; prefer per‑chapter outputs; write robust normalization utilities.  
- **Don’t**: Attempt to insert into Apple Books programmatically or require cloud services.  
- **Docs**: Each public API should have a short docstring; include README sections from this file.

---

## Quick tasks for Cursor

1. **Models & options**: Implement `Models.swift` with data structures shown above.  
2. **EPUB parser protocol + Readium parser**: Spine order → chapters; extract titles; normalize text.  
3. **Normalization utilities**: newline modes, footnote cleanup (regex), search&replace rules loader.  
4. **Speech engine**: streaming write to `.m4a`, progress/cancel, preview 30s.  
5. **Results view**: list output files; Reveal in Finder; Open Books helper.  
6. **Unit tests**: parsing and normalization behaviors (3 title modes, 3 newline modes).

---

## Stretch goals
- Single‑file output with chapters sidecar JSON.  
- Embedded chapter markers via timed metadata (advanced).  
- Language auto‑detection per chapter and voice auto‑switch.  
- Batch convert multiple EPUBs.

---

## Prompts (examples)

- *“Create `EpubParser` protocol and a `ReadiumEpubParser` that yields `[Chapter]`. Include title detection modes and newline modes.”*  
- *“Write `Normalize.swift` with regex functions: remove superscripts `[0-9]+` and bracketed refs (`\[[0-9]+(\.[0-9]+)*\]`). Add unit tests.”*  
- *“Implement `SpeechEngine.synthesize` that streams AVSpeech buffers to an `AVAudioFile` (PCM) and then exports AAC `.m4a`.”*  
- *“Build `ResultsView` with buttons: Preview, Reveal in Finder, Open Books (and an import help popover).”*
