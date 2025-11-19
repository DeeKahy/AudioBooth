import SwiftUI

struct GeneralPreferencesView: View {
  @ObservedObject var preferences = UserPreferences.shared

  var body: some View {
    Form {
      Section {
        Toggle("Show Listening Stats", isOn: $preferences.showListeningStats)
          .bold()
      }
      .listSectionSpacing(.custom(12))

      Section {
        Toggle("Auto-Download Books", isOn: $preferences.autoDownloadBooks)
          .bold()

        Toggle("Remove Download on Completion", isOn: $preferences.removeDownloadOnCompletion)
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
