import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  @Published var selectedEPUBURL: URL?
  @Published var destinationURL: URL?

  @Published var book: Book?
  @Published var settings: Settings = .init()

  @Published var isConverting: Bool = false
  @Published var overallProgress: Double = 0

  let engine = ConversionEngine()
}
