import SwiftUI

enum RebootTheme {
    static let popoverWidth: CGFloat = 448
    static let popoverHeight: CGFloat = 640
    static let windowMinWidth: CGFloat = 760
    static let windowMinHeight: CGFloat = 820
    static let pageHorizontalPadding: CGFloat = 18
    static let pageVerticalSpacing: CGFloat = 18
    static let sectionSpacing: CGFloat = 14
    static let cardCornerRadius: CGFloat = 18
    static let buttonCornerRadius: CGFloat = 14

    static let canvas = Color(nsColor: NSColor(calibratedWhite: 0.08, alpha: 0.98))
    static let elevated = Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 1.0))
    static let elevatedStrong = Color(nsColor: NSColor(calibratedWhite: 0.16, alpha: 1.0))
    static let outline = Color.white.opacity(0.08)
    static let subduedText = Color.white.opacity(0.64)
    static let accent = Color.orange
    static let secondaryAccent = Color.blue
    static let positive = Color.green
    static let warning = Color.orange
    static let critical = Color.red
}

struct RebootCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(RebootTheme.elevated, in: RoundedRectangle(cornerRadius: RebootTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RebootTheme.cardCornerRadius, style: .continuous)
                    .stroke(RebootTheme.outline, lineWidth: 1)
            )
    }
}

struct RebootSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(RebootTheme.subduedText)
                .tracking(1)

            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if let detail {
                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RebootTheme.subduedText)
            }
        }
    }
}

struct RebootMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(RebootTheme.subduedText)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct RebootActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isBusy = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(tint.opacity(isDisabled ? 0.2 : 0.9), in: RoundedRectangle(cornerRadius: RebootTheme.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct RebootGhostButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RebootTheme.elevatedStrong, in: RoundedRectangle(cornerRadius: RebootTheme.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct RebootTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(.white)
    }
}

extension View {
    func rebootCard() -> some View {
        modifier(RebootCardModifier())
    }
}
