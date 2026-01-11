import Combine
import SwiftUI

struct StoragePreferencesView: View {
  @ObservedObject var model: Model

  var body: some View {
    Form {
      Section {
        HStack {
          Text("Total Storage Used")
          Spacer()
          if model.isLoading {
            ProgressView()
          } else {
            Text(model.totalSize)
              .foregroundStyle(.secondary)
          }
        }
      }

      Section("Downloaded Content") {
        HStack {
          Text("Audiobooks & Ebooks")
          Spacer()
          if model.isLoading {
            ProgressView()
          } else {
            Text(model.downloadSize)
              .foregroundStyle(.secondary)
          }
        }

        Button("Clear All Downloads", action: model.onClearDownloadsTapped)
          .foregroundColor(.red)
          .disabled(model.downloadSize == "0 bytes" || model.isLoading)

        Text("⚠️ This will delete all downloaded audiobooks and ebooks. You can re-download them later.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Image Cache") {
        HStack {
          Text("Cache Size")
          Spacer()
          if model.isLoading {
            ProgressView()
          } else {
            Text(model.cacheSize)
              .foregroundStyle(.secondary)
          }
        }

        Button("Clear Image Cache", action: model.onClearCacheTapped)
          .foregroundColor(.red)
          .disabled(model.cacheSize == "0 bytes" || model.isLoading)

        Text("Cover images will be re-downloaded as needed.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Storage")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear(perform: model.onAppear)
    .alert("Clear All Downloads?", isPresented: $model.showDownloadConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Clear", role: .destructive, action: model.onConfirmClearDownloads)
    } message: {
      Text("This will delete all downloaded content. This action cannot be undone.")
    }
    .alert("Clear Image Cache?", isPresented: $model.showCacheConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Clear", role: .destructive, action: model.onConfirmClearCache)
    } message: {
      Text("This will clear all cached cover images. They will be re-downloaded as needed.")
    }
  }
}

extension StoragePreferencesView {
  @Observable class Model: ObservableObject {
    var isLoading = true
    var totalSize = "0 bytes"
    var downloadSize = "0 bytes"
    var cacheSize = "0 bytes"
    var showDownloadConfirmation = false
    var showCacheConfirmation = false

    func onAppear() {}
    func onClearDownloadsTapped() {}
    func onClearCacheTapped() {}
    func onConfirmClearDownloads() {}
    func onConfirmClearCache() {}

    init(
      isLoading: Bool = true,
      totalSize: String = "0 bytes",
      downloadSize: String = "0 bytes",
      cacheSize: String = "0 bytes"
    ) {
      self.isLoading = isLoading
      self.totalSize = totalSize
      self.downloadSize = downloadSize
      self.cacheSize = cacheSize
    }
  }
}

extension StoragePreferencesView.Model {
  static var mock = StoragePreferencesView.Model(
    isLoading: false,
    totalSize: "1.2 GB",
    downloadSize: "800 MB",
    cacheSize: "400 MB"
  )
}

#Preview {
  NavigationStack {
    StoragePreferencesView(model: .mock)
  }
}
