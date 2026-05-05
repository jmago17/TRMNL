import Foundation
import Network

enum NetworkPreflight {
    static func requireNetwork(timeout: TimeInterval = 3.0) throws {
        guard isNetworkAvailable(timeout: timeout) else {
            throw AgentError.noNetwork
        }
    }

    private static func isNetworkAvailable(timeout: TimeInterval) -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "trmnl.network-preflight")
        let semaphore = DispatchSemaphore(value: 0)
        var isAvailable = false

        monitor.pathUpdateHandler = { path in
            isAvailable = path.status == .satisfied
            semaphore.signal()
        }
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + timeout)
        monitor.cancel()

        return isAvailable
    }
}
