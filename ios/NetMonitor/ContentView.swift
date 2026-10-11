import SwiftUI
import Charts

struct ContentView: View {
    let monitor: TrafficMonitor
    @AppStorage("keepAwake") private var keepAwake = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    SpeedCard(title: "Download", symbol: "arrow.down", color: .blue, speed: monitor.down)
                    SpeedCard(title: "Upload", symbol: "arrow.up", color: .orange, speed: monitor.up)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 60 seconds").font(.footnote).foregroundStyle(.secondary)
                    SpeedChart(samples: monitor.samples)
                        .frame(height: 180)
                }
                .padding()
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 10) {
                    row("Wi-Fi download", formatted(monitor.wifiDown))
                    row("Cellular download", formatted(monitor.cellDown))
                    Divider()
                    row("Session downloaded", bytes(monitor.sessionDown))
                    row("Session uploaded", bytes(monitor.sessionUp))
                }
                .padding()
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

                Toggle("Keep screen awake", isOn: $keepAwake)
                    .padding(.horizontal)
                Text("Speeds update only while the app is open — iOS suspends apps in the background.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
        }
        .onChange(of: keepAwake, initial: true) { _, v in UIApplication.shared.isIdleTimerDisabled = v }
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack { Text(l).foregroundStyle(.secondary); Spacer(); Text(v).monospacedDigit() }
    }
    private func formatted(_ s: Double) -> String { let f = formatSpeed(s); return "\(f.value) \(f.unit)" }
    private func bytes(_ b: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file) }
}

struct SpeedCard: View {
    let title: String, symbol: String, color: Color, speed: Double

    var body: some View {
        let f = formatSpeed(speed)
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.footnote).foregroundStyle(color)
            Text(f.value).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(f.unit).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SpeedChart: View {
    let samples: [Sample]

    var body: some View {
        Chart {
            ForEach(samples) { s in
                series("Download", s.id, s.down)
                series("Upload", s.id, s.up)
            }
        }
        .chartForegroundStyleScale(["Download": Color.blue, "Upload": Color.orange])
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { v in
                AxisGridLine()
                AxisValueLabel {
                    if let d = v.as(Double.self) { let f = formatSpeed(d); Text("\(f.value) \(f.unit)") }
                }
            }
        }
        .chartLegend(position: .bottom)
    }

    @ChartContentBuilder
    private func series(_ name: String, _ x: Int, _ y: Double) -> some ChartContent {
        AreaMark(x: .value("t", x), y: .value("speed", y), series: .value("s", name), stacking: .unstacked)
            .foregroundStyle(by: .value("Series", name)).opacity(0.2)
        LineMark(x: .value("t", x), y: .value("speed", y), series: .value("s", name))
            .foregroundStyle(by: .value("Series", name))
    }
}
