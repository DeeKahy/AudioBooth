import API
import Foundation
import Models

final class ContinueListeningRowModel: ContinueListeningRow.Model {
  enum Item {
    case local(LocalBook)
    case remote(Book)
  }

  private let item: Item
  private let playerManager = PlayerManager.shared

  init(_ localBook: LocalBook, timeRemaining: Double) {
    self.item = .local(localBook)

    let timeRemainingText: String?
    if timeRemaining > 0 {
      timeRemainingText =
        Duration.seconds(timeRemaining).formatted(
          .units(
            allowed: [.hours, .minutes],
            width: .narrow
          )
        ) + " left"
    } else {
      timeRemainingText = nil
    }

    super.init(
      id: localBook.bookID,
      title: localBook.title,
      author: localBook.authorNames,
      coverURL: localBook.coverURL,
      timeRemaining: timeRemainingText
    )
  }

  init(_ book: Book, timeRemaining: Double, isDownloaded: Bool) {
    self.item = .remote(book)

    let timeRemainingText: String?
    if timeRemaining > 0 {
      timeRemainingText =
        Duration.seconds(timeRemaining).formatted(
          .units(
            allowed: [.hours, .minutes],
            width: .narrow
          )
        ) + " left"
    } else {
      timeRemainingText = nil
    }

    super.init(
      id: book.id,
      title: book.title,
      author: book.authorName,
      coverURL: book.coverURL,
      timeRemaining: timeRemainingText
    )
  }

  override func onTapped() {
    switch item {
    case .local(let localBook):
      playerManager.setCurrent(localBook)
    case .remote(let book):
      playerManager.setCurrent(book)
    }
    playerManager.isShowingFullPlayer = true
  }
}
