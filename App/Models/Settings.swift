import Foundation

struct Settings: Hashable {
  var voiceID: String? = nil
  var rate: Float = 1.0
  var pitch: Float = 1.0
  var chunkChars: Int = 1500
}
