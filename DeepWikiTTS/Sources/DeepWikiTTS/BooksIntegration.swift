import Foundation
import AppKit

public enum BooksIntegration {
    public static func openInBooks(url: URL) -> Bool {
        let config = NSWorkspace.OpenConfiguration()
        return NSWorkspace.shared.open([url], withAppBundleIdentifier: "com.apple.iBooksX", options: [], additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }
}

