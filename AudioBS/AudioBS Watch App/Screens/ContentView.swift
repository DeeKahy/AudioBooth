import Combine
import SwiftUI

struct ContentView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared
  @ObservedObject var playerManager = PlayerManager.shared
  @StateObject private var continueListeningModel = ContinueListeningViewModel()
  @StateObject private var localPlayerModel = LocalPlayerViewModel()
  @StateObject private var remotePlayerModel = RemotePlayerViewModel()

  private var hasActivePlayer: Bool {
    playerManager.hasActivePlayer || connectivityManager.hasActivePlayer
  }

  private var activePlayerModel: PlayerView.Model {
    if playerManager.hasActivePlayer {
      return localPlayerModel
    } else {
      return remotePlayerModel
    }
  }

  var body: some View {
    NavigationStack {
      ContinueListeningView(model: continueListeningModel)
        .toolbar {
          if hasActivePlayer {
            ToolbarItem(placement: .topBarTrailing) {
              NavigationLink {
                PlayerView(model: activePlayerModel)
              } label: {
                Image(systemName: playerManager.hasActivePlayer ? "applewatch" : "iphone")
              }
            }
          }
        }
    }
  }
}

#Preview {
  ContentView()
}
