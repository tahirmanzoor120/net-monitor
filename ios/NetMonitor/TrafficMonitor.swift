import Foundation
import Observation

struct Counters {
    var wifiDown: UInt32 = 0, wifiUp: UInt32 = 0
    var cellDown: UInt32 = 0, cellUp: UInt32 = 0
}

/// Reads per-interface byte counters. en0 is Wi-Fi, pdp_ip* is cellular.
/// The kernel counters are 32-bit, so deltas use wrapping subtraction.
func readCounters() -> Counters {
    var c = Counters()
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return c }
    defer { freeifaddrs(head) }
    var p: UnsafeMutablePointer<ifaddrs>? = first
    while let cur = p {
        let i = cur.pointee
        if let addr = i.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = i.ifa_data {
            let name = String(cString: i.ifa_name)
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            if name == "en0" {
                c.wifiDown &+= d.ifi_ibytes; c.wifiUp &+= d.ifi_obytes
            } else if name.hasPrefix("pdp_ip") {
                c.cellDown &+= d.ifi_ibytes; c.cellUp &+= d.ifi_obytes
            }
        }
        p = i.ifa_next
    }
    return c
}

func formatSpeed(_ bytesPerSec: Double) -> (value: String, unit: String) {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var v = bytesPerSec, u = 0
    while v >= 1000 && u < units.count - 1 { v /= 1000; u += 1 }
    let s = u == 0 || v >= 100 ? String(format: "%.0f", v) : (v >= 10 ? String(format: "%.1f", v) : String(format: "%.2f", v))
    return (s, units[u])
}

struct Sample: Identifiable {
    let id: Int
    let down: Double
    let up: Double
}

@Observable
final class TrafficMonitor {
    static let window = 60

    var down = 0.0
    var up = 0.0
    var samples: [Sample] = []
    var sessionDown: UInt64 = 0
    var sessionUp: UInt64 = 0
    var wifiDown = 0.0
    var cellDown = 0.0

    private var last = readCounters()
    private var lastTime = Date()
    private var tickCount = 0
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        last = readCounters(); lastTime = Date()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
    }

    private func tick() {
        let now = Date(), cur = readCounters()
        let dt = max(now.timeIntervalSince(lastTime), 0.001)
        let wd = cur.wifiDown &- last.wifiDown, wu = cur.wifiUp &- last.wifiUp
        let cd = cur.cellDown &- last.cellDown, cu = cur.cellUp &- last.cellUp
        last = cur; lastTime = now

        wifiDown = Double(wd) / dt; cellDown = Double(cd) / dt
        down = Double(UInt64(wd) + UInt64(cd)) / dt
        up = Double(UInt64(wu) + UInt64(cu)) / dt
        sessionDown += UInt64(wd) + UInt64(cd)
        sessionUp += UInt64(wu) + UInt64(cu)

        tickCount += 1
        samples.append(Sample(id: tickCount, down: down, up: up))
        if samples.count > Self.window { samples.removeFirst(samples.count - Self.window) }
    }
}
