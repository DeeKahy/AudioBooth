import OSLog

enum AppLogger {
  private static let subsystem = "me.jgrenier.AudioBS.models"

  static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
