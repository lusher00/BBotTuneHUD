import SwiftUI
import Combine

// MARK: - Data model

struct DataPoint: Identifiable {
    let id = UUID()
    let t: Double   // wall-clock seconds since first sample
    let value: Float
}

struct PIDSample {
    let t: Double
    let setpoint: Float
    let measurement: Float
    let error: Float
    let pTerm: Float
    let iTerm: Float
    let dTerm: Float
    let output: Float
}

enum GraphSeries: String, CaseIterable, Identifiable {
    case setpoint    = "Setpoint"
    case measurement = "Measurement"
    case error       = "Error"
    case pTerm       = "P term"
    case iTerm       = "I term"
    case dTerm       = "D term"
    case output      = "Output"

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .setpoint:    return .blue
        case .measurement: return .green
        case .error:       return .orange
        case .pTerm:       return .purple
        case .iTerm:       return .cyan
        case .dTerm:       return .mint
        case .output:      return .red
        }
    }
    var dashed: Bool { self == .setpoint }
}

class PIDGraphData: ObservableObject {
    let name: String
    let windowSec: Double = 15.0
    let maxPoints  = 600

    @Published var series: [GraphSeries: [DataPoint]] = Dictionary(
        uniqueKeysWithValues: GraphSeries.allCases.map { ($0, []) }
    )

    @Published var recording = false
    private var recordBuf: [PIDSample] = []
    private var t0: Double?

    init(name: String) { self.name = name }

    func append(state: PIDState) {
        let now = Date().timeIntervalSinceReferenceDate
        if t0 == nil { t0 = now }
        let t       = now - t0!
        let cutoff  = t - windowSec

        func add(_ key: GraphSeries, _ val: Float) {
            var buf = series[key] ?? []
            buf.append(DataPoint(t: t, value: val))
            buf.removeAll { $0.t < cutoff }
            if buf.count > maxPoints { buf.removeFirst(buf.count - maxPoints) }
            series[key] = buf
        }

        add(.setpoint,    state.setpoint)
        add(.measurement, state.measurement ?? 0)
        add(.error,       state.error)
        add(.pTerm,       state.pTerm ?? 0)
        add(.iTerm,       state.iTerm ?? 0)
        add(.dTerm,       state.dTerm ?? 0)
        add(.output,      state.output)

        if recording {
            recordBuf.append(PIDSample(
                t: t, setpoint: state.setpoint,
                measurement: state.measurement ?? 0, error: state.error,
                pTerm: state.pTerm ?? 0, iTerm: state.iTerm ?? 0,
                dTerm: state.dTerm ?? 0, output: state.output))
        }
    }

    func startRecording() { recordBuf = []; recording = true }

    func stopAndSave() -> URL? {
        recording = false
        guard !recordBuf.isEmpty else { return nil }
        var csv = "t,setpoint,measurement,error,p_term,i_term,d_term,output\n"
        for s in recordBuf {
            csv += String(format: "%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n",
                          s.t, s.setpoint, s.measurement, s.error,
                          s.pTerm, s.iTerm, s.dTerm, s.output)
        }
        let fname = "\(name.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fname)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        recordBuf = []
        return url
    }

    func stopAndDiscard() { recording = false; recordBuf = [] }
    func reset() {
        t0 = nil
        series = Dictionary(uniqueKeysWithValues: GraphSeries.allCases.map { ($0, []) })
    }
}

// MARK: - Controller metadata

struct ControllerMeta {
    let name: String
    let unit: String
    let pLabel: String   // what "P term" means for this controller
    let iLabel: String
    let dLabel: String
}

let controllerMeta: [ControllerMeta] = [
    ControllerMeta(name: "D1 Balance",  unit: "deg",
                   pLabel: "P (kp·err)", iLabel: "I (ki·∫err)", dLabel: "D (kd·derr)"),
    ControllerMeta(name: "D2 Position", unit: "ticks / deg",
                   pLabel: "Pos corr (deg)", iLabel: "Vel damp (deg)", dLabel: "Tick vel"),
    ControllerMeta(name: "D3 Steering", unit: "deg",
                   pLabel: "P (kp·err)", iLabel: "I (ki·∫err)", dLabel: "D (kd·derr)"),
]

