import Foundation

enum SecurityBookmarkManager {
  private static let defaults = UserDefaults.standard

  static func saveBookmark(for url: URL, key: String) throws {
    let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    defaults.set(data, forKey: key)
  }

  static func resolveBookmark(key: String) -> URL? {
    guard let data = defaults.data(forKey: key) else { return nil }
    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
      if isStale { return nil }
      return url
    } catch {
      return nil
    }
  }
}
