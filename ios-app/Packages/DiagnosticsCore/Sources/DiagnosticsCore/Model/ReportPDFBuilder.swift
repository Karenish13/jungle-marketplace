import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
typealias PDFFont = UIFont
typealias PDFColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PDFFont = NSFont
typealias PDFColor = NSColor
#endif

/// Renders a `Report` as a US Letter PDF.
///
/// Drawn with Core Graphics and attributed strings, so it runs on the Mac as well as the
/// phone and the unit tests can check the output. A simulated report gets an orange
/// "Demo: simulated results" banner and a faint "DEMO" watermark on every page.
public enum ReportPDFBuilder {
    public static func render(_ report: Report) -> Data {
        let layout = Layout(report: report)
        return layout.draw(pages: layout.paginate(layout.blocks()))
    }
}

// MARK: - Layout

private struct Block {
    var height: CGFloat
    /// Headings move to the next page with the block after them.
    var keepWithNext = false
    /// For table rows: the column headings, repeated when the table continues on a new page.
    var header: [Block] = []
    var draw: (CGFloat) -> Void
}

private struct Layout {
    let report: Report

    static let page = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 48
    var width: CGFloat { Self.page.width - 2 * Self.margin }
    var simulated: Bool { report.isSimulated }
    var headerHeight: CGFloat { simulated ? 62 : 34 }
    var footerHeight: CGFloat { 30 }
    var top: CGFloat { Self.margin + headerHeight }
    var bottom: CGFloat { Self.page.height - Self.margin - footerHeight }
    var caps: DeviceCapabilities { report.device.capabilities }

    // MARK: Content

    func blocks() -> [Block] {
        var b: [Block] = []
        b.append(text(attr("iPhone condition report", 24, .bold), after: 2))
        b.append(text(attr(report.device.modelName, 17, .semibold), after: 2))
        b.append(text(attr(Self.date(report.createdAt), 11, color: .gray), after: 14))

        if let stamp = report.simulation {
            let body = "Faults in this report were simulated with the app's developer options. It does not describe a real phone.\n"
                + stamp.details.joined(separator: "\n")
            b.append(text(attr(body, 10, color: Palette.orange), after: 14))
        }

        var phone: [(String, String)] = [
            ("Model", report.device.modelName),
            ("Storage", report.device.storageDescription),
        ]
        if let colour = report.device.colour { phone.append(("Colour", colour)) }
        phone += [
            ("iOS version", report.device.osVersion),
            ("Report ID", report.id),
            ("IMEI (seller-declared)", report.survey.imei ?? "Not given"),
        ]
        b += keyValues(phone)

        // Summary
        b.append(heading("Summary"))
        let grade = report.functionalGrade
        b += keyValues([("Function", grade.title)], valueAttr: attr(grade.title, 12, .bold, color: Palette.grade(grade)))
        let counts = report.counts
        b += keyValues([
            ("Cosmetic condition", report.cosmeticGrade?.title ?? "Survey not finished"),
            ("Components", "\(counts.pass) passed, \(counts.fail) failed, \(counts.notTested) not tested"),
        ])

        // Parts view
        b.append(heading("Parts for repair",
                         note: "For buyers looking for donor parts. A part is good for parts only when every component in it passed."))
        let partColumns: [CGFloat] = [150, 70, 90, width - 310]
        let partHeader = tableRow(["Part", "Result", "Good for parts", "Notes"].map { attr($0, 9, .bold, color: .gray) }, partColumns, shaded: false)
        b.append(partHeader)
        for (i, group) in report.partGroups.enumerated() {
            let failed = group.rows.filter { $0.status == .fail }.map { $0.component.displayName(on: caps) }
            var notes: [String] = []
            if !failed.isEmpty { notes.append("Failed: " + failed.joined(separator: ", ")) }
            if let transfer = group.transferNote { notes.append(transfer) }
            b.append(tableRow([
                attr(group.part.displayName(on: caps), 10),
                attr(group.status.label, 10, .semibold, color: Palette.status(group.status)),
                attr(group.isHarvestable ? "Yes" : "No", 10),
                attr(notes.joined(separator: "\n"), 9, color: .darkGray),
            ], partColumns, shaded: i % 2 == 1, header: partHeader))
        }

        // Component table
        b.append(heading("Every component", note: "Only the components this model has are listed."))
        let componentColumns: [CGFloat] = [130, 70, 90, width - 290]
        let componentHeader = tableRow(["Component", "Result", "Evidence", "Details"].map { attr($0, 9, .bold, color: .gray) }, componentColumns, shaded: false)
        b.append(componentHeader)
        for (i, row) in report.presentComponentRows.enumerated() {
            let details = ([row.note].compactMap { $0 } + row.measurements.map { "\($0.name): \($0.value)" })
                .joined(separator: "\n")
            b.append(tableRow([
                attr(row.component.displayName(on: caps), 10),
                attr(row.status.label, 10, .semibold, color: Palette.status(row.status)),
                attr(row.evidence?.label ?? "", 9, color: .darkGray),
                attr(details, 9, color: .darkGray),
            ], componentColumns, shaded: i % 2 == 1, header: componentHeader))
        }

        // Survey
        b.append(heading("Condition (from the seller)", note: "Self-reported: the app cannot check these answers."))
        let areaColumns: [CGFloat] = [130, 80, width - 210]
        for (i, area) in CosmeticArea.allCases.enumerated() {
            let rating = report.survey[area]
            b.append(tableRow([
                attr("\(area.title) (\(area.covers.lowercased()))", 10),
                attr(rating?.title ?? "Not answered", 10, .semibold),
                attr(rating?.definition ?? "", 9, color: .darkGray),
            ], areaColumns, shaded: i % 2 == 1))
        }
        b.append(spacer(10))
        b += keyValues([
            ("Battery health", report.survey.batteryHealthPercent.map { "\($0)% (from Settings)" } ?? "Not answered"),
            ("Parts replaced", report.survey.partsReplaced?.title ?? "Not answered"),
            ("Activation Lock off", report.survey.activationLockOff.map { $0 ? "Yes" : "No" } ?? "Not answered"),
        ])
        if !report.survey.notes.isEmpty {
            b.append(text(attr("Seller's notes", 10, .bold), after: 2))
            b.append(text(attr(report.survey.notes, 10), after: 8))
        }

        // How to read it
        b.append(heading("How to read this report"))
        let legend = """
        Automated: the app measured the result itself.
        User-confirmed: the app played a sound, vibration or colours and the seller said whether it worked.
        Self-reported: the seller typed or chose the answer; the app cannot check it.
        Not tested: the test was skipped or could not run (for example no Wi-Fi network nearby). It is not a fault.

        The seller ran these tests on their own phone, and this PDF is not signed, so it could be edited. \
        Check that the model, storage and IMEI match the phone you receive.
        """
        b.append(text(attr(legend, 9, color: .darkGray), after: 0))
        return b
    }

