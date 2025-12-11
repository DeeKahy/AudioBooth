import SwiftUI

extension AutoDownloadMode: Identifiable {
  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .off:
      return "Off"
    case .wifiOnly:
      return "Wi-Fi Only"
    case .wifiAndCellular:
      return "Wi-Fi & Cellular"
    }
  }
}

struct GeneralPreferencesView: View {
  @ObservedObject var preferences = UserPreferences.shared

  var body: some View {
    Form {
      Section {
        Picker("Auto-Download Books", selection: $preferences.autoDownloadBooks) {
          ForEach(AutoDownloadMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .font(.subheadline)
        .bold()

        Toggle("Remove Download on Completion", isOn: $preferences.removeDownloadOnCompletion)
          .font(.subheadline)
          .bold()
      }
    }
    .navigationTitle("General")
  }
}

#Preview {
  NavigationStack {
    GeneralPreferencesView()
  }
}
