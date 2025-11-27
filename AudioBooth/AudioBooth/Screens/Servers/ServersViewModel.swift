import API
import Foundation
import Models
import OSLog
import SwiftUI

final class ServersViewModel: ServersView.Model {
  private let audiobookshelf = Audiobookshelf.shared
  private var playerManager: PlayerManager { .shared }

  init() {
    let allConnections = audiobookshelf.authentication.connections.values
      .sorted { lhs, rhs in
        let lhsName = lhs.alias ?? (lhs.serverURL.host ?? "Unknown Server")
        let rhsName = rhs.alias ?? (rhs.serverURL.host ?? "Unknown Server")
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
      }

    let activeServerID = audiobookshelf.authentication.activeServerID

    var selected: ServerView.Model?
    let serverModels = allConnections.map { connection in
      let server = ServerViewModel(connection: connection)
      if connection.id == activeServerID {
        selected = server
      }
      return server
    }

    super.init(
      servers: serverModels,
      activeServerID: activeServerID,
      addServerModel: ServerViewModel(),
      selected: selected
    )
  }

  override func onAppear() {
    let allConnections = audiobookshelf.authentication.connections.values
      .sorted { lhs, rhs in
        let lhsName = lhs.alias ?? (lhs.serverURL.host ?? "Unknown Server")
        let rhsName = rhs.alias ?? (rhs.serverURL.host ?? "Unknown Server")
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
      }
    servers = allConnections.map { connection in
      ServerViewModel(connection: connection)
    }
    activeServerID = audiobookshelf.authentication.activeServerID
  }
}
