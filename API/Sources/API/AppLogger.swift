import Logging

enum AppLogger {
  static let network = Logger(label: "api.network")
  static let authentication = Logger(label: "api.authentication")
  static let libraries = Logger(label: "api.libraries")
  static let persistence = Logger(label: "api.persistence")
  static let download = Logger(label: "api.download")
}
