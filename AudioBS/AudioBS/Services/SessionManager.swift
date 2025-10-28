import API
import BackgroundTasks
import Foundation
import MediaPlayer
import Models
import OSLog

final class SessionManager {
  static let shared = SessionManager()

  private let taskIdentifier = "me.jgrenier.AudioBS.close-session"
  private let sessionIDKey = "activeSessionID"
  private let inactivityTimeout: TimeInterval = 10 * 60
  private let audiobookshelf = Audiobookshelf.shared

  private(set) var current: Session?
  private var lastSyncAt = Date()
  private var inactivityTask: Task<Void, Never>?

  private init() {
    registerBackgroundTask()
  }

  func startSession(
    itemID: String,
    item: LocalBook?,
    mediaProgress: MediaProgress
  ) async throws -> (session: Session, updatedItem: LocalBook?, serverCurrentTime: TimeInterval) {
    AppLogger.session.info("Fetching session from server...")

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
      AppLogger.session.debug("Updated session with chapters")
    } else {
      let newItem = LocalBook(from: audiobookshelfSession.libraryItem)
      try? newItem.save()
      updatedItem = newItem
      AppLogger.session.debug("Created new item from session")
    }

    AppLogger.session.info("Session setup completed successfully")
    return (session, updatedItem, audiobookshelfSession.currentTime)
  }

  func closeSession(
    timeListened: TimeInterval = 0,
    currentTime: TimeInterval = 0
  ) async {
    let sessionID = current?.id ?? UserDefaults.standard.string(forKey: sessionIDKey)

    guard let sessionID else {
      AppLogger.session.debug("Session already closed or no session to close")
      return
    }

    if timeListened > 0, let session = current {
      do {
        try await audiobookshelf.sessions.sync(
          session.id,
          timeListened: timeListened,
          currentTime: currentTime
        )
        AppLogger.session.debug("Synced final progress before closing session")
      } catch {
        AppLogger.session.error("Failed to sync session progress before close: \(error)")
      }
    }

    do {
      try await audiobookshelf.sessions.close(sessionID)
      AppLogger.session.info("Successfully closed session: \(sessionID)")
      current = nil
      UserDefaults.standard.removeObject(forKey: sessionIDKey)
      cancelScheduledSessionClose()
    } catch {
      AppLogger.session.error("Failed to close session: \(error)")
    }
  }

  func ensureSession(
    itemID: String,
    item: LocalBook?,
    mediaProgress: MediaProgress
  ) async throws -> (session: Session, updatedItem: LocalBook?, serverCurrentTime: TimeInterval) {
    if let existingSession = current, existingSession.itemID == itemID {
      AppLogger.session.debug(
        "Session already exists for this book, reusing: \(existingSession.id)")
      return (existingSession, item, mediaProgress.currentTime)
    }

    if current != nil {
      AppLogger.session.info(
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
    ) { [weak self] task in
      AppLogger.session.debug("Task triggered")
      self?.handleBackgroundTask(task as! BGAppRefreshTask)
    }

    if success {
      AppLogger.session.info(
        "Background task handler registered successfully for: \(self.taskIdentifier)")
    } else {
      AppLogger.session.warning(
        "Failed to register background task handler for: \(self.taskIdentifier)")
      AppLogger.session.debug(
        "Note: This is normal if registration was already done, or if running in certain environments"
      )
    }
  }

  private func scheduleSessionClose() {
    guard let sessionID = current?.id else {
      AppLogger.session.warning("Cannot schedule session close - no active session")
      return
    }

    UserDefaults.standard.set(sessionID, forKey: sessionIDKey)

    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: inactivityTimeout)

    do {
      try BGTaskScheduler.shared.submit(request)
      AppLogger.session.info(
        "Scheduled background task to close session \(sessionID) after \(self.inactivityTimeout)s")
    } catch let error as NSError {
      if error.code == 1 {
        AppLogger.session.warning(
          "Background tasks unavailable (Background App Refresh may be disabled). Session will close on foreground instead."
        )
      } else {
        AppLogger.session.error("Failed to schedule background task: \(error)")
      }
    }
  }

  private func cancelScheduledSessionClose() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    UserDefaults.standard.removeObject(forKey: sessionIDKey)
    AppLogger.session.debug("Canceled scheduled session close background task")
  }

  private func handleBackgroundTask(_ task: BGAppRefreshTask) {
    AppLogger.session.info("Background task executing - checking if session should be closed")

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
    cancelInactivityTask()
  }

  func notifyPlaybackStopped() {
    AppLogger.session.debug("Playback stopped - starting inactivity countdown")
    startInactivityTask()
  }

  func notifyPlaybackStarted() {
    AppLogger.session.debug("Playback started - canceling inactivity countdown")
    cancelInactivityTask()
  }

  private func startInactivityTask() {
    cancelInactivityTask()

    inactivityTask = Task {
      do {
        try await Task.sleep(for: .seconds(inactivityTimeout))

        guard !Task.isCancelled else {
          AppLogger.session.debug("Inactivity task was cancelled")
          return
        }

        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let playbackRate = nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0

        if playbackRate > 0 {
          AppLogger.session.info(
            "Inactivity timeout reached but playback is active - not closing session")
          return
        }

        AppLogger.session.info("Inactivity timeout reached - closing session")
        await closeSession()
      } catch {
        AppLogger.session.debug("Inactivity task sleep was interrupted: \(error)")
      }
    }
  }

  private func cancelInactivityTask() {
    inactivityTask?.cancel()
    inactivityTask = nil
  }

  enum SessionError: Error {
    case noActiveSession
    case failedToCreateSession
  }
}
