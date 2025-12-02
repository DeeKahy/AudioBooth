import Foundation

public class Connection: Codable, @unchecked Sendable {
  public let id: String
  public let serverURL: URL
  public var token: Credentials
  public let customHeaders: [String: String]
  public var alias: String?

  private lazy var credentialsActor = CredentialsActor(connection: self)

  public var freshToken: Credentials {
    get async throws {
      try await credentialsActor.freshCredentials
    }
  }

  public init(
    id: String? = nil,
    serverURL: URL,
    token: Credentials,
    customHeaders: [String: String] = [:],
    alias: String? = nil
  ) {
    self.id = id ?? UUID().uuidString
    self.serverURL = serverURL
    self.token = token
    self.customHeaders = customHeaders
    self.alias = alias
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
    serverURL = try container.decode(URL.self, forKey: .serverURL)
    token = try container.decode(Credentials.self, forKey: .token)
    customHeaders =
      try container.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:]
    alias = try container.decodeIfPresent(String.self, forKey: .alias)
  }
}

public enum Credentials: Codable, Sendable {
  case legacy(token: String)
  case bearer(accessToken: String, refreshToken: String, expiresAt: TimeInterval)

  enum CodingKeys: String, CodingKey {
    case type
    case token
    case accessToken
    case refreshToken
    case expiresAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let token = try? container.decode(String.self, forKey: .token) {
      self = .legacy(token: token)
    } else {
      let accessToken = try container.decode(String.self, forKey: .accessToken)
      let refreshToken = try container.decode(String.self, forKey: .refreshToken)
      let expiresAt = try container.decode(TimeInterval.self, forKey: .expiresAt)
      self = .bearer(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .legacy(let token):
      try container.encode(token, forKey: .token)
    case .bearer(let accessToken, let refreshToken, let expiresAt):
      try container.encode(accessToken, forKey: .accessToken)
      try container.encode(refreshToken, forKey: .refreshToken)
      try container.encode(expiresAt, forKey: .expiresAt)
    }
  }

  public var bearer: String {
    switch self {
    case .legacy(let token):
      return "Bearer \(token)"
    case .bearer(let accessToken, _, _):
      return "Bearer \(accessToken)"
    }
  }

  static func decodeJWT(_ jwt: String) -> TimeInterval? {
    let parts = jwt.split(separator: ".")
    guard parts.count == 3 else { return nil }

    let payload = String(parts[1])
    var base64 =
      payload
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let paddingLength = (4 - base64.count % 4) % 4
    base64 += String(repeating: "=", count: paddingLength)

    guard let data = Data(base64Encoded: base64) else { return nil }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }

    guard let exp = json["exp"] as? TimeInterval else { return nil }
    return exp
  }
}
