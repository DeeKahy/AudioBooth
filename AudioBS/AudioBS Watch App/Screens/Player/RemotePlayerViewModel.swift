import Combine
import Foundation

final class RemotePlayerViewModel: PlayerView.Model {
  private var cancellables = Set<AnyCancellable>()
  private let connectivityManager = WatchConnectivityManager.shared

  init() {
    super.init()
    setupBindings()
  }

  private func setupBindings() {
    connectivityManager.$isPlaying
      .assign(to: \.isPlaying, on: self)
      .store(in: &cancellables)

    connectivityManager.$progress
      .assign(to: \.progress, on: self)
      .store(in: &cancellables)

    connectivityManager.$current
      .assign(to: \.current, on: self)
      .store(in: &cancellables)

    connectivityManager.$remaining
      .assign(to: \.remaining, on: self)
      .store(in: &cancellables)

    connectivityManager.$total
      .assign(to: \.total, on: self)
      .store(in: &cancellables)

    connectivityManager.$totalTimeRemaining
      .assign(to: \.totalTimeRemaining, on: self)
      .store(in: &cancellables)

    connectivityManager.$bookID
      .assign(to: \.bookID, on: self)
      .store(in: &cancellables)

    connectivityManager.$title
      .assign(to: \.title, on: self)
      .store(in: &cancellables)

    connectivityManager.$author
      .assign(to: \.author, on: self)
      .store(in: &cancellables)

    connectivityManager.$coverURL
      .assign(to: \.coverURL, on: self)
      .store(in: &cancellables)

    connectivityManager.$playbackSpeed
      .assign(to: \.playbackSpeed, on: self)
      .store(in: &cancellables)

    connectivityManager.$hasActivePlayer
      .assign(to: \.hasActivePlayer, on: self)
      .store(in: &cancellables)

    // Remote playback doesn't support chapters (iPhone doesn't send chapter info)
    hasChapters = false
    currentChapterTitle = nil
  }

  override func togglePlayback() {
    connectivityManager.togglePlayback()
  }

  override func skipBackward() {
    connectivityManager.skipBackward()
  }

  override func skipForward() {
    connectivityManager.skipForward()
  }

  // Chapter navigation not supported for remote playback
  override func previousChapter() {}
  override func nextChapter() {}
  override func showChapterPicker() {}
}
