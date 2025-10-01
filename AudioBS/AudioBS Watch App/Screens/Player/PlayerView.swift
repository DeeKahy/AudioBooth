import Combine
import NukeUI
import SwiftUI

struct PlayerView: View {
  @StateObject var model: Model

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        CoverArtView(coverURL: model.coverURL)

        TitleAuthorView(title: model.title, author: model.author)

        if let chapterTitle = model.currentChapterTitle {
          ChapterView(title: chapterTitle)
        }

        PlaybackProgressView(
          progress: model.hasChapters ? model.chapterProgress : model.progress,
          current: model.hasChapters ? model.chapterCurrent : model.current,
          remaining: model.hasChapters ? model.chapterRemaining : model.remaining,
          totalTimeRemaining: model.totalTimeRemaining,
          label: model.hasChapters ? "Chapter" : "Book"
        )

        PlaybackControlsView(
          isPlaying: model.isPlaying,
          hasChapters: model.hasChapters,
          onTogglePlayback: { model.togglePlayback() },
          onSkipBackward: { model.skipBackward() },
          onSkipForward: { model.skipForward() },
          onPreviousChapter: { model.previousChapter() },
          onNextChapter: { model.nextChapter() }
        )

        PlaybackSpeedView(playbackSpeed: model.playbackSpeed)

        if model.hasChapters {
          Button(action: { model.showChapterPicker() }) {
            Label("All Chapters", systemImage: "list.bullet")
              .font(.caption)
          }
          .buttonStyle(.borderedProminent)
          .tint(.orange)
        }
      }
      .padding()
    }
    .navigationTitle("Playing")
    .sheet(item: $model.chapters) { chapters in
      NavigationStack {
        if let chapters = Binding($model.chapters) {
          ChapterPickerSheet(model: chapters)
        }
      }
    }
  }
}

extension PlayerView {
  private struct CoverArtView: View {
    let coverURL: URL?

    var body: some View {
      if let coverURL {
        LazyImage(url: coverURL) { state in
          if let image = state.image {
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } else {
            Color.gray
          }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}

extension PlayerView {
  private struct TitleAuthorView: View {
    let title: String
    let author: String

    var body: some View {
      VStack(spacing: 4) {
        Text(title)
          .font(.headline)
          .lineLimit(2)
          .multilineTextAlignment(.center)

        if !author.isEmpty {
          Text(author)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
  }
}

extension PlayerView {
  private struct ChapterView: View {
    let title: String

    var body: some View {
      Text(title)
        .font(.caption)
        .foregroundStyle(.orange)
        .lineLimit(1)
        .padding(.horizontal)
    }
  }
}

extension PlayerView {
  struct PlaybackProgressView: View {
    let progress: Double
    let current: Double
    let remaining: Double
    let totalTimeRemaining: Double
    let label: String

    var body: some View {
      VStack(spacing: 4) {
        ProgressView(value: progress, total: 1.0)

        HStack {
          Text(formatTime(current))
            .font(.caption2)
            .foregroundStyle(.secondary)

          Spacer()

          Text("-\(formatTime(remaining))")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .monospacedDigit()

        Text("\(formatTimeRemaining(totalTimeRemaining)) (\(label))")
          .font(.caption2)
          .fontWeight(.medium)
      }
    }

    private func formatTime(_ seconds: Double) -> String {
      Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }

    private func formatTimeRemaining(_ duration: Double) -> String {
      Duration.seconds(duration).formatted(
        .units(
          allowed: [.hours, .minutes],
          width: .narrow
        )
      ) + " left"
    }
  }
}

extension PlayerView {
  private struct PlaybackControlsView: View {
    let isPlaying: Bool
    let hasChapters: Bool
    let onTogglePlayback: () -> Void
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void

    var body: some View {
      VStack(spacing: 12) {
        HStack(spacing: 20) {
          Button(action: onSkipBackward) {
            Image(systemName: "gobackward.30")
              .font(.title2)
          }
          .buttonStyle(.plain)

          Button(action: onTogglePlayback) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
              .font(.title)
          }
          .buttonStyle(.plain)

          Button(action: onSkipForward) {
            Image(systemName: "goforward.30")
              .font(.title2)
          }
          .buttonStyle(.plain)
        }

        // Chapter navigation (if chapters exist)
        if hasChapters {
          HStack(spacing: 32) {
            Button(action: onPreviousChapter) {
              Label("Previous", systemImage: "backward.end.fill")
                .labelStyle(.iconOnly)
                .font(.caption)
            }
            .buttonStyle(.plain)

            Text("Chapters")
              .font(.caption2)
              .foregroundStyle(.secondary)

            Button(action: onNextChapter) {
              Label("Next", systemImage: "forward.end.fill")
                .labelStyle(.iconOnly)
                .font(.caption)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.top, 8)
    }
  }
}

extension PlayerView {
  private struct PlaybackSpeedView: View {
    let playbackSpeed: Float

    var body: some View {
      if playbackSpeed != 1.0 {
        Text("\(playbackSpeed, specifier: "%.1f")x")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

extension PlayerView {
  @Observable class Model: ObservableObject {
    var isPlaying: Bool
    var progress: Double
    var current: Double
    var remaining: Double
    var total: Double
    var totalTimeRemaining: Double
    var bookID: String
    var title: String
    var author: String
    var coverURL: URL?
    var playbackSpeed: Float
    var hasActivePlayer: Bool

    var currentChapterTitle: String?
    var chapterProgress: Double
    var chapterCurrent: Double
    var chapterRemaining: Double
    var hasChapters: Bool
    var chapters: ChapterPickerSheet.Model?

    func togglePlayback() {}
    func skipBackward() {}
    func skipForward() {}
    func previousChapter() {}
    func nextChapter() {}
    func showChapterPicker() {}

    init(
      isPlaying: Bool = false,
      progress: Double = 0,
      current: Double = 0,
      remaining: Double = 0,
      total: Double = 0,
      totalTimeRemaining: Double = 0,
      bookID: String = "",
      title: String = "",
      author: String = "",
      coverURL: URL? = nil,
      playbackSpeed: Float = 1.0,
      hasActivePlayer: Bool = false,
      currentChapterTitle: String? = nil,
      chapterProgress: Double = 0,
      chapterCurrent: Double = 0,
      chapterRemaining: Double = 0,
      hasChapters: Bool = false,
      chapters: ChapterPickerSheet.Model? = nil
    ) {
      self.isPlaying = isPlaying
      self.progress = progress
      self.current = current
      self.remaining = remaining
      self.total = total
      self.totalTimeRemaining = totalTimeRemaining
      self.bookID = bookID
      self.title = title
      self.author = author
      self.coverURL = coverURL
      self.playbackSpeed = playbackSpeed
      self.hasActivePlayer = hasActivePlayer
      self.currentChapterTitle = currentChapterTitle
      self.chapterProgress = chapterProgress
      self.chapterCurrent = chapterCurrent
      self.chapterRemaining = chapterRemaining
      self.hasChapters = hasChapters
      self.chapters = chapters
    }
  }
}

#Preview {
  NavigationStack {
    PlayerView(
      model: PlayerView.Model(
        isPlaying: true,
        progress: 0.45,
        current: 1800,
        remaining: 2200,
        total: 4000,
        totalTimeRemaining: 38000,
        bookID: "1",
        title: "The Lord of the Rings",
        author: "J.R.R. Tolkien",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/51YHc7SK5HL._SL500_.jpg"),
        playbackSpeed: 1.2,
        hasActivePlayer: true
      )
    )
  }
}
