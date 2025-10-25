import API
import BackgroundTasks
import Foundation
import MediaPlayer
import Models

final class SessionManager {
  static let shared = SessionManager()

  private let taskIdentifier = "me.jgrenier.AudioBS.close-session"
  private let sessionIDKey = "activeSessionID"
  private let inactivityTimeout: TimeInterval = 10 * 60
  private let audiobookshelf = Audiobookshelf.shared

  private(set) var current: Session?
  private var lastSyncAt = Date()

  private init() {
    registerBackgroundTask()
  }

  func startSession(
    itemID: String,
    item: LocalBook?,
    mediaProgress: MediaProgress
  ) async throws -> (session: Session, updatedItem: LocalBook?, serverCurrentTime: TimeInterval) {
    print("Fetching session from server...")

    let audiobookshelfSession = try await audiobookshelf.sessions.start(
      itemID: itemID,
      forceTranscode: false
    )

    guard let session = Session(from: audiobookshelfSession) else {
      throw SessionError.failedToCreateSession
    }

    current = session
    scheduleSessionClose()

    var updatedItem = item

    if let item {
      item.chapters = audiobookshelfSession.chapters?.map(Chapter.init) ?? []

      try? MediaProgress.updateProgress(
        for: item.bookID,
        currentTime: mediaProgress.currentTime,
        timeListened: mediaProgress.timeListened,
        duration: item.duration,
        progress: mediaProgress.currentTime / item.duration
      )
      updatedItem = item
      print("Updated session with chapters")
    } else {
      let newItem = LocalBook(from: audiobookshelfSession.libraryItem)
      try? newItem.save()
      updatedItem = newItem
      print("Created new item from session")
    }

    print("Session setup completed successfully")
    return (session, updatedItem, audiobookshelfSession.currentTime)
  }

  func closeSession(
    timeListened: TimeInterval = 0,
    currentTime: TimeInterval = 0
  ) async {
    let sessionID = current?.id ?? UserDefaults.standard.string(forKey: sessionIDKey)

    guard let sessionID else {
      print("Session already closed or no session to close")
      return
    }

    if timeListened > 0, let session = current {
      do {
        try await audiobookshelf.sessions.sync(
          session.id,
          timeListened: timeListened,
          currentTime: currentTime
        )
        print("Synced final progress before closing session")
      } catch {
        print("Failed to sync session progress before close: \(error)")
      }
    }

    do {
      try await audiobookshelf.sessions.close(sessionID)
      print("Successfully closed session: \(sessionID)")
      current = nil
      UserDefaults.standard.removeObject(forKey: sessionIDKey)
      cancelScheduledSessionClose()
    } catch {
      print("Failed to close session: \(error)")
    }
  }

  func ensureSession(
    itemID: String,
    item: LocalBook?,
    mediaProgress: MediaProgress
  ) async throws -> (session: Session, updatedItem: LocalBook?, serverCurrentTime: TimeInterval) {
    if let existingSession = current, existingSession.itemID == itemID {
      print("Session already exists for this book, reusing: \(existingSession.id)")
      return (existingSession, item, mediaProgress.currentTime)
    }

    if current != nil {
      print(
        "Session exists for different book, server will close old session when starting new one")
      current = nil
      cancelScheduledSessionClose()
    }

    return try await startSession(itemID: itemID, item: item, mediaProgress: mediaProgress)
  }

  func syncProgress(
    timeListened: TimeInterval,
    currentTime: TimeInterval
  ) async throws -> Bool {
    guard let session = current else {
      throw SessionError.noActiveSession
    }

    let now = Date()
    guard timeListened >= 20, now.timeIntervalSince(lastSyncAt) >= 10 else {
      return false
    }

    lastSyncAt = now

    try await audiobookshelf.sessions.sync(
      session.id,
      timeListened: timeListened,
      currentTime: currentTime
    )

    scheduleSessionClose()

    return true
  }

  private func registerBackgroundTask() {
    let success = BGTaskScheduler.shared.register(
      forTaskWithIdentifier: taskIdentifier,
      using: nil
    ) { task in
      print("Task triggered")
      self.handleBackgroundTask(task as! BGAppRefreshTask)
    }

    if success {
      print("✅ Background task handler registered successfully for: \(taskIdentifier)")
    } else {
      print("❌ Failed to register background task handler for: \(taskIdentifier)")
      print(
        "   Note: This is normal if registration was already done, or if running in certain environments"
      )
    }
  }

  private func scheduleSessionClose() {
    guard let sessionID = current?.id else {
      print("⚠️ Cannot schedule session close - no active session")
      return
    }

    UserDefaults.standard.set(sessionID, forKey: sessionIDKey)

    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: inactivityTimeout)

    do {
      try BGTaskScheduler.shared.submit(request)
      print("✅ Scheduled background task to close session \(sessionID) after \(inactivityTimeout)s")
    } catch let error as NSError {
      if error.code == 1 {
        print(
          "⚠️ Background tasks unavailable (Background App Refresh may be disabled). Session will close on foreground instead."
        )
      } else {
        print("❌ Failed to schedule background task: \(error)")
      }
    }
  }

  private func cancelScheduledSessionClose() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    UserDefaults.standard.removeObject(forKey: sessionIDKey)
    print("Canceled scheduled session close background task")
  }

  private func handleBackgroundTask(_ task: BGAppRefreshTask) {
    print("Background task executing - checking if session should be closed")

    let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
    let playbackRate = nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0

    if playbackRate > 0 {
      AppLogger.session.info("Playback is still active, rescheduling session close")
      scheduleSessionClose()
      task.setTaskCompleted(success: false)
    } else {
      AppLogger.session.info("Playback is not active, closing session")
      Task {
        await closeSession()
        task.setTaskCompleted(success: true)
      }
    }
  }

  func clearSession() {
    current = nil
    cancelScheduledSessionClose()
  }

  enum SessionError: Error {
    case noActiveSession
    case failedToCreateSession
  }
}
