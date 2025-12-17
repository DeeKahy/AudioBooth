import Combine
import SwiftUI

struct AppIconPickerView: View {
  @Environment(\.colorScheme) private var colorScheme

  @ObservedObject var model: Model

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        HStack(spacing: 40) {
          VStack(spacing: 12) {
            Image(model.currentIcon.previewImageName)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)
              .cornerRadius(16)
              .shadow(radius: 10)
              .padding(.top, 20)
              .colorScheme(.light)

            Text("Light")
          }

          VStack(spacing: 12) {
            Image(model.currentIcon.previewImageName)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)
              .cornerRadius(16)
              .shadow(radius: 10)
              .padding(.top, 20)
              .colorScheme(.dark)

            Text("Dark")
          }
        }
        .font(.callout)
        .fontWeight(.medium)
        .foregroundColor(.secondary)

        LazyVGrid(
          columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
          ],
          spacing: 20
        ) {
          ForEach(Model.AppIcon.allCases) { icon in
            Button {
              model.setAlternateAppIcon(icon: icon)
            } label: {
              VStack(spacing: 8) {
                Image(icon.previewImageName)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 80, height: 80)
              }
            }
            .disabled(model.isChanging)
          }
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
      }
    }
    .navigationTitle("App Icon")
    .onAppear(perform: model.onAppear)
  }
}

extension AppIconPickerView {
  @Observable
  class Model: ObservableObject {
    var currentIcon: AppIcon
    var isChanging: Bool

    func onAppear() {}
    func setAlternateAppIcon(icon: AppIcon) {}

    init(currentIcon: AppIcon = .default, isChanging: Bool = false) {
      self.currentIcon = currentIcon
      self.isChanging = isChanging
    }
  }
}

extension AppIconPickerView.Model {
  enum AppIcon: String, CaseIterable, Identifiable {
    case `default` = "AppIcon"
    case blue = "AppIcon-Blue"
    case purple = "AppIcon-Purple"
    case green = "AppIcon-Green"
    case dark = "AppIcon-Dark"
    case red = "AppIcon-Red"
    case yellow = "AppIcon-Yellow"
    case teal = "AppIcon-Teal"
    case pink = "AppIcon-Pink"

    var id: String { self.rawValue }

    var previewImageName: String { "IconPreviews/" + self.rawValue }
  }
}

#Preview {
  NavigationStack {
    AppIconPickerView(model: AppIconPickerView.Model())
  }
}
