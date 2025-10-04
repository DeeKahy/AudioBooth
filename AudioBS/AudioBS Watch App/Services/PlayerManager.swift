import API
import Combine
import Foundation
import Models

final class PlayerManager: ObservableObject {
  @Published var current: PlayerView.Model?
  @Published var isShowingFullPlayer = false

  static let shared = PlayerManager()

  private static let currentBookIDKey = "currentBookID"

  private init() {
    Task { @MainActor in
      await self.restoreLastPlayer()
    }
  }

  private func restoreLastPlayer() async {
    guard current == nil,
      let savedBookID = UserDefaults.standard.string(forKey: Self.currentBookIDKey),
      let recent = try? RecentlyPlayedItem.fetch(bookID: savedBookID)
    else {
      return
    }

    setCurrent(recent)
  }

  var isPlayingLocally: Bool {
    guard let current else { return false }
    return current is LocalPlayerModel && current.isPlaying
  }

  func setCurrent(_ item: RecentlyPlayedItem) {
    if let localPlayer = current as? LocalPlayerModel,
      item.bookID == localPlayer.item.bookID
    {
      return
    } else {
      clearCurrent()
      current = LocalPlayerModel(item)
      UserDefaults.standard.set(item.bookID, forKey: Self.currentBookIDKey)
    }
  }

  func clearCurrent() {
    if let localPlayer = current as? LocalPlayerModel {
      localPlayer.closeSession()
    }
    current = nil
    UserDefaults.standard.removeObject(forKey: Self.currentBookIDKey)
  }
}