    // MARK: Block builders

    func text(_ s: NSAttributedString, after spacing: CGFloat) -> Block {
        let h = measure(s, width)
        return Block(height: h + spacing) { y in drawText(s, CGRect(x: Self.margin, y: y, width: width, height: h)) }
    }

    func spacer(_ h: CGFloat) -> Block { Block(height: h) { _ in } }

    func heading(_ title: String, note: String? = nil) -> Block {
        let t = attr(title, 14, .bold, color: Palette.green)
        let n = note.map { attr($0, 9, color: .gray) }
        let th = measure(t, width)
        let nh = n.map { measure($0, width) } ?? 0
        let height = 16 + th + (n == nil ? 0 : nh + 2) + 6
        return Block(height: height, keepWithNext: true) { y in
            drawText(t, CGRect(x: Self.margin, y: y + 16, width: width, height: th))
            if let n = n { drawText(n, CGRect(x: Self.margin, y: y + 16 + th + 2, width: width, height: nh)) }
        }
    }

    func keyValues(_ pairs: [(String, String)], valueAttr: NSAttributedString? = nil) -> [Block] {
        pairs.map { key, value in
            let k = attr(key, 10, color: .gray)
            let v = valueAttr ?? attr(value, 10)
            let keyWidth: CGFloat = 150
            let h = max(measure(k, keyWidth), measure(v, width - keyWidth))
            return Block(height: h + 5) { y in
                drawText(k, CGRect(x: Self.margin, y: y, width: keyWidth, height: h))
                drawText(v, CGRect(x: Self.margin + keyWidth, y: y, width: width - keyWidth, height: h))
            }
        }
    }

    func tableRow(_ cells: [NSAttributedString], _ columns: [CGFloat], shaded: Bool, header: Block? = nil) -> Block {
        let pad: CGFloat = 5
        let heights = zip(cells, columns).map { measure($0, $1 - 2 * pad) }
        let h = (heights.max() ?? 0) + 2 * pad
        return Block(height: h, header: header.map { [$0] } ?? []) { y in
            guard let ctx = currentContext() else { return }
            if shaded {
                ctx.setFillColor(Palette.shade.cgColor)
                ctx.fill(CGRect(x: Self.margin, y: y, width: width, height: h))
            }
            var x = Self.margin
            for (cell, column) in zip(cells, columns) {
                drawText(cell, CGRect(x: x + pad, y: y + pad, width: column - 2 * pad, height: h - 2 * pad))
                x += column
            }
        }
    }

    // MARK: Pagination and drawing

    func paginate(_ blocks: [Block]) -> [[(Block, CGFloat)]] {
        var pages: [[(Block, CGFloat)]] = [[]]
        var y = top
        for (i, block) in blocks.enumerated() {
            var needed = block.height
            if block.keepWithNext, i + 1 < blocks.count { needed += blocks[i + 1].height }
            if y + needed > bottom, !pages[pages.count - 1].isEmpty {
                pages.append([])
                y = top
                for heading in block.header {
                    pages[pages.count - 1].append((heading, y))
                    y += heading.height
                }
            }
            pages[pages.count - 1].append((block, y))
            y += block.height
        }
        return pages
    }

