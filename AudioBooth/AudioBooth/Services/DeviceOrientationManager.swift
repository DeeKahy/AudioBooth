import Combine
import CoreMotion
import Foundation
import Logging
import UIKit

final class DeviceOrientationManager: ObservableObject {
  static let shared = DeviceOrientationManager()
  
  private let motionManager = CMMotionManager()
  private var cancellables = Set<AnyCancellable>()
  
  @Published private(set) var isFaceDown = false
  @Published private(set) var isFaceUp = false
  
  private var lastOrientation: DeviceOrientation = .unknown
  private var flipDetectedSubject = PassthroughSubject<Void, Never>()
  
  var flipDetected: AnyPublisher<Void, Never> {
    flipDetectedSubject.eraseToAnyPublisher()
  }
  
  private enum DeviceOrientation {
    case faceUp
    case faceDown
    case other
    case unknown
  }
  
  private init() {
    setupAppLifecycleObservers()
    startMonitoring()
  }
  
  private func setupAppLifecycleObservers() {
    NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
      .sink { [weak self] _ in
        self?.stopMonitoring()
      }
      .store(in: &cancellables)
    
    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
      .sink { [weak self] _ in
        self?.startMonitoring()
      }
      .store(in: &cancellables)
  }
  
  func startMonitoring() {
    guard motionManager.isDeviceMotionAvailable else {
      AppLogger.player.warning("Device motion not available")
      return
    }
    
    guard !motionManager.isDeviceMotionActive else {
      AppLogger.player.debug("Device motion already active")
      return
    }
    
    motionManager.deviceMotionUpdateInterval = 0.5
    motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
      guard let self, let motion = motion else {
        if let error = error {
          AppLogger.player.error("Device motion error: \(error)")
        }
        return
      }
      
      self.processMotionData(motion)
    }
    
    AppLogger.player.info("Device orientation monitoring started")
  }
  
  func stopMonitoring() {
    guard motionManager.isDeviceMotionActive else { return }
    
    motionManager.stopDeviceMotionUpdates()
    lastOrientation = .unknown
    AppLogger.player.info("Device orientation monitoring stopped")
  }
  
  private func processMotionData(_ motion: CMDeviceMotion) {
    let gravity = motion.gravity
    
    // Determine current orientation based on gravity
    // z-axis points through the screen
    // When face up: z ≈ -1
    // When face down: z ≈ 1
    let currentOrientation: DeviceOrientation
    
    if gravity.z < -0.75 {
      currentOrientation = .faceUp
      isFaceDown = false
      isFaceUp = true
    } else if gravity.z > 0.75 {
      currentOrientation = .faceDown
      isFaceDown = true
      isFaceUp = false
    } else {
      currentOrientation = .other
      isFaceDown = false
      isFaceUp = false
    }
    
    // Detect flip from face up to face down
    if lastOrientation == .faceUp && currentOrientation == .faceDown {
      AppLogger.player.info("Device flip detected: face up → face down")
      flipDetectedSubject.send()
    }
    
    // Update last orientation for all changes
    if currentOrientation != lastOrientation {
      lastOrientation = currentOrientation
    }
  }
}
