import Foundation

public enum HomeSection: String, CaseIterable, Identifiable, Codable {
  case listeningStats = "listening-stats"
  case pinnedPlaylist = "pinned-playlist"
  case continueListening = "continue-listening"
  case continueReading = "continue-reading"
  case continueSeries = "continue-series"
  case recentlyAdded = "recently-added"
  case recentSeries = "recent-series"
  case discover = "discover"
  case listenAgain = "listen-again"
  case newestAuthors = "newest-authors"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .listeningStats: return "Listening Stats"
    case .pinnedPlaylist: return "Pinned Playlist"
    case .continueListening: return "Continue Listening"
    case .continueReading: return "Continue Reading"
    case .continueSeries: return "Continue Series"
    case .recentlyAdded: return "Recently Added"
    case .recentSeries: return "Recent Series"
    case .discover: return "Discover"
    case .listenAgain: return "Listen Again"
    case .newestAuthors: return "Newest Authors"
    }
  }

  public var canBeDisabled: Bool {
    ![.pinnedPlaylist, .continueListening, .continueReading].contains(self)
  }

  public static var defaultCases: [HomeSection] {
    [
      .continueListening,
      .continueReading,
      .continueSeries,
      .recentlyAdded,
      .recentSeries,
      .discover,
      .listenAgain,
      .newestAuthors,
    ]
  }
}
