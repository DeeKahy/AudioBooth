import Combine
import Foundation
import SwiftUI

final class PinnedPlaylistManager: ObservableObject {
  static let shared = PinnedPlaylistManager()

  @AppStorage("pinnedPlaylistID")
  var pinnedPlaylistID: String?

  private let preferences = UserPreferences.shared

  private init() {}

  func pin(_ playlistID: String) {
    pinnedPlaylistID = playlistID

    if !preferences.homeSections.contains(.pinnedPlaylist) {
      preferences.homeSections.insert(.pinnedPlaylist, at: 0)
    }
  }

  func unpin() {
    pinnedPlaylistID = nil
    preferences.homeSections.removeAll { $0 == .pinnedPlaylist }
  }

  func isPinned(_ playlistID: String) -> Bool {
    pinnedPlaylistID == playlistID
  }
}