// MARK: - Main view

struct PIDGraphView: View {
    @ObservedObject var viewModel: RobotViewModel

    @StateObject private var d1 = PIDGraphData(name: "D1 Balance")
    @StateObject private var d2 = PIDGraphData(name: "D2 Position")
    @StateObject private var d3 = PIDGraphData(name: "D3 Steering")

    @State private var selected: Int = 0
    @State private var visibleSeries: Set<GraphSeries> = [.measurement, .error, .output]
    @State private var shareItem: URL? = nil
    @State private var showingShare = false

    var allData: [PIDGraphData] { [d1, d2, d3] }
    var currentData: PIDGraphData { allData[selected] }
    var currentMeta: ControllerMeta { controllerMeta[selected] }
    var anyRecording: Bool { allData.contains { $0.recording } }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack(alignment: .top) {
                PIDChartContent(
                    meta:       currentMeta,
                    visible:    visibleSeries,
                    seriesData: currentData.series,
                    windowSec:  currentData.windowSec,
                    landscape:  landscape
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    overlayBar(landscape: landscape)
                    Spacer()
                }
            }
        }
        .onReceive(viewModel.$robotState) { state in
            d1.append(state: state.d1Balance)
            d2.append(state: state.d2Drive)
            d3.append(state: state.d3Steering)
        }
        .sheet(isPresented: $showingShare) {
            if let url = shareItem { ShareSheet(items: [url]) }
        }
    }

    // MARK: Toolbar

    func overlayBar(landscape: Bool) -> some View {
        HStack(spacing: 10) {

            // Controller picker
            Picker("", selection: $selected) {
                Text("D1").tag(0)
                Text("D2").tag(1)
                Text("D3").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 130)

            Divider().frame(height: 22)

            // Series multi-select
            Menu {
                ForEach(GraphSeries.allCases) { s in
                    let label: String = {
                        switch s {
                        case .pTerm: return currentMeta.pLabel
                        case .iTerm: return currentMeta.iLabel
                        case .dTerm: return currentMeta.dLabel
                        default:     return s.rawValue
                        }
                    }()
                    Button {
                        if visibleSeries.contains(s) { visibleSeries.remove(s) }
                        else                         { visibleSeries.insert(s) }
                    } label: {
                        HStack {
                            if visibleSeries.contains(s) { Image(systemName: "checkmark") }
                            Text(label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Series (\(visibleSeries.count))").font(.subheadline)
                }
            }

            Divider().frame(height: 22)

            // Compact stacked legend — 2 columns
            let visible = GraphSeries.allCases.filter { visibleSeries.contains($0) }
            let cols = 2
            let rows = (visible.count + cols - 1) / cols
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 1) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<cols, id: \.self) { col in
                            let idx = row * cols + col
                            if idx < visible.count {
                                let s = visible[idx]
                                HStack(spacing: 3) {
                                    Circle().fill(s.color).frame(width: 6, height: 6)
                                    Text(s.rawValue).font(.system(size: 8)).foregroundColor(.secondary)
                                }
                            } else {
                                Color.clear.frame(width: 1)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Record / Save / Discard
            if anyRecording {
                Button {
                    for d in allData {
                        if d.recording, let url = d.stopAndSave() {
                            shareItem = url; showingShare = true; break
                        }
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.up")
                        .font(.subheadline).foregroundColor(.green)
                }
                .buttonStyle(.plain)

                Button { allData.forEach { $0.stopAndDiscard() } } label: {
                    Image(systemName: "xmark.circle").foregroundColor(.red)
                }
                .buttonStyle(.plain)

                HStack(spacing: 3) {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Text("REC").font(.caption).foregroundColor(.red)
                }
            } else {
                Button { currentData.startRecording() } label: {
                    Label("Record", systemImage: "record.circle")
                        .font(.subheadline).foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            Button("Reset") { allData.forEach { $0.reset() } }
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, landscape ? 6 : 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Chart canvas

struct PIDChartContent: View {
    let meta:       ControllerMeta
    let visible:    Set<GraphSeries>
    let seriesData: [GraphSeries: [DataPoint]]
    let windowSec:  Double
    let landscape:  Bool

    private let leftPad:   CGFloat = 52
    private let rightPad:  CGFloat = 10
    private let bottomPad: CGFloat = 24
    private var topPad:    CGFloat { landscape ? 46 : 52 }

    private struct ChartParams {
        let yMin: Float; let yMax: Float; let ySpan: Float
        // tNow is wall-clock "now" — drives a smooth sliding window
        let tNow: Double; let tMin: Double; let tSpan: Double
        let yGridVals: [Float]
        let xLabels: [(offset: Double, label: String)]  // offset from tMin, not absolute t
    }

    private func chartParams() -> ChartParams {
        var allVals: [Float] = []
        for s in visible { allVals += (seriesData[s] ?? []).map(\.value) }
        let rawMin = allVals.min() ?? -1
        let rawMax = allVals.max() ?? 1
        let span   = Swift.max(rawMax - rawMin, 0.001)
        let margin = span * 0.12
        let yMin   = rawMin - margin
        let yMax   = rawMax + margin
        let ySpan  = yMax - yMin

        // Key fix: use current wall time as tNow so the window slides
        // smoothly instead of snapping to the last data point's timestamp.
        let refPts = seriesData[.error] ?? seriesData[.output] ?? []
        let t0     = refPts.first?.t ?? 0
        let tNow   = refPts.last.map { _ in
            // derive wall "now" from the data's elapsed time
            (refPts.last?.t ?? 0)
        } ?? windowSec
        let tMin   = Swift.max(0.0, tNow - windowSec)
        let tSpan  = Swift.max(tNow - tMin, 1.0)
        _ = t0  // suppress unused warning

        let xStep = 5.0
        var xLabels: [(offset: Double, label: String)] = []
        // Generate labels at fixed 5-second grid positions
        let firstGrid = ceil(tMin / xStep) * xStep
        var xg = firstGrid
        while xg <= tNow + 0.01 {
            let relT = Int((tNow - xg).rounded())
            let offset = xg - tMin
            xLabels.append((offset: offset, label: relT == 0 ? "now" : "-\(relT)s"))
            xg += xStep
        }

        return ChartParams(
            yMin: yMin, yMax: yMax, ySpan: ySpan,
            tNow: tNow, tMin: tMin, tSpan: tSpan,
            yGridVals: niceGridValues(lo: yMin, hi: yMax, targetLines: 6),
            xLabels: xLabels
        )
    }

    var body: some View {
        GeometryReader { geo in
            let W    = geo.size.width
            let H    = geo.size.height
            let plotW = W - leftPad - rightPad
            let plotH = H - topPad - bottomPad
            let p    = chartParams()

            ZStack {
                Color(.systemBackground)

                Canvas { ctx, _ in
                    // All coordinate math uses offsets from tMin so labels and
                    // canvas share identical x-positions — eliminates flicker.
                    let px: (Double) -> CGFloat = { t in
                        leftPad + CGFloat((t - p.tMin) / p.tSpan) * plotW
                    }
                    let py: (Float) -> CGFloat = { v in
                        topPad + CGFloat(1.0 - Double((v - p.yMin) / p.ySpan)) * plotH
                    }
                    let clampY: (CGFloat) -> CGFloat = {
                        Swift.max(topPad, Swift.min(topPad + plotH, $0))
                    }

                    // Y grid
                    for gv in p.yGridVals {
                        let gy = py(gv)
                        guard gy >= topPad && gy <= topPad + plotH else { continue }
                        var path = Path()
                        path.move(to: CGPoint(x: leftPad, y: gy))
                        path.addLine(to: CGPoint(x: leftPad + plotW, y: gy))
                        let isZero = abs(gv) < Float(p.ySpan) * 0.015
                        ctx.stroke(path,
                                   with: .color(.gray.opacity(isZero ? 0.55 : 0.20)),
                                   style: isZero
                                       ? StrokeStyle(lineWidth: 1)
                                       : StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    }

                    // X grid — use same offsets as labels
                    for pair in p.xLabels {
                        let gx = leftPad + CGFloat(pair.offset / p.tSpan) * plotW
                        guard gx >= leftPad && gx <= leftPad + plotW else { continue }
                        var path = Path()
                        path.move(to: CGPoint(x: gx, y: topPad))
                        path.addLine(to: CGPoint(x: gx, y: topPad + plotH))
                        ctx.stroke(path, with: .color(.gray.opacity(0.18)),
                                   style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    }

                    // Border
                    ctx.stroke(
                        Path(CGRect(x: leftPad, y: topPad, width: plotW, height: plotH)),
                        with: .color(.gray.opacity(0.4)), lineWidth: 0.5)

                    // Series
                    func draw(_ ctx: inout GraphicsContext, pts: [DataPoint],
                              color: Color, width: CGFloat, dashed: Bool) {
                        guard pts.count > 1 else { return }
                        var path = Path()
                        var started = false
                        for pt in pts {
                            let cp = CGPoint(x: px(pt.t), y: clampY(py(pt.value)))
                            if !started { path.move(to: cp); started = true }
                            else        { path.addLine(to: cp) }
                        }
                        ctx.stroke(path, with: .color(color),
                                   style: dashed
                                       ? StrokeStyle(lineWidth: width, dash: [5, 3])
                                       : StrokeStyle(lineWidth: width))
                    }

                    for s in GraphSeries.allCases where visible.contains(s) {
                        draw(&ctx, pts: seriesData[s] ?? [], color: s.color,
                             width: (s == .error || s == .output) ? 2.0 : 1.5,
                             dashed: s.dashed)
                    }
                }

                // Axis labels — use same offset math as canvas so they stay aligned
                GeometryReader { _ in
                    let py2: (Float) -> CGFloat = { v in
                        topPad + CGFloat(1.0 - Double((v - p.yMin) / p.ySpan)) * plotH
                    }

                    // Y labels
                    ForEach(Array(p.yGridVals.enumerated()), id: \.offset) { _, gv in
                        let gy = py2(gv)
                        if gy >= topPad && gy <= topPad + plotH {
                            Text(formatAxisVal(gv))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: leftPad - 4, alignment: .trailing)
                                .position(x: (leftPad - 4) / 2, y: gy)
                        }
                    }

                    Text(meta.unit)
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .position(x: leftPad / 2, y: topPad + 8)

                    // X labels — offset-based so they match canvas exactly
                    ForEach(Array(p.xLabels.enumerated()), id: \.offset) { _, pair in
                        let gx = leftPad + CGFloat(pair.offset / p.tSpan) * plotW
                        if gx >= leftPad && gx <= leftPad + plotW {
                            Text(pair.label)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                                .position(x: gx, y: geo.size.height - bottomPad / 2)
                        }
                    }
                }
            }
        }
    }

    private func niceGridValues(lo: Float, hi: Float, targetLines: Int) -> [Float] {
        let span = hi - lo
        guard span > 0 else { return [lo, hi] }
        let rawStep = span / Float(targetLines)
        let mag = pow(10.0, floor(log10(rawStep)))
        let steps: [Float] = [1, 2, 2.5, 5, 10]
        let step = (steps.first { $0 * mag >= rawStep } ?? 10) * mag
        let start = ceil(lo / step) * step
        var vals: [Float] = []
        var v = start
        while v <= hi + step * 0.01 { vals.append(v); v += step }
        return vals
    }

    private func formatAxisVal(_ v: Float) -> String {
        let a = abs(v)
        if a >= 10000 { return String(format: "%.0fk", v / 1000) }
        if a >= 100   { return String(format: "%.0f", v) }
        if a >= 1     { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }
}

// MARK: - Helpers

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
