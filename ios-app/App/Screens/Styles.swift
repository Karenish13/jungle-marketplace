import DiagnosticsCore
import SwiftUI
import UIKit

/// Shared look for the temporary screens. Everything here works on iOS 14
/// (`.bordered`, `.borderedProminent` and `.tint` need iOS 15).

/// A full-width filled button.
struct PrimaryButtonStyle: ButtonStyle {
    var colour: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(colour.opacity(configuration.isPressed ? 0.6 : 1))
            .cornerRadius(12)
    }
}

/// A full-width outlined button, for the less important choice next to a primary one.
struct SecondaryButtonStyle: ButtonStyle {
    var colour: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(colour)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(colour.opacity(configuration.isPressed ? 0.2 : 0.1))
            .cornerRadius(12)
    }
}

extension TestStatus {
    var colour: Color {
        switch self {
        case .pass: return .green
        case .fail: return .red
        case .notTested: return .orange
        case .notPresent: return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .notTested: return "minus.circle.fill"
        case .notPresent: return "circle.dashed"
        }
    }
}

/// Status icon; nil means the test has not run yet.
struct StatusIcon: View {
    let status: TestStatus?
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: status?.symbol ?? "circle")
            .font(.system(size: size))
            .foregroundColor(status?.colour ?? Color(.tertiaryLabel))
    }
}

/// Orange banner shown wherever results may be simulated.
struct SimulationBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).font(.footnote)
        }
        .foregroundColor(.orange)
    }
}

enum Keyboard {
    /// iOS 14 has no `@FocusState`, so ask UIKit to end editing.
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
