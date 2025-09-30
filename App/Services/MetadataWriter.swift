import AVFoundation
import Foundation

final class MetadataWriter {
  func apply(
    to url: URL,
    bookTitle: String,
    author: String,
    chapterTitle: String,
    trackNumber: Int,
    artworkData: Data?
  ) throws {
    let asset = AVURLAsset(url: url)
    guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { return }
    let tmp = url.deletingLastPathComponent().appendingPathComponent(".meta-\(UUID().uuidString).m4a")
    exporter.outputURL = tmp
    exporter.outputFileType = .m4a

    var items: [AVMetadataItem] = []

    let titleItem = AVMutableMetadataItem()
    titleItem.identifier = .commonIdentifierTitle
    titleItem.value = chapterTitle as NSString
    items.append(titleItem)

    let albumItem = AVMutableMetadataItem()
    albumItem.identifier = .commonIdentifierAlbumName
    albumItem.value = bookTitle as NSString
    items.append(albumItem)

    let artistItem = AVMutableMetadataItem()
    artistItem.identifier = .commonIdentifierArtist
    artistItem.value = author as NSString
    items.append(artistItem)

    // Track number in iTunes format
    let trackItem = AVMutableMetadataItem()
    trackItem.identifier = .iTunesMetadataTrackNumber
    trackItem.value = "\(trackNumber)/0" as NSString
    items.append(trackItem)

    if let artworkData {
      let art = AVMutableMetadataItem()
      art.identifier = .commonIdentifierArtwork
      art.value = artworkData as NSData
      items.append(art)
    }

    exporter.metadata = items
    let group = DispatchGroup()
    group.enter()
    exporter.exportAsynchronously { group.leave() }
    group.wait()
    if exporter.status == .completed {
      try? FileManager.default.removeItem(at: url)
      try FileManager.default.moveItem(at: tmp, to: url)
    } else {
      try? FileManager.default.removeItem(at: tmp)
      if let err = exporter.error { throw err }
    }
  }
}
