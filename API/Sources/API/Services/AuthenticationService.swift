import Foundation
import KeychainAccess
import Logging
import Nuke

public final class AuthenticationService {
  private let audiobookshelf: Audiobookshelf
  private let keychain = Keychain(service: "me.jgrenier.AudioBS")

  public var onAuthenticationChanged: ((String, URL, String)?) -> Void = { _ in }

  enum Keys {
    static let connections = "audiobookshelf_server_connections"
    static let activeServerID = "audiobookshelf_active_server_id"
    static let permissions = "audiobookshelf_user_permissions"
  }

  public struct Connection: Codable {
    public let id: String
    public let serverURL: URL
    public let token: String
    public let customHeaders: [String: String]
    public var alias: String?

    public init(
      id: String? = nil,
      serverURL: URL,
      token: String,
      customHeaders: [String: String] = [:],
      alias: String? = nil
    ) {
      self.id = id ?? UUID().uuidString
      self.serverURL = serverURL
      self.token = token
      self.customHeaders = customHeaders
      self.alias = alias
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
      serverURL = try container.decode(URL.self, forKey: .serverURL)
      token = try container.decode(String.self, forKey: .token)
      customHeaders =
        try container.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:]
      alias = try container.decodeIfPresent(String.self, forKey: .alias)
    }
  }

  public var connections: [String: Connection] {
    get {
      guard let data = try? keychain.getData(Keys.connections) else { return [:] }
      return (try? JSONDecoder().decode([String: Connection].self, from: data)) ?? [:]
    }
    set {
      if !newValue.isEmpty {
        guard let data = try? JSONEncoder().encode(newValue) else { return }
        try? keychain.set(data, key: Keys.connections)
      } else {
        try? keychain.remove(Keys.connections)
      }
    }
  }

  public var activeServerID: String? {
    get {
      UserDefaults.standard.string(forKey: Keys.activeServerID)
    }
    set {
      if let newValue = newValue {
        UserDefaults.standard.set(newValue, forKey: Keys.activeServerID)
      } else {
        UserDefaults.standard.removeObject(forKey: Keys.activeServerID)
      }
      audiobookshelf.setupNetworkService()
    }
  }

  public var connection: Connection? {
    get {
      guard let serverID = activeServerID else { return nil }
      return connections[serverID]
    }
    set {
      guard let serverID = activeServerID else { return }
      var allConnections = connections
      if let newValue = newValue {
        allConnections[serverID] = newValue
      } else {
        allConnections.removeValue(forKey: serverID)
      }
      connections = allConnections
      audiobookshelf.setupNetworkService()
    }
  }

  public var serverURL: URL? { connection?.serverURL }
  public var isAuthenticated: Bool { connection != nil }

  public var permissions: User.Permissions? {
    get {
      guard let data = UserDefaults.standard.data(forKey: Keys.permissions) else { return nil }
      return try? JSONDecoder().decode(User.Permissions.self, from: data)
    }
    set {
      if let newValue = newValue {
        guard let data = try? JSONEncoder().encode(newValue) else { return }
        UserDefaults.standard.set(data, forKey: Keys.permissions)
      } else {
        UserDefaults.standard.removeObject(forKey: Keys.permissions)
      }
    }
  }

  init(audiobookshelf: Audiobookshelf) {
    self.audiobookshelf = audiobookshelf
  }

  public func migrateLegacyConnection() {
    struct LegacyConnection: Codable {
      let serverURL: URL
      let token: String
      let customHeaders: [String: String]?
      let alias: String?
    }

    let legacyConnectionKey = "audiobookshelf_server_connection"

    guard let legacyData = try? keychain.getData(legacyConnectionKey) else {
      return
    }

    guard let legacyConnection = try? JSONDecoder().decode(LegacyConnection.self, from: legacyData)
    else {
      AppLogger.authentication.error("Failed to decode legacy connection")
      return
    }

    AppLogger.authentication.info("Migrating legacy connection to multi-server format")

    do {
      try keychain.remove(legacyConnectionKey)
    } catch {
      AppLogger.authentication.error("Failed to remove legacy key: \(error.localizedDescription)")
      return
    }

    let migratedConnection = Connection(
      serverURL: legacyConnection.serverURL,
      token: legacyConnection.token,
      customHeaders: legacyConnection.customHeaders ?? [:],
      alias: legacyConnection.alias
    )

    var allConnections = connections
    allConnections[migratedConnection.id] = migratedConnection
    connections = allConnections

    activeServerID = migratedConnection.id
  }

  public func login(
    serverURL: String,
    username: String,
    password: String,
    customHeaders: [String: String] = [:]
  ) async throws -> String {
    guard let baseURL = URL(string: serverURL) else {
      throw Audiobookshelf.AudiobookshelfError.invalidURL
    }

    let loginService = NetworkService(baseURL: baseURL)

    struct LoginRequest: Codable {
      let username: String
      let password: String
    }

    struct Response: Codable {
      struct User: Codable {
        let token: String
      }
      let user: User
    }

    let loginRequest = LoginRequest(username: username, password: password)
    let request = NetworkRequest<Response>(
      path: "/login",
      method: .post,
      body: loginRequest,
      headers: customHeaders
    )

    let response = try await loginService.send(request)
    let token = response.value.user.token

    let newConnection = Connection(
      serverURL: baseURL,
      token: token,
      customHeaders: customHeaders
    )
    var allConnections = connections
    allConnections[newConnection.id] = newConnection
    connections = allConnections

    return newConnection.id
  }

  public func loginWithOIDC(
    serverURL: String, code: String, verifier: String, state: String?, cookies: [HTTPCookie],
    customHeaders: [String: String] = [:]
  ) async throws -> String {
    AppLogger.authentication.info("loginWithOIDC called for server: \(serverURL)")
    AppLogger.authentication.debug(
      "Request parameters - code length: \(code.count), verifier length: \(verifier.count), state: \(state ?? "nil"), cookies: \(cookies.count), custom headers: \(customHeaders.count)"
    )

    guard let baseURL = URL(string: serverURL) else {
      AppLogger.authentication.error("Invalid server URL: \(serverURL)")
      throw Audiobookshelf.AudiobookshelfError.invalidURL
    }

    let loginService = NetworkService(baseURL: baseURL)

    struct Response: Codable {
      struct User: Codable {
        let token: String
      }
      let user: User
    }

    var query: [String: String] = [
      "code": code,
      "code_verifier": verifier,
    ]

    if let state {
      query["state"] = state
    }

    let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    let headers = [
      "Cookie": cookieString
    ]

    AppLogger.authentication.info("Sending OIDC callback request to /auth/openid/callback")
    AppLogger.authentication.debug(
      "Query parameters: \(query.keys.joined(separator: ", "))")
    AppLogger.authentication.debug("Cookie header: \(cookieString)")

    let request = NetworkRequest<Response>(
      path: "/auth/openid/callback",
      method: .get,
      query: query,
      headers: headers
    )

    do {
      let response = try await loginService.send(request)
      let token = response.value.user.token

      AppLogger.authentication.info(
        "OIDC login successful, received token of length: \(token.count)")

      let newConnection = Connection(
        serverURL: baseURL,
        token: token,
        customHeaders: customHeaders
      )
      var allConnections = connections
      allConnections[newConnection.id] = newConnection
      connections = allConnections

      return newConnection.id
    } catch {
      AppLogger.authentication.error(
        "OIDC login request failed: \(error.localizedDescription)")
      if let error = error as? URLError {
        AppLogger.authentication.error("URLError code: \(error.code.rawValue)")
      }
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "OIDC login failed: \(error.localizedDescription)")
    }
  }

  public func switchToServer(_ serverID: String) throws {
    guard connections[serverID] != nil else {
      throw Audiobookshelf.AudiobookshelfError.networkError("Server not found")
    }
    activeServerID = serverID
  }

  public func updateAlias(_ serverID: String, alias: String?) {
    guard let connection = connections[serverID] else { return }
    var allConnections = connections
    allConnections[serverID] = Connection(
      id: connection.id,
      serverURL: connection.serverURL,
      token: connection.token,
      customHeaders: connection.customHeaders,
      alias: alias
    )
    connections = allConnections
  }

  public func removeServer(_ serverID: String) {
    var allConnections = connections
    allConnections.removeValue(forKey: serverID)
    connections = allConnections

    if activeServerID == serverID {
      activeServerID = nil
    }
  }

  public func logout(serverID: String) {
    removeServer(serverID)

    if activeServerID == serverID {
      permissions = nil
      audiobookshelf.libraries.current = nil
      ImagePipeline.shared.cache.removeAll()
      onAuthenticationChanged(nil)
    }
  }

  public func logoutAll() {
    connections = [:]
    activeServerID = nil
    permissions = nil
    audiobookshelf.libraries.current = nil
    ImagePipeline.shared.cache.removeAll()
    onAuthenticationChanged(nil)
  }

  public func fetchMe() async throws -> User {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    let request = NetworkRequest<User>(
      path: "/api/me",
      method: .get
    )

    do {
      let response = try await networkService.send(request)
      let user = response.value
      permissions = user.permissions
      return user
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to fetch user data: \(error.localizedDescription)")
    }
  }

  public func fetchListeningStats() async throws -> ListeningStats {
    guard let networkService = audiobookshelf.networkService else {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Network service not configured. Please login first.")
    }

    let request = NetworkRequest<ListeningStats>(
      path: "/api/me/listening-stats",
      method: .get
    )

    do {
      let response = try await networkService.send(request)
      return response.value
    } catch {
      throw Audiobookshelf.AudiobookshelfError.networkError(
        "Failed to fetch listening stats: \(error.localizedDescription)")
    }
  }
}
