import Foundation
import AVFoundation

public enum MetadataExporterError: Error {
    case exportFailed
}

public struct ChapterTaggingInfo: Sendable {
    public let book: BookMetadata
    public let chapterIndex: Int
    public init(book: BookMetadata, chapterIndex: Int) {
        self.book = book
        self.chapterIndex = chapterIndex
    }
}

public enum MetadataExporter {
    public static func tagM4A(
        inputURL: URL,
        outputURL: URL,
        tagging: ChapterTaggingInfo,
        completion: @Sendable @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: inputURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(MetadataExporterError.exportFailed)); return
        }
        exporter.outputFileType = .m4a
        exporter.outputURL = outputURL

        // Basic tags recognized by Books
        var metadata: [AVMutableMetadataItem] = []

        let album = AVMutableMetadataItem()
        album.identifier = .iTunesMetadataAlbum
        album.value = tagging.book.title as NSString
        metadata.append(album)

        let artist = AVMutableMetadataItem()
        artist.identifier = .iTunesMetadataArtist
        artist.value = tagging.book.author as NSString
        metadata.append(artist)

        let trackNumber = AVMutableMetadataItem()
        trackNumber.identifier = .iTunesMetadataTrackNumber
        trackNumber.value = "\(tagging.chapterIndex)" as NSString
        metadata.append(trackNumber)

        exporter.metadata = metadata
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outputURL))
            default:
                completion(.failure(exporter.error ?? MetadataExporterError.exportFailed))
            }
        }
    }
}

