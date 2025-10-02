import Foundation
import Models

final class ChapterPickerSheetViewModel: ChapterPickerSheet.Model {
  private weak var player: LocalPlayerModel?

  init(player: LocalPlayerModel) {
    self.player = player

    let chapters = (player.item.playSessionInfo.orderedChapters ?? []).map { chapterInfo in
      ChapterPickerSheet.Model.Chapter(
        id: chapterInfo.id,
        title: chapterInfo.title,
        start: chapterInfo.start,
        end: chapterInfo.end
      )
    }

    super.init(chapters: chapters, currentIndex: player.currentChapterIndex)
  }

  override func onChapterTapped(at index: Int) {
    guard let player = player else { return }
    player.seekToChapter(at: index)
    currentIndex = index
  }
}
