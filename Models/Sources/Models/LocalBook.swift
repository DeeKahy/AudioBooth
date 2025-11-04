import API
@preconcurrency import Foundation
import SwiftData

@Model
public final class LocalBook {
  @Attribute(.unique) public var bookID: String
  public var title: String
  public var authors: [Author]
  public var narrators: [String]
  public var series: [Series]
  public var coverURL: URL?
  public var duration: TimeInterval
  public var tracks: [Track]
  public var chapters: [Chapter]
  public var publishedYear: String?

  public var authorNames: String {
    authors.map(\.name).joined(separator: ", ")
  }

  public init(
    bookID: String,
    title: String,
    authors: [Author] = [],
    narrators: [String] = [],
    series: [Series] = [],
    coverURL: URL? = nil,
    duration: TimeInterval,
    tracks: [Track] = [],
    chapters: [Chapter] = [],
    publishedYear: String? = nil
  ) {
    self.bookID = bookID
    self.title = title
    self.authors = authors
    self.narrators = narrators
    self.series = series
    self.coverURL = coverURL
    self.duration = duration
    self.tracks = tracks
    self.chapters = chapters
    self.publishedYear = publishedYear
  }
}

@MainActor
extension LocalBook {
  public static func fetchAll() throws -> [LocalBook] {
    let context = ModelContextProvider.shared.context
    let descriptor = FetchDescriptor<LocalBook>()
    return try context.fetch(descriptor)
  }

  public static func fetch(bookID: String) throws -> LocalBook? {
    let context = ModelContextProvider.shared.context
    let predicate = #Predicate<LocalBook> { item in
      item.bookID == bookID
    }
    let descriptor = FetchDescriptor<LocalBook>(predicate: predicate)
    return try context.fetch(descriptor).first
  }

  public func save() throws {
    let context = ModelContextProvider.shared.context

    if let existingItem = try LocalBook.fetch(bookID: self.bookID) {
      existingItem.title = self.title
      existingItem.authors = self.authors
      existingItem.narrators = self.narrators
      existingItem.series = self.series
      existingItem.coverURL = self.coverURL
      existingItem.duration = self.duration
      existingItem.chapters = self.chapters
      existingItem.publishedYear = self.publishedYear

      if self.tracks.isEmpty {
        existingItem.tracks = []
        try context.save()
        return
      }

      var mergedTracks: [Track] = []
      for newTrack in self.tracks {
        if let existingTrack = existingItem.tracks.first(where: { $0.index == newTrack.index }) {
          newTrack.relativePath = existingTrack.relativePath
        }
        mergedTracks.append(newTrack)
      }
      existingItem.tracks = mergedTracks
    } else {
      context.insert(self)
    }

    try context.save()
  }

  public func delete() throws {
    let context = ModelContextProvider.shared.context
    context.delete(self)
    try context.save()
  }

  public static func deleteAll() throws {
    let context = ModelContextProvider.shared.context
    let descriptor = FetchDescriptor<LocalBook>()
    let allItems = try context.fetch(descriptor)

    for item in allItems {
      context.delete(item)
    }

    try context.save()
  }

  public func track(at time: TimeInterval) -> Track? {
    let tracks = orderedTracks
    guard !tracks.isEmpty else { return nil }

    var currentTime: TimeInterval = 0
    for track in tracks {
      if time >= currentTime && time < currentTime + track.duration {
        return track
      }
      currentTime += track.duration
    }

    return nil
  }

  public var orderedChapters: [Chapter] {
    chapters.sorted(by: { $0.start < $1.start })
  }

  public var orderedTracks: [Track] {
    tracks.sorted(by: { $0.index < $1.index })
  }

  public var isDownloaded: Bool {
    guard !tracks.isEmpty else { return false }
    return tracks.allSatisfy { track in track.relativePath != nil }
  }

  public convenience init(from book: Book) {
    let authors =
      book.media.metadata.authors?.map { apiAuthor in
        Author(id: apiAuthor.id, name: apiAuthor.name)
      } ?? []

    let series =
      book.media.metadata.series?.map { apiSeries in
        Series(id: apiSeries.id, name: apiSeries.name, sequence: apiSeries.sequence)
      } ?? []

    let narrators = book.media.metadata.narrators ?? []

    self.init(
      bookID: book.id,
      title: book.title,
      authors: authors,
      narrators: narrators,
      series: series,
      coverURL: book.coverURL,
      duration: book.duration,
      tracks: book.tracks?.map(Track.init) ?? [],
      chapters: book.chapters?.map(Chapter.init) ?? [],
      publishedYear: book.publishedYear
    )
  }
}

extension Array where Element == LocalBook {
  public func sorted(current: String?) -> [LocalBook] {
    let currentBook = first { $0.bookID == current }
    let currentSeriesID = currentBook?.series.first?.id
    let currentSequence = currentBook?.series.first?.sequence

    return sorted { book1, book2 in
      let series1 = book1.series.first
      let series2 = book2.series.first

      guard let s1 = series1 else { return false }
      guard let s2 = series2 else { return true }

      let isBook1InCurrentSeries = s1.id == currentSeriesID
      let isBook2InCurrentSeries = s2.id == currentSeriesID

      if isBook1InCurrentSeries && !isBook2InCurrentSeries {
        return true
      }
      if !isBook1InCurrentSeries && isBook2InCurrentSeries {
        return false
      }

      if isBook1InCurrentSeries && isBook2InCurrentSeries, let currentSeq = currentSequence {
        let seq1Value = Double(s1.sequence) ?? 0
        let seq2Value = Double(s2.sequence) ?? 0
        let currentSeqValue = Double(currentSeq) ?? 0

        let isBook1CurrentOrAfter = seq1Value >= currentSeqValue
        let isBook2CurrentOrAfter = seq2Value >= currentSeqValue

        if isBook1CurrentOrAfter && isBook2CurrentOrAfter {
          return seq1Value < seq2Value
        }

        if !isBook1CurrentOrAfter && !isBook2CurrentOrAfter {
          return seq1Value > seq2Value
        }

        return isBook1CurrentOrAfter
      }

      if s1.name != s2.name {
        return s1.name < s2.name
      }

      let seq1Value = Double(s1.sequence) ?? 0
      let seq2Value = Double(s2.sequence) ?? 0
      return seq1Value < seq2Value
    }
  }
}
