import AppKit
import Foundation

struct Book: Identifiable, Hashable {
  var id: UUID = .init()
  var title: String
  var author: String
  var cover: NSImage?
  var chapters: [Chapter]
}
