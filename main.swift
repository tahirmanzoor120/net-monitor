import AppKit
import Darwin
import ServiceManagement

/// Sums received/sent bytes across all active, non-loopback interfaces.
func readTotals() -> (down: UInt64, up: UInt64) {
    var down: UInt64 = 0, up: UInt64 = 0
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
    defer { freeifaddrs(head) }
    var p: UnsafeMutablePointer<ifaddrs>? = first
    while let cur = p {
        let i = cur.pointee
        let flags = Int32(i.ifa_flags)
        if let addr = i.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
           flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0, let data = i.ifa_data {
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            down += UInt64(d.ifi_ibytes)
            up += UInt64(d.ifi_obytes)
        }
        p = i.ifa_next
    }
    return (down, up)
}

func format(_ bytesPerSec: Double) -> String {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var v = bytesPerSec, u = 0
    while v >= 1000 && u < units.count - 1 { v /= 1000; u += 1 }
    return String(format: v < 10 && u > 0 ? "%.2f %@" : (v < 100 && u > 0 ? "%.1f %@" : "%.0f %@"), v, units[u])
}


/// Rolling 60-second graph of download (blue) and upload (orange) speed.
final class GraphView: NSView {
    static let samples = 60
    var down = [Double](repeating: 0, count: samples)
    var up = [Double](repeating: 0, count: samples)

    override init(frame: NSRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }

    func push(down d: Double, up u: Double) {
        down.removeFirst(); down.append(d)
        up.removeFirst(); up.append(u)
        needsDisplay = true
    }

    private func path(_ data: [Double], in r: NSRect, peak: Double, close: Bool) -> NSBezierPath {
        let p = NSBezierPath()
        let step = r.width / CGFloat(data.count - 1)
        for (i, v) in data.enumerated() {
            let pt = NSPoint(x: r.minX + CGFloat(i) * step, y: r.minY + CGFloat(v / peak) * r.height)
            i == 0 ? p.move(to: pt) : p.line(to: pt)
        }
        if close {
            p.line(to: NSPoint(x: r.maxX, y: r.minY))
            p.line(to: NSPoint(x: r.minX, y: r.minY))
            p.close()
        }
        return p
    }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 14, dy: 8)
        let peak = max(down.max() ?? 0, up.max() ?? 0, 1024) * 1.1

        NSColor.labelColor.withAlphaComponent(0.15).setStroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: r.minX, y: r.minY)); base.line(to: NSPoint(x: r.maxX, y: r.minY))
        base.lineWidth = 1; base.stroke()

        for (data, color) in [(down, NSColor.systemBlue), (up, NSColor.systemOrange)] {
            color.withAlphaComponent(0.2).setFill()
            path(data, in: r, peak: peak, close: true).fill()
            color.setStroke()
            let line = path(data, in: r, peak: peak, close: false)
            line.lineWidth = 1.5; line.lineJoinStyle = .round
            line.stroke()
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        NSAttributedString(string: "peak " + format(peak / 1.1), attributes: attrs)
            .draw(at: NSPoint(x: r.minX, y: bounds.maxY - 12))
        let legend = NSMutableAttributedString()
        func add(_ t: String, _ color: NSColor? = nil) {
            var a = attrs
            if let color { a[.foregroundColor] = color }
            legend.append(NSAttributedString(string: t, attributes: a))
        }
        add("60s  "); add("●", .systemBlue); add(" down  "); add("●", .systemOrange); add(" up")
        legend.draw(at: NSPoint(x: r.maxX - legend.size().width, y: bounds.maxY - 12))
    }
}

/// Left-pads to a fixed width so both lines (monospaced) line up exactly.
func padded(_ bytesPerSec: Double) -> String {
    let s = format(bytesPerSec)
    return String(repeating: " ", count: max(0, 9 - s.count)) + s
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var last = readTotals()
    var lastTime = Date()
    var timer: Timer?
    var totalDown: UInt64 = 0, totalUp: UInt64 = 0
    let downItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let upItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let sessionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let graph = GraphView(frame: NSRect(x: 0, y: 0, width: 260, height: 90))
    let graphItem = NSMenuItem()
    let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ n: Notification) {
        let menu = NSMenu()
        graphItem.view = graph
        [downItem, upItem, sessionItem, graphItem].forEach { menu.addItem($0) }
        menu.addItem(.separator())
        loginItem.target = self
        updateLoginItem()
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Net Monitor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
        item.menu = menu
        item.button?.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
        item.button?.title = "↑ 0 B/s\n↓ 0 B/s"
        tick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func updateLoginItem() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func menuWillOpen(_ menu: NSMenu) { updateLoginItem() }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at Login failed: \(error)")
        }
        updateLoginItem()
    }

    func tick() {
        let now = Date(), cur = readTotals()
        let dt = max(now.timeIntervalSince(lastTime), 0.001)
        // Counters can reset (interface down/up); clamp to zero.
        let dDown = cur.down >= last.down ? cur.down - last.down : 0
        let dUp = cur.up >= last.up ? cur.up - last.up : 0
        last = cur; lastTime = now
        totalDown += dDown; totalUp += dUp
        let down = Double(dDown) / dt, up = Double(dUp) / dt

        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.maximumLineHeight = 10
        style.minimumLineHeight = 10
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
            .paragraphStyle: style,
            .baselineOffset: -2,
        ]
        item.button?.attributedTitle = NSAttributedString(
            string: "↑ \(padded(up))\n↓ \(padded(down))", attributes: attrs)
        graph.push(down: down, up: up)
        downItem.title = "Download: \(format(down))"
        upItem.title = "Upload: \(format(up))"
        let f = ByteCountFormatter()
        sessionItem.title = "This session: ↓ \(f.string(fromByteCount: Int64(totalDown)))  ↑ \(f.string(fromByteCount: Int64(totalUp)))"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
