import Combine
import Foundation
import Models

final class LocalPlayerViewModel: PlayerView.Model {
  private var cancellables = Set<AnyCancellable>()
  private let playerManager = PlayerManager.shared

  init() {
    super.init()
    setupBindings()
  }

  private func setupBindings() {
    playerManager.$current
      .sink { [weak self] currentPlayer in
        guard let self = self else { return }

        if let player = currentPlayer {
          self.setupPlayerBindings(player)
          self.hasActivePlayer = true
        } else {
          self.hasActivePlayer = false
        }
      }
      .store(in: &cancellables)
  }

  private func setupPlayerBindings(_ player: BookPlayerModel) {
    cancellables.removeAll()

    player.$isPlaying
      .assign(to: \.isPlaying, on: self)
      .store(in: &cancellables)

    player.$progress
      .assign(to: \.progress, on: self)
      .store(in: &cancellables)

    player.$current
      .assign(to: \.current, on: self)
      .store(in: &cancellables)

    player.$remaining
      .assign(to: \.remaining, on: self)
      .store(in: &cancellables)

    player.$total
      .assign(to: \.total, on: self)
      .store(in: &cancellables)

    player.$totalTimeRemaining
      .assign(to: \.totalTimeRemaining, on: self)
      .store(in: &cancellables)

    player.$chapterProgress
      .assign(to: \.chapterProgress, on: self)
      .store(in: &cancellables)

    player.$chapterCurrent
      .assign(to: \.chapterCurrent, on: self)
      .store(in: &cancellables)

    player.$chapterRemaining
      .assign(to: \.chapterRemaining, on: self)
      .store(in: &cancellables)

    player.$currentChapter
      .map { $0?.title }
      .assign(to: \.currentChapterTitle, on: self)
      .store(in: &cancellables)

    player.$currentChapter
      .map { $0 != nil }
      .assign(to: \.hasChapters, on: self)
      .store(in: &cancellables)

    bookID = player.id
    title = player.title
    author = player.author ?? ""
    coverURL = player.coverURL
    playbackSpeed = 1.0
  }

  override func togglePlayback() {
    guard let player = playerManager.current else { return }
    player.onTogglePlaybackTapped()
  }

  override func skipBackward() {
    guard let player = playerManager.current else { return }
    player.onSkipBackwardTapped()
  }

  override func skipForward() {
    guard let player = playerManager.current else { return }
    player.onSkipForwardTapped()
  }

  override func previousChapter() {
    guard let player = playerManager.current else { return }
    player.onPreviousChapterTapped()
  }

  override func nextChapter() {
    guard let player = playerManager.current else { return }
    player.onNextChapterTapped()
  }

  override func showChapterPicker() {
    guard let player = playerManager.current else { return }
    chapters = ChapterPickerSheetViewModel(player: player)
  }
}
