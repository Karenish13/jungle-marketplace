import Foundation

/// Saved reports on disk: `<directory>/<id>.json` plus `<id>.pdf`.
/// The report list screen observes `reports`.
@MainActor
public final class ReportStore: ObservableObject {
    /// Newest first.
    @Published public private(set) var reports: [Report] = []
    public let directory: URL

    /// - Parameter directory: defaults to Documents/Reports.
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reports", isDirectory: true)
        reload()
    }

    public func jsonURL(for id: String) -> URL { directory.appendingPathComponent("\(id).json") }
    public func pdfURL(for id: String) -> URL { directory.appendingPathComponent("\(id).pdf") }

    /// Nil until the PDF has been rendered.
    public func existingPDF(for id: String) -> URL? {
        let url = pdfURL(for: id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func save(_ report: Report, pdf: Data? = nil) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try report.jsonData().write(to: jsonURL(for: report.id), options: .atomic)
        if let pdf {
            try pdf.write(to: pdfURL(for: report.id), options: .atomic)
        }
        reload()
    }

    /// The report's PDF file, rendered with `ReportPDFBuilder` and saved first if it does not
    /// exist yet (the preloaded samples, or a report saved without one).
    public func pdfFile(for report: Report) throws -> URL {
        if let url = existingPDF(for: report.id) { return url }
        try save(report, pdf: ReportPDFBuilder.render(report))
        return pdfURL(for: report.id)
    }

    /// Builds the PDF, saves the report with it, and returns the PDF's file URL.
    @discardableResult
    public func saveWithPDF(_ report: Report) throws -> URL {
        try save(report, pdf: ReportPDFBuilder.render(report))
        return pdfURL(for: report.id)
    }

    public func delete(_ id: String) throws {
        for url in [jsonURL(for: id), pdfURL(for: id)] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        reload()
    }

    /// Saves the two sample reports if they are missing, or replaces them if the copy on disk
    /// is from an older build (it may no longer decode, or its PDF may be out of date).
    public func installSamplesIfNeeded() throws {
        for sample in [Report.sampleHealthy, Report.samplePartsDonor] {
            let onDisk = try? Report.fromJSON(Data(contentsOf: jsonURL(for: sample.id)))
            guard onDisk != sample else { continue }
            if let pdf = existingPDF(for: sample.id) { try FileManager.default.removeItem(at: pdf) }
            try save(sample)
        }
    }

    /// Reads every report on disk. Files that fail to decode are skipped.
    public func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        reports = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Report.fromJSON(Data(contentsOf: $0)) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
