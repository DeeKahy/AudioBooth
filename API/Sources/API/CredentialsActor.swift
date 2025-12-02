import Foundation

actor CredentialsActor {
  private var refreshTask: Task<Credentials, Error>?
  private weak var connection: Connection?

  init(connection: Connection) {
    self.connection = connection
  }

  var freshCredentials: Credentials {
    get async throws {
      guard let connection = connection else {
        throw Audiobookshelf.AudiobookshelfError.networkError("No connection")
      }

      guard case .bearer(_, _, let expiresAt) = connection.token else {
        return connection.token
      }

      let currentTime = Date().timeIntervalSince1970
      let bufferTime: TimeInterval = 60

      if currentTime < (expiresAt - bufferTime) {
        return connection.token
      }

      if let existingTask = refreshTask {
        return try await existingTask.value
      }

      let connectionToRefresh = connection
      let task = Task<Credentials, Error> { @MainActor in
        try await Audiobookshelf.shared.authentication.refreshToken(for: connectionToRefresh)
        return connectionToRefresh.token
      }

      refreshTask = task

      do {
        let credentials = try await task.value
        refreshTask = nil
        return credentials
      } catch {
        refreshTask = nil
        throw error
      }
    }
  }
}
