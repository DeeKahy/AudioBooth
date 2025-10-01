import Combine
import SwiftUI

struct ContentView: View {
  @ObservedObject var connectivityManager = WatchConnectivityManager.shared
  @StateObject private var continueListeningModel = ContinueListeningViewModel()

  var body: some View {
    NavigationStack {
      ContinueListeningView(model: continueListeningModel)
        .toolbar {
          if connectivityManager.hasActivePlayer {
            ToolbarItem(placement: .topBarTrailing) {
              NavigationLink {
                NowPlayingView()
              } label: {
                Image(systemName: "iphone")
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
