import Foundation
import OSLog
import Pulse

enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"
}

enum NetworkError: LocalizedError {
  case httpError(statusCode: Int, message: String?)
  case invalidResponse
  case decodingError(Error)

  var errorDescription: String? {
    switch self {
    case .httpError(let statusCode, let message):
      switch statusCode {
      case 401:
        return "Invalid username or password. Please check your credentials and try again."
      case 403:
        return "Access forbidden. Please check your credentials."
      case 404:
        return "Server not found. Please check the server URL and try again."
      case 500...599:
        return "Server error. Please try again later or contact your server administrator."
      default:
        return message ?? "HTTP error \(statusCode)"
      }
    case .invalidResponse:
      return "Invalid server response"
    case .decodingError(let error):
      return "Failed to decode server response: \(error.localizedDescription)"
    }
  }
}

struct NetworkRequest<T: Decodable> {
  let path: String
  let method: HTTPMethod
  let body: (any Encodable)?
  let query: [String: String]?
  let headers: [String: String]?
  let timeout: TimeInterval?
  let discretionary: Bool

  init(
    path: String, method: HTTPMethod = .get, body: (any Encodable)? = nil,
    query: [String: String]? = nil, headers: [String: String]? = nil, timeout: TimeInterval? = nil,
    discretionary: Bool = false
  ) {
    self.path = path
    self.method = method
    self.body = body
    self.query = query
    self.headers = headers
    self.timeout = timeout
    self.discretionary = discretionary
  }
}

struct NetworkResponse<T: Decodable> {
  let value: T
}

final class NetworkService {
  private let baseURL: URL
  private let headersProvider: () -> [String: String]

  private let session: URLSessionProtocol = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 60

    #if os(watchOS)
      config.timeoutIntervalForResource = 300
      config.allowsExpensiveNetworkAccess = true
      config.allowsConstrainedNetworkAccess = true
      config.allowsCellularAccess = true
    #endif

    return URLSessionProxy(configuration: config)
  }()

  private let discretionarySession: URLSessionProtocol = {
    let discretionaryConfig = URLSessionConfiguration.default
    discretionaryConfig.timeoutIntervalForRequest = 30
    discretionaryConfig.timeoutIntervalForResource = 60

    #if os(watchOS)
      discretionaryConfig.timeoutIntervalForResource = 300
      discretionaryConfig.allowsExpensiveNetworkAccess = true
      discretionaryConfig.allowsConstrainedNetworkAccess = true
      discretionaryConfig.allowsCellularAccess = true
      discretionaryConfig.waitsForConnectivity = true
    #endif

    #if os(iOS)
      discretionaryConfig.sessionSendsLaunchEvents = true
      discretionaryConfig.isDiscretionary = true
      discretionaryConfig.shouldUseExtendedBackgroundIdleMode = true
    #endif

    return URLSessionProxy(configuration: discretionaryConfig)
  }()

  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let timestamp = try container.decode(Int64.self)
      return Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
    }
    return decoder
  }()

  init(baseURL: URL, headersProvider: @escaping () -> [String: String] = { [:] }) {
    self.baseURL = baseURL
    self.headersProvider = headersProvider
  }

  func send<T: Decodable>(_ request: NetworkRequest<T>) async throws -> NetworkResponse<T> {
    let urlRequest = try buildURLRequest(from: request)

    AppLogger.network.info(
      "Sending \(urlRequest.httpMethod ?? "GET", privacy: .public) request to: \(urlRequest.url?.absoluteString ?? "unknown", privacy: .public)"
    )

    let selectedSession = request.discretionary ? discretionarySession : session
    let (data, response) = try await selectedSession.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      AppLogger.network.error("Received non-HTTP response")
      throw NetworkError.invalidResponse
    }

    AppLogger.network.info("Received HTTP \(httpResponse.statusCode, privacy: .public) response")

    guard 200...299 ~= httpResponse.statusCode else {
      let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body"
      AppLogger.network.error(
        "HTTP \(httpResponse.statusCode, privacy: .public) error. Response body: \(responseBody, privacy: .public)"
      )
      throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: responseBody)
    }

    let decodedValue: T
    if T.self == Data.self {
      decodedValue = data as! T
    } else if data.isEmpty {
      throw NetworkError.decodingError(URLError(.cannotDecodeContentData))
    } else {
      do {
        decodedValue = try decoder.decode(T.self, from: data)
      } catch {
        AppLogger.network.error(
          "Failed to decode \(T.self, privacy: .public): \(error, privacy: .public)")

        if let decodingError = error as? DecodingError {
          switch decodingError {
          case .keyNotFound(let key, let context):
            AppLogger.network.error(
              "  Missing key: '\(key.stringValue, privacy: .public)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."), privacy: .public)"
            )
          case .typeMismatch(let type, let context):
            AppLogger.network.error(
              "  Type mismatch: expected \(type, privacy: .public) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."), privacy: .public)"
            )
            AppLogger.network.error("  Context: \(context.debugDescription, privacy: .public)")
          case .valueNotFound(let type, let context):
            AppLogger.network.error(
              "  Value not found: expected \(type, privacy: .public) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."), privacy: .public)"
            )
            AppLogger.network.error("  Context: \(context.debugDescription, privacy: .public)")
          case .dataCorrupted(let context):
            AppLogger.network.error(
              "  Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."), privacy: .public)"
            )
            AppLogger.network.error("  Context: \(context.debugDescription, privacy: .public)")
          @unknown default:
            AppLogger.network.error("  Unknown decoding error")
          }
        }

        throw NetworkError.decodingError(error)
      }
    }
    return NetworkResponse(value: decodedValue)
  }

  private func buildURLRequest<T: Decodable>(from request: NetworkRequest<T>) throws -> URLRequest {
    var url = baseURL.appendingPathComponent(request.path)

    if let query = request.query {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
      if let updatedURL = components?.url {
        url = updatedURL
      }
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    for (key, value) in headersProvider() {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    if let headers = request.headers {
      for (key, value) in headers {
        urlRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    if let timeout = request.timeout {
      urlRequest.timeoutInterval = timeout
    }

    if let body = request.body {
      urlRequest.httpBody = try JSONEncoder().encode(body)
    }

    return urlRequest
  }
}
