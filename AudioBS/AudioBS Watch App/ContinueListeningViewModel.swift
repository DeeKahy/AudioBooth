import Audiobookshelf
import Combine
import Foundation

final class ContinueListeningViewModel: ContinueListeningView.Model {
  override func fetch() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let personalized = try await Audiobookshelf.shared.libraries.fetchPersonalized()

      let continueListeningBooks =
        personalized.sections
        .first(where: { $0.id == "continue-listening" })
        .flatMap { section -> [Book]? in
          if case .books(let books) = section.entities {
            return books
          }
          return nil
        } ?? []

      let userData = try await Audiobookshelf.shared.authentication.fetchMe()
      let progressByBookID = Dictionary(
        uniqueKeysWithValues: userData.mediaProgress.map { ($0.libraryItemId, $0) }
      )

      let items = continueListeningBooks.map { book in
        let timeRemaining: Double
        if let progress = progressByBookID[book.id] {
          timeRemaining = max(0, book.duration - progress.currentTime)
        } else {
          timeRemaining = book.duration
        }

        return BookItem(
          id: book.id,
          title: book.title,
          author: book.authorName ?? "",
          coverURL: book.coverURL,
          timeRemaining: timeRemaining
        )
      }

      await MainActor.run {
        self.books = items
      }
    } catch {
      print("Failed to fetch continue listening: \(error)")
      await MainActor.run {
        self.books = []
      }
    }
  }
}
