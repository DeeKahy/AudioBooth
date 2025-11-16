import API
import AppIntents
import Models
import PlayerIntents
import RevenueCat
import SwiftUI
import UIKit
import WidgetKit

@main
struct AudioBoothApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    DownloadManager.shared.cleanupOrphanedDownloads()
    _ = WatchConnectivityManager.shared
    _ = SessionManager.shared
    _ = UserPreferences.shared

    observeAuthentication()
    observeLibrary()

    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: "appl_AuBdFKRrOngbJsXGkkxDKGNbGRW")

    let player: PlayerManagerProtocol = PlayerManager.shared
    AppDependencyManager.shared.add(dependency: player)
  }

  private func observeAuthentication() {
    Audiobookshelf.shared.authentication.onAuthenticationChanged = { credentials in
      if let (serverURL, token) = credentials {
        WatchConnectivityManager.shared.syncAuthCredentials(serverURL: serverURL, token: token)
      } else {
        WatchConnectivityManager.shared.clearAuthCredentials()
      }
    }

    if let connection = Audiobookshelf.shared.authentication.connection {
      WatchConnectivityManager.shared.syncAuthCredentials(
        serverURL: connection.serverURL, token: connection.token)
    }
  }

  private func observeLibrary() {
    Audiobookshelf.shared.libraries.onLibraryChanged = { library in
      if let library {
        WatchConnectivityManager.shared.syncLibrary(library)
        Task {
          try? await Audiobookshelf.shared.libraries.fetchFilterData()
        }
      } else {
        WatchConnectivityManager.shared.clearLibrary()
      }
    }

    if let library = Audiobookshelf.shared.libraries.current {
      WatchConnectivityManager.shared.syncLibrary(library)
      Task {
        try? await Audiobookshelf.shared.libraries.fetchFilterData()
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
