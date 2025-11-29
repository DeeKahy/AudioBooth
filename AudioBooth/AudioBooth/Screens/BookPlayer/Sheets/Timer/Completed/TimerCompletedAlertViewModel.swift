import Combine
import Foundation
import UIKit

final class TimerCompletedAlertViewModel: TimerCompletedAlertView.Model {
  private let onExtend: () -> Void
  private let onReset: () -> Void
  private var cancellables = Set<AnyCancellable>()

  init(extendAction: String, onExtend: @escaping () -> Void, onReset: @escaping () -> Void) {
    self.onExtend = onExtend
    self.onReset = onReset

    super.init(extendAction: extendAction)

    setupShakeObserver()
  }

  override func onExtendTapped() {
    onExtend()
  }

  override func onResetTapped() {
    onReset()
  }

  private func setupShakeObserver() {
    NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)
      .sink { [weak self] _ in
        guard let self else { return }
        if UserPreferences.shared.shakeToExtendTimer {
          self.onExtendTapped()
        }
      }
      .store(in: &cancellables)
  }
}
