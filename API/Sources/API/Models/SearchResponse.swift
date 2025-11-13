import Foundation

public struct SearchResponse: Decodable, Sendable {
  public let book: [SearchBook]
  public let series: [Series]
  public let authors: [Author]
  public let narrators: [Narrator]
  public let tags: [Tag]
  public let genres: [Genre]
}

extension SearchResponse {
  public struct SearchBook: Decodable, Sendable {
    public let libraryItem: Book
  }

  public struct Narrator: Codable, Sendable {
    public let name: String
    public let numBooks: Int
  }

  public struct Tag: Codable, Sendable {
    public let name: String
    public let numItems: Int
  }

  public struct Genre: Codable, Sendable {
    public let name: String
    public let numItems: Int
  }
}
