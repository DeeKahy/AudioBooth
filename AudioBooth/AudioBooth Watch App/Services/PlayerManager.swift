import API
import Combine
import Foundation
import Models
import OSLog

final class PlayerManager: ObservableObject {
  @Published var current: PlayerView.Model?
  @Published var isShowingFullPlayer = false

  static let shared = PlayerManager()

  private static let currentBookIDKey = "currentBookID"

  var isPlayingLocally: Bool {
    guard let current else { return false }
    return current is LocalPlayerModel && current.isPlaying
  }

  func setCurrent(_ item: LocalBook) {
    if let localPlayer = current as? LocalPlayerModel,
      item.bookID == localPlayer.item.bookID
    {
      return
    } else {
      clearCurrent()
      guard let playerModel = LocalPlayerModel(item) else {
        AppLogger.player.error(
          "Failed to create player model for item \(item.bookID, privacy: .public)")
        return
      }
      current = playerModel
      UserDefaults.standard.set(item.bookID, forKey: Self.currentBookIDKey)
    }
  }

  func setCurrent(_ book: Book) {
    if let localPlayer = current as? LocalPlayerModel,
      book.id == localPlayer.item.bookID
    {
      return
    } else {
      clearCurrent()
      guard let playerModel = LocalPlayerModel(book) else {
        AppLogger.player.error(
          "Failed to create player model for book \(book.id, privacy: .public)")
        return
      }
      current = playerModel
      UserDefaults.standard.set(book.id, forKey: Self.currentBookIDKey)
    }
  }

  func clearCurrent() {
    current = nil
    UserDefaults.standard.removeObject(forKey: Self.currentBookIDKey)
  }
}
