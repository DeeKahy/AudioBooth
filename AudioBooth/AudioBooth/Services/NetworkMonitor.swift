import Foundation
import Network

final class NetworkMonitor {
  static let shared = NetworkMonitor()

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "me.jgrenier.AudioBS.NetworkMonitor")

  private(set) var isConnected = true
  private(set) var interfaceType: NWInterface.InterfaceType?

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      self?.isConnected = path.status == .satisfied

      if path.usesInterfaceType(.wifi) {
        self?.interfaceType = .wifi
      } else if path.usesInterfaceType(.cellular) {
        self?.interfaceType = .cellular
      } else if path.usesInterfaceType(.wiredEthernet) {
        self?.interfaceType = .wiredEthernet
      } else if path.usesInterfaceType(.loopback) {
        self?.interfaceType = .loopback
      } else if path.usesInterfaceType(.other) {
        self?.interfaceType = .other
      } else {
        self?.interfaceType = nil
      }
    }
    monitor.start(queue: queue)
  }
}
