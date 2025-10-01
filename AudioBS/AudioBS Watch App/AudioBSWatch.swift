import SwiftUI

@main
struct AudioBSWatch: App {
  init() {
    _ = WatchConnectivityManager.shared
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
