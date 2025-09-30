import AppKit
import Foundation

enum OpenPanelHelpers {
  static func selectEPUB(completion: @escaping (URL?) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.epub]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      completion(response == .OK ? panel.url : nil)
    }
  }

  static func selectFolder(completion: @escaping (URL?) -> Void) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.begin { response in
      completion(response == .OK ? panel.url : nil)
    }
  }
}
