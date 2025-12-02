import Foundation
import Logging
import PulseLogHandler

enum AppLogger {
  static func bootstrap() {
    LoggingSystem.bootstrap { label in
      MultiplexLogHandler([
        StreamLogHandler.standardOutput(label: label),
        PersistentLogHandler(label: label),
      ])
    }
  }

  static let session = Logger(label: "session")
  static let network = Logger(label: "network")
  static let watchConnectivity = Logger(label: "watch-connectivity")
  static let player = Logger(label: "player")
  static let download = Logger(label: "download")
  static let viewModel = Logger(label: "viewModel")
  static let persistence = Logger(label: "persistence")
  static let general = Logger(label: "general")
  static let authentication = Logger(label: "authentication")
}
