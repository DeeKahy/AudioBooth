import Foundation
import Models

final class StoragePreferencesViewModel: StoragePreferencesView.Model {
  private let storageManager = StorageManager.shared

  override func onAppear() {
    Task {
      await loadStorageInfo()
    }
  }

  override func onClearDownloadsTapped() {
    showDownloadConfirmation = true
  }

  override func onClearCacheTapped() {
    showCacheConfirmation = true
  }

  override func onConfirmClearDownloads() {
    Task {
      isLoading = true
      let currentBookID = PlayerManager.shared.current?.id

      DownloadManager.shared.deleteAllServerData()

      let allBooks = try? LocalBook.fetchAll()
      for book in allBooks ?? [] {
        if book.bookID != currentBookID {
          try? book.delete()
        }
      }

      try? await Task.sleep(for: .seconds(0.5))
      await loadStorageInfo()
      Toast(success: "All downloads cleared").show()
    }
  }

  override func onConfirmClearCache() {
    Task {
      isLoading = true
      storageManager.clearImageCache()
      try? await Task.sleep(for: .seconds(0.5))
      await loadStorageInfo()
      Toast(success: "Image cache cleared").show()
    }
  }

  private func loadStorageInfo() async {
    isLoading = true

    let total = await storageManager.getTotalStorageUsed()
    let downloads = await storageManager.getDownloadedContentSize()
    let cache = await storageManager.getImageCacheSize()

    totalSize = total.formattedByteSize
    downloadSize = downloads.formattedByteSize
    cacheSize = cache.formattedByteSize

    isLoading = false
  }
}
