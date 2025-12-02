import API
import Foundation
import KeychainAccess
import Logging
import Models
import SwiftUI
import UIKit

final class ServerViewModel: ServerView.Model {
  private let audiobookshelf = Audiobookshelf.shared
  private var oidcAuthManager: OIDCAuthenticationManager?
  private var playerManager: PlayerManager { .shared }

  private var libraryData: [API.Library] = []
  private var connection: AuthenticationService.Connection?
  private var pendingConnectionID: String?

  init(connection: AuthenticationService.Connection? = nil) {
    self.connection = connection

    let serverURL: String
    let customHeaders: [String: String]
    let selectedLibrary: Library?
    let isAuthenticated: Bool
    let alias: String
    let isActiveServer: Bool

    if let connection {
      serverURL = connection.serverURL.absoluteString
      customHeaders = connection.customHeaders
      isAuthenticated = true
      alias = connection.alias ?? ""
      isActiveServer = audiobookshelf.authentication.activeServerID == connection.id

      if isActiveServer, let current = audiobookshelf.libraries.current {
        selectedLibrary = Library(id: current.id, name: current.name)
      } else {
        selectedLibrary = nil
      }
    } else {
      serverURL = ""
      customHeaders = [:]
      selectedLibrary = nil
      isAuthenticated = false
      alias = ""
      isActiveServer = false
    }

    super.init(
      isAuthenticated: isAuthenticated,
      serverURL: serverURL,
      username: "",
      password: "",
      customHeaders: CustomHeadersViewModel(initialHeaders: customHeaders),
      selectedLibrary: selectedLibrary,
      alias: alias
    )

  }

  override func onAppear() {
    if connection != nil {
      Task {
        await fetchLibraries()
      }
    }
  }

  override func onLoginTapped() {
    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return
    }

    isLoading = true
    let normalizedURL = buildFullServerURL()
    let headers = Dictionary(uniqueKeysWithValues: customHeaders.headers.map { ($0.key, $0.value) })

    Task {
      do {
        let connectionID = try await audiobookshelf.authentication.login(
          serverURL: normalizedURL,
          username: username.trimmingCharacters(in: .whitespacesAndNewlines),
          password: password,
          customHeaders: headers
        )
        password = ""
        pendingConnectionID = connectionID
        connection = audiobookshelf.authentication.connections[connectionID]
        isAuthenticated = true
        await fetchLibraries()
      } catch {
        AppLogger.viewModel.error("Login failed: \(error.localizedDescription)")
        Toast(error: error.localizedDescription).show()
        isAuthenticated = false
      }

      isLoading = false
    }
  }

  override func onOIDCLoginTapped() {
    guard !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    let normalizedURL = buildFullServerURL()
    let headers = Dictionary(uniqueKeysWithValues: customHeaders.headers.map { ($0.key, $0.value) })

    isLoading = true

    let authManager = OIDCAuthenticationManager(
      serverURL: normalizedURL,
      customHeaders: headers
    )
    authManager.delegate = self
    self.oidcAuthManager = authManager

    authManager.start()
  }

  func showError(_ message: String) {
    Toast(error: message).show()
    isLoading = false
  }

  override func onDiscoverServersTapped() {
    showDiscoveryPortAlert = true
  }

  func performDiscovery() {
    isDiscovering = true
    discoveredServers = []

    Task {
      let port = Int(discoveryPort) ?? 13378
      let servers = await audiobookshelf.networkDiscovery.discoverServers(port: port)
      discoveredServers = servers

      isDiscovering = false
    }
  }

  override func onServerSelected(_ server: DiscoveredServer) {
    serverURL = server.serverURL.absoluteString
  }

  override func onLibraryTapped(_ library: Library) {
    guard
      library.id != selectedLibrary?.id,
      let value = libraryData.first(where: { $0.id == library.id })
    else { return }

    let connectionID = pendingConnectionID ?? connection?.id
    guard let connectionID else { return }

    if audiobookshelf.authentication.activeServerID != connectionID {
      Task {
        do {
          try await audiobookshelf.switchToServer(connectionID)
          audiobookshelf.libraries.current = value
          selectedLibrary = library
          pendingConnectionID = nil
          Toast(success: "Switched to server and selected library").show()
        } catch {
          AppLogger.viewModel.error("Failed to switch server: \(error.localizedDescription)")
          Toast(error: "Failed to switch server").show()
        }
      }
    } else {
      audiobookshelf.libraries.current = value
      selectedLibrary = library
      pendingConnectionID = nil
    }
  }

  override func onAliasChanged(_ newAlias: String) {
    guard let connectionID = connection?.id else { return }
    let trimmedAlias = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
    audiobookshelf.authentication.updateAlias(
      connectionID,
      alias: trimmedAlias.isEmpty ? nil : trimmedAlias
    )
  }

  override func onLogoutTapped() {
    guard let serverID = connection?.id else { return }

    if audiobookshelf.authentication.activeServerID == serverID {
      playerManager.current = nil
    }

    audiobookshelf.logout(serverID: serverID)
    isAuthenticated = false
    username = ""
    password = ""
    discoveredServers = []
    libraries = []
    selectedLibrary = nil

    if let appGroupURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.me.jgrenier.audioBS"
    ) {
      let serverDirectory = appGroupURL.appendingPathComponent(serverID)

      if FileManager.default.fileExists(atPath: serverDirectory.path) {
        try? FileManager.default.removeItem(at: serverDirectory)
      }
    }
  }

  private func fetchLibraries() async {
    let connectionID = pendingConnectionID ?? connection?.id
    guard let connectionID else { return }

    isLoadingLibraries = true

    do {
      let fetchedLibraries = try await audiobookshelf.libraries.fetch(serverID: connectionID)

      libraryData = fetchedLibraries

      self.libraries = fetchedLibraries.map({ Library(id: $0.id, name: $0.name) })
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

      if libraries.count == 1, let singleLibrary = libraries.first, selectedLibrary == nil {
        onLibraryTapped(singleLibrary)
      }
    } catch {
      Toast(error: "Failed to load libraries").show()
    }

    isLoadingLibraries = false
  }

  private func buildFullServerURL() -> String {
    let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)

    var fullURL: String
    if trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://") {
      fullURL = trimmedURL
    } else {
      fullURL = serverScheme.rawValue + trimmedURL
    }

    if useSubdirectory {
      let trimmedSubdirectory =
        subdirectory
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

      if !trimmedSubdirectory.isEmpty {
        fullURL = fullURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        fullURL += "/" + trimmedSubdirectory
      }
    }

    return fullURL
  }
}

extension ServerViewModel: OIDCAuthenticationDelegate {
  func oidcAuthenticationDidSucceed(connectionID: String) {
    pendingConnectionID = connectionID
    connection = audiobookshelf.authentication.connections[connectionID]
    isAuthenticated = true
    isLoading = false
    oidcAuthManager = nil
    Toast(success: "Successfully authenticated with SSO").show()
    Task {
      await fetchLibraries()
    }
  }

  func oidcAuthentication(didFailWithError error: Error) {
    showError("SSO login failed: \(error.localizedDescription)")
    isLoading = false
    oidcAuthManager = nil
  }
}
