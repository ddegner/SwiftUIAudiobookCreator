import Foundation

struct Chapter: Identifiable, Hashable {
  var id: UUID = .init()
  var index: Int
  var title: String
  var htmlURL: URL
  var text: String = ""
  var outputURL: URL?
  var duration: TimeInterval?
}