    func draw(pages: [[(Block, CGFloat)]]) -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: Self.page)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, [
                kCGPDFContextTitle as String: "Condition report \(report.id)",
                kCGPDFContextCreator as String: "JUNGLE",
              ] as CFDictionary)
        else { return Data() }

        for (index, page) in pages.enumerated() {
            ctx.beginPDFPage(nil)
            ctx.saveGState()
            // Top-left origin, like UIKit.
            ctx.translateBy(x: 0, y: Self.page.height)
            ctx.scaleBy(x: 1, y: -1)
            pushContext(ctx)
            if simulated { drawWatermark(ctx) }
            drawHeader(ctx)
            drawFooter(ctx, page: index + 1, of: pages.count)
            for (block, y) in page { block.draw(y) }
            popContext()
            ctx.restoreGState()
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    private func drawHeader(_ ctx: CGContext) {
        let y = Self.margin
        let left = attr("Condition report · \(report.device.modelName)", 9, color: .gray)
        let right = attr("Report \(report.id)", 9, .semibold, color: .gray)
        drawText(left, CGRect(x: Self.margin, y: y, width: width / 2, height: 14))
        let rw = measureWidth(right)
        drawText(right, CGRect(x: Self.margin + width - rw, y: y, width: rw, height: 14))
        ctx.setFillColor(Palette.line.cgColor)
        ctx.fill(CGRect(x: Self.margin, y: y + 16, width: width, height: 0.5))

        if simulated {
            let banner = CGRect(x: Self.margin, y: y + 24, width: width, height: 24)
            ctx.setFillColor(Palette.orange.cgColor)
            ctx.fill(banner)
            let label = attr(SimulationStamp.label.uppercased() + ": not a real condition report", 10, .bold, color: .white)
            drawText(label, banner.insetBy(dx: 8, dy: 6))
        }
    }

    private func drawFooter(_ ctx: CGContext, page: Int, of total: Int) {
        let y = Self.page.height - Self.margin - 12
        ctx.setFillColor(Palette.line.cgColor)
        ctx.fill(CGRect(x: Self.margin, y: y - 6, width: width, height: 0.5))
        let left = attr("Made on the phone by the seller with JUNGLE. Not independently verified.", 8, color: .gray)
        let right = attr("Page \(page) of \(total)", 8, color: .gray)
        drawText(left, CGRect(x: Self.margin, y: y, width: width - 80, height: 12))
        let rw = measureWidth(right)
        drawText(right, CGRect(x: Self.margin + width - rw, y: y, width: rw, height: 12))
    }

    private func drawWatermark(_ ctx: CGContext) {
        let mark = attr("DEMO", 150, .heavy, color: Palette.orange.withAlphaComponent(0.08))
        let size = CGSize(width: measureWidth(mark), height: measure(mark, 1000))
        ctx.saveGState()
        ctx.translateBy(x: Self.page.width / 2, y: Self.page.height / 2)
        ctx.rotate(by: -.pi / 5)
        drawText(mark, CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        ctx.restoreGState()
    }

    // MARK: Text helpers

    func attr(_ string: String, _ size: CGFloat, _ weight: PDFFont.Weight = .regular, color: PDFColor = .black) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: string, attributes: [
            .font: PDFFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ])
    }

    func measure(_ s: NSAttributedString, _ width: CGFloat) -> CGFloat {
        guard s.length > 0 else { return 0 }
        let rect = s.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return ceil(rect.height)
    }

    /// Draws with the same options `measure` uses, so the last line is never clipped.
    func drawText(_ s: NSAttributedString, _ rect: CGRect) {
        s.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    func measureWidth(_ s: NSAttributedString) -> CGFloat {
        ceil(s.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 1000),
                            options: [.usesLineFragmentOrigin], context: nil).width) + 1
    }

    static func date(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Platform glue

private enum Palette {
    static let green = PDFColor(red: 0x23 / 255, green: 0x7A / 255, blue: 0x4B / 255, alpha: 1)
    static let red = PDFColor(red: 0.80, green: 0.15, blue: 0.15, alpha: 1)
    static let orange = PDFColor(red: 0.90, green: 0.45, blue: 0.05, alpha: 1)
    static let shade = PDFColor(white: 0.95, alpha: 1)
    static let line = PDFColor(white: 0.8, alpha: 1)

    static func status(_ status: TestStatus) -> PDFColor {
        switch status {
        case .pass: return green
        case .fail: return red
        case .notTested: return orange
        case .notPresent: return .gray
        }
    }

    static func grade(_ grade: FunctionalGrade) -> PDFColor {
        switch grade {
        case .allWorking: return green
        case .incomplete, .minorFaults: return orange
        case .forParts: return red
        }
    }
}

/// Makes `ctx` the current context for attributed-string drawing.
private func pushContext(_ ctx: CGContext) {
    #if canImport(UIKit)
    UIGraphicsPushContext(ctx)
    #else
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    #endif
}

private func popContext() {
    #if canImport(UIKit)
    UIGraphicsPopContext()
    #else
    NSGraphicsContext.restoreGraphicsState()
    #endif
}

private func currentContext() -> CGContext? {
    #if canImport(UIKit)
    return UIGraphicsGetCurrentContext()
    #else
    return NSGraphicsContext.current?.cgContext
    #endif
}
