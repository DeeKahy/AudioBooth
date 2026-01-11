import API
import Foundation
import Nuke

final class StorageManager {
  static let shared = StorageManager()

  private init() {}

  func getDownloadedContentSize() async -> Int64 {
    guard
      let appGroupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.me.jgrenier.audioBS"
      )
    else {
      return 0
    }

    var totalSize: Int64 = 0

    do {
      let directories = try FileManager.default.contentsOfDirectory(
        at: appGroupURL,
        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )

      for directory in directories {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
          totalSize += calculateDirectorySize(at: directory)
        }
      }
    } catch {
      return 0
    }

    return totalSize
  }

  func getImageCacheSize() async -> Int64 {
    guard let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache else {
      return 0
    }

    return await Task.detached {
      Int64(dataCache.totalSize)
    }.value
  }

  func getTotalStorageUsed() async -> Int64 {
    let downloadSize = await getDownloadedContentSize()
    let cacheSize = await getImageCacheSize()
    return downloadSize + cacheSize
  }

  func clearImageCache() {
    ImagePipeline.shared.cache.removeAll()
    ImagePipeline.shared.configuration.dataCache?.removeAll()
  }

  private func calculateDirectorySize(at url: URL) -> Int64 {
    var size: Int64 = 0

    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return 0
    }

    for case let fileURL as URL in enumerator {
      do {
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        size += Int64(resourceValues.fileSize ?? 0)
      } catch {
        continue
      }
    }

    return size
  }
}

extension Int64 {
  var formattedByteSize: String {
    ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
  }
}
