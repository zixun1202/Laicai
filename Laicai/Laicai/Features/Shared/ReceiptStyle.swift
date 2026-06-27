import SwiftUI

enum ReceiptStyle {
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.12)
    static let fadedInk = Color(red: 0.45, green: 0.44, blue: 0.40)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.89)
    static let panel = Color(red: 1.0, green: 0.99, blue: 0.95)
    static let accent = Color(red: 0.96, green: 0.82, blue: 0.31)
    static let positive = Color(red: 0.20, green: 0.55, blue: 0.30)
    static let paperShadow = Color.black.opacity(0.08)
    static let background = Color(red: 0.06, green: 0.06, blue: 0.055)
    static let outlineWidth: CGFloat = 0.9
    static let softOutlineWidth: CGFloat = 0.65

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct ReceiptOutlinedPanel<Content: View>: View {
    let fill: Color
    let cornerRadius: CGFloat
    let content: Content

    init(
        fill: Color = ReceiptStyle.panel,
        cornerRadius: CGFloat = 22,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ReceiptStyle.ink.opacity(0.72), lineWidth: ReceiptStyle.outlineWidth)
            )
    }
}

struct ReceiptPill: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .black))
            Text(title)
                .lineLimit(1)
        }
        .font(ReceiptStyle.mono(11, weight: .black))
        .foregroundStyle(ReceiptStyle.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(isSelected ? ReceiptStyle.paper : Color.white.opacity(0.55), in: Capsule())
        .overlay(
            Capsule()
                .stroke(ReceiptStyle.ink, lineWidth: ReceiptStyle.softOutlineWidth)
        )
    }
}

struct ReceiptPaper<Content: View>: View {
    let content: Content
    let tornEdges: Bool

    init(tornEdges: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.tornEdges = tornEdges
    }

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if tornEdges {
                    ReceiptPaperShape(teeth: 18, depth: 8)
                        .fill(ReceiptStyle.paper)
                        .shadow(color: ReceiptStyle.paperShadow, radius: 18, y: 8)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(ReceiptStyle.paper)
                        .shadow(color: ReceiptStyle.paperShadow, radius: 12, y: 6)
                }
            }
            .clipShape(tornEdges ? AnyShape(ReceiptPaperShape(teeth: 18, depth: 8)) : AnyShape(RoundedRectangle(cornerRadius: 24)))
    }
}

struct AnyShape: Shape {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

struct ReceiptHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text("LAICAI / DAILY ARCHIVE")
                .font(ReceiptStyle.mono(12, weight: .semibold))
                .tracking(6)
                .foregroundStyle(ReceiptStyle.fadedInk)

            Text(title)
                .font(ReceiptStyle.mono(36, weight: .black))
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text("- \(subtitle) -")
                .font(ReceiptStyle.mono(13, weight: .semibold))
                .tracking(3)
                .foregroundStyle(ReceiptStyle.fadedInk)
        }
        .foregroundStyle(ReceiptStyle.ink)
        .frame(maxWidth: .infinity)
    }
}

struct TicketPageHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(subtitle)
                    .font(ReceiptStyle.mono(12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(ReceiptStyle.fadedInk)
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(ReceiptStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(ReceiptStyle.ink)
                .frame(width: 52, height: 52)
                .background(ReceiptStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ReceiptStyle.ink.opacity(0.72), lineWidth: ReceiptStyle.outlineWidth)
                )
        }
    }
}

struct ReceiptDashedDivider: View {
    var body: some View {
        Line()
            .stroke(
                ReceiptStyle.fadedInk.opacity(0.48),
                style: StrokeStyle(lineWidth: 1.2, dash: [4, 5])
            )
            .frame(height: 1)
    }
}

struct ReceiptSolidDivider: View {
    var body: some View {
        Rectangle()
            .fill(ReceiptStyle.ink)
            .frame(height: 2)
    }
}

struct ReceiptInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 20)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(ReceiptStyle.mono(14, weight: .semibold))
        .foregroundStyle(ReceiptStyle.ink)
    }
}

struct ReceiptSectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ReceiptDashedDivider()
            Text(title)
                .font(ReceiptStyle.mono(12, weight: .bold))
                .foregroundStyle(ReceiptStyle.fadedInk)
            ReceiptDashedDivider()
        }
    }
}

struct ReceiptBarcode: View {
    let code: String

    private let bars: [CGFloat] = [2, 1, 3, 1, 1, 2, 4, 1, 2, 3, 1, 1, 3, 2, 1, 4, 1, 2, 2, 1, 3, 1, 2, 4, 1, 1]

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
                    Rectangle()
                        .fill(ReceiptStyle.ink)
                        .frame(width: width, height: 58)
                }
            }
            Text(code)
                .font(ReceiptStyle.mono(13, weight: .semibold))
                .tracking(4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("编号 \(code)")
    }
}

struct ReceiptActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(ReceiptStyle.mono(13, weight: .bold))
            .foregroundStyle(ReceiptStyle.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(ReceiptStyle.ink, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct ReceiptPaperShape: Shape {
    let teeth: Int
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth = rect.width / CGFloat(max(teeth, 1))

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        for index in 0..<teeth {
            let startX = rect.minX + CGFloat(index) * toothWidth
            path.addLine(to: CGPoint(x: startX + toothWidth * 0.5, y: rect.minY))
            path.addLine(to: CGPoint(x: startX + toothWidth, y: rect.minY + depth))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        for index in stride(from: teeth, through: 0, by: -1) {
            let x = rect.minX + CGFloat(index) * toothWidth
            path.addLine(to: CGPoint(x: x - toothWidth * 0.5, y: rect.maxY))
            path.addLine(to: CGPoint(x: max(rect.minX, x - toothWidth), y: rect.maxY - depth))
        }

        path.closeSubpath()
        return path
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
