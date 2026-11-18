import AVFoundation
import DiagnosticsCore
import SwiftUI
import UIKit

/// The full-screen interactions a test can ask for (docs/CONTRACT.md, "Test screens").

struct TouchGridView: View {
    @ObservedObject var grid: TouchGridModel
    let onGiveUp: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 1) {
                    ForEach(0..<grid.rows, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<grid.columns, id: \.self) { col in
                                Rectangle().fill(grid.isPainted(row: row, column: col) ? Color.accentColor : Color.gray.opacity(0.25))
                            }
                        }
                    }
                }
                // Simultaneous, so a finger passing over the button still paints the cells under it.
                Button("Can't fill the rest", action: onGiveUp)
                    .buttonStyle(CompactButtonStyle())
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("grid"))
                    .onChanged { grid.touch(at: $0.location, in: geo.size) }
            )
        }
        .coordinateSpace(name: "grid")
        .ignoresSafeArea()
        .statusBar(hidden: true)
    }
}

struct ColourScreensView: View {
    let colours: [DisplayColour]
    let defect: DisplayDefect?
    let onDone: () -> Void
    @State private var index = 0

    var body: some View {
        let rgb = colours[min(index, colours.count - 1)].rgb
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
                if let defect = defect {
                    Color(red: defect.rgb.red, green: defect.rgb.green, blue: defect.rgb.blue)
                        .frame(width: max(2, geo.size.width * defect.rect.width), height: geo.size.height * defect.rect.height)
                        .offset(x: geo.size.width * defect.rect.x, y: geo.size.height * defect.rect.y)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            if index + 1 < colours.count { index += 1 } else { onDone() }
        }
        .statusBar(hidden: true)
    }
}

struct MultiTouchView: View {
    @ObservedObject var model: TouchCountModel
    let onGiveUp: () -> Void

    var body: some View {
        ZStack {
            TouchReporter { count, _, _ in model.update(touchCount: count) }
            VStack(spacing: 16) {
                Text("Put \(model.required) fingers on the screen at once")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(model.current)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                Text("Best so far: \(model.maximum)").foregroundColor(.secondary)
                Button("Can't do it", action: onGiveUp).buttonStyle(CompactButtonStyle())
            }
            .padding(32)
        }
        .ignoresSafeArea()
    }
}

struct ForcePressView: View {
    @ObservedObject var model: ForcePressModel
    let onGiveUp: () -> Void

    var body: some View {
        ZStack {
            TouchReporter { _, force, maximum in model.update(force: force, maximumForce: maximum) }
            VStack(spacing: 24) {
                Text("Press hard anywhere on the screen").font(.title2.bold()).multilineTextAlignment(.center)
                ProgressView(value: model.peak)
                Button("Can't do it", action: onGiveUp).buttonStyle(CompactButtonStyle())
            }
            .padding(40)
        }
        .ignoresSafeArea()
    }
}

/// Small pill button that sits on top of a full-screen interaction.
struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black.opacity(configuration.isPressed ? 0.4 : 0.65))
            .cornerRadius(20)
    }
}

/// UIKit view that reports how many fingers are down and the strongest touch force.
/// SwiftUI cannot count simultaneous touches or read force, so this is needed for
/// the multi-touch and 3D Touch tests.
struct TouchReporter: UIViewRepresentable {
    let onChange: (Int, CGFloat, CGFloat) -> Void

    func makeUIView(context: Context) -> ReporterView {
        let view = ReporterView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .systemBackground
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ReporterView, context: Context) {
        view.onChange = onChange
    }

    final class ReporterView: UIView {
        var onChange: ((Int, CGFloat, CGFloat) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { report(event) }

        private func report(_ event: UIEvent?) {
            let active = (event?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled }
            let force = active.map(\.force).max() ?? 0
            let maximum = active.first?.maximumPossibleForce ?? 0
            onChange?(active.count, force, maximum)
        }
    }
}

// MARK: - Camera preview

/// Live preview of the camera a test is checking. Shows black when the camera is
/// simulated as broken, so what the user sees matches the result.
struct CameraPreview: UIViewRepresentable {
    let feed: CameraFeed

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        update(view)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        update(view)
    }

    private func update(_ view: PreviewView) {
        let session: AVCaptureSession? = feed.isBlanked ? nil : feed.session
        if view.previewLayer.session !== session { view.previewLayer.session = session }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

extension TestInteraction {
    var isCameraPreview: Bool {
        if case .cameraPreview = self { return true }
        return false
    }
}
