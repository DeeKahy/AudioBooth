import OSLog

enum AppLogger {
  private static let subsystem = "me.jgrenier.AudioBS.api"

  static let network = Logger(subsystem: subsystem, category: "network")
  static let authentication = Logger(subsystem: subsystem, category: "authentication")
  static let libraries = Logger(subsystem: subsystem, category: "libraries")
  static let persistence = Logger(subsystem: subsystem, category: "persistence")
  static let download = Logger(subsystem: subsystem, category: "download")
}
