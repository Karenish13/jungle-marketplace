import DiagnosticsCore
import PDFKit
import SwiftUI
import UIKit

/// The in-app report viewer: the PDF in PDFKit, with a share button
/// that sends it to Files, AirDrop, Mail and so on.
struct ReportViewer: View {
    @EnvironmentObject private var store: ReportStore
    let report: Report
    @State private var pdfURL: URL?
    @State private var shareURL: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if let url = pdfURL {
                PDFKitView(url: url).ignoresSafeArea(edges: .bottom)
            } else if failed {
                Text("The PDF could not be created.").foregroundColor(.secondary)
            } else {
                ProgressView("Creating PDF…")
            }
        }
        .navigationTitle(report.device.modelName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: share) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(Text("Share PDF"))
                    .disabled(pdfURL == nil)
            }
        }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard pdfURL == nil else { return }
        do { pdfURL = try store.pdfFile(for: report) } catch { failed = true }
    }

    /// Shares a copy with a readable file name, e.g. "iPhone 7 condition report JGL-7K3Q-9PXM.pdf".
    private func share() {
        guard let source = pdfURL else { return }
        let name = "\(report.device.modelName) condition report \(report.id).pdf"
            .replacingOccurrences(of: "/", with: "-")
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: copy)
        do {
            try FileManager.default.copyItem(at: source, to: copy)
            shareURL = copy
        } catch {
            shareURL = source
        }
    }
}

/// Saved reports, newest first. The two sample reports are always there.
struct SavedReportsView: View {
    @EnvironmentObject private var store: ReportStore

    var body: some View {
        List {
            ForEach(store.reports) { report in
                NavigationLink(destination: ReportViewer(report: report)) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.richtext").font(.title2).foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(report.device.modelName).font(.headline)
                                if report.isSimulated {
                                    Text("DEMO").font(.caption2.bold()).foregroundColor(.orange)
                                }
                            }
                            Text(report.functionalGrade.title).font(.subheadline).foregroundColor(.secondary)
                            Text("\(report.id) · \(Self.dateFormatter.string(from: report.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { store.reports[$0].id }
                for id in ids { try? store.delete(id) }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Saved reports")
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

/// PDFKit's viewer, scaled to the screen width.
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}

/// The system share sheet (`ShareLink` needs iOS 16).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
