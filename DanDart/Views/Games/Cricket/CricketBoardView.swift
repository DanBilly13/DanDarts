//
//  CricketBoardView.swift
//  Dart Freak
//
//  The Cricket scoreboard: a column per player (avatar, name, points) and a row per target
//  with each player's marks. Used by the game screen and the History detail.
//

import SwiftUI

/// What the board needs to draw one player.
struct CricketBoardColumn: Identifiable {
    let id: UUID
    let name: String
    let avatarURL: String?
    let color: Color
    let markCounts: [CricketTarget: Int]
    let points: Int
    let isCurrent: Bool

    static func color(forPlayerAt index: Int) -> Color {
        switch index {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        default: return AppColor.player1
        }
    }

    static func firstName(of displayName: String) -> String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }
}

struct CricketBoardView: View {
    let columns: [CricketBoardColumn]
    let deadTargets: Set<CricketTarget>
    /// Shorter rows and smaller avatars, for phones that are too short for the normal layout.
    var compact: Bool = false

    /// The number column in the middle, like the chalkboard's.
    private let labelWidth: CGFloat = 44
    private let columnSpacing: CGFloat = 6

    /// With n players, (n + 1) / 2 sit left of the numbers (in throwing order), the rest right:
    /// 2 = 1 | numbers | 1, 3 = 2 | numbers | 1, 4 = 2 | numbers | 2.
    private var leftColumns: ArraySlice<CricketBoardColumn> {
        columns.prefix((columns.count + 1) / 2)
    }

    private var rightColumns: ArraySlice<CricketBoardColumn> {
        columns.dropFirst((columns.count + 1) / 2)
    }

    private var rowHeight: CGFloat { compact ? 28 : 34 }

    private var avatarSize: CGFloat {
        if compact { return columns.count <= 2 ? 48 : 40 }
        switch columns.count {
        case ...2: return 64
        case 3: return 56
        default: return 48
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(leftColumns) { column in
                    header(for: column)
                }
                Color.clear.frame(width: labelWidth, height: 1)
                ForEach(rightColumns) { column in
                    header(for: column)
                }
            }
            .padding(.bottom, compact ? 4 : 8)

            ForEach(CricketTarget.allCases, id: \.self) { target in
                row(for: target)
            }
        }
        // The rows and marks are drawn at fixed sizes, so larger text would only break the grid.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func header(for column: CricketBoardColumn) -> some View {
        VStack(spacing: compact ? 2 : 4) {
            PlayerAvatarWithRing(
                avatarURL: column.avatarURL,
                isCurrentPlayer: column.isCurrent,
                ringColor: column.color,
                size: avatarSize
            )

            Text(column.name)
                .font(.system(columns.count > 3 ? .subheadline : .headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(column.color)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(column.points)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.justWhite)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: column.points)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CricketBoardAccessibility.headerLabel(for: column))
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(AppColor.justWhite.opacity(0.12))
            .frame(width: 0.5)
    }

    private func markCell(for column: CricketBoardColumn, target: CricketTarget) -> some View {
        CricketMarkView(count: column.markCounts[target] ?? 0, color: column.color)
            .frame(maxWidth: .infinity)
    }

    private func row(for target: CricketTarget) -> some View {
        let isDead = deadTargets.contains(target)
        return VStack(spacing: 0) {
            Rectangle()
                .fill(AppColor.justWhite.opacity(0.12))
                .frame(height: 0.5)

            HStack(spacing: columnSpacing) {
                ForEach(leftColumns) { column in
                    markCell(for: column, target: target)
                }

                Text(target.label)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.justWhite)
                    .frame(width: labelWidth, height: rowHeight)
                    .overlay(alignment: .leading) { verticalHairline }
                    .overlay(alignment: .trailing) { verticalHairline }

                ForEach(rightColumns) { column in
                    markCell(for: column, target: target)
                }
            }
            .frame(height: rowHeight)
        }
        .opacity(isDead ? 0.3 : 1)
        .animation(.easeOut(duration: 0.3), value: isDead)
        // One element per target row: "20: Dan closed, Sam 1 mark, Alex no marks" (throwing order).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CricketBoardAccessibility.targetLabel(target))
        .accessibilityValue(CricketBoardAccessibility.rowValue(columns: columns, target: target, isDead: isDead))
    }
}

// MARK: - Accessibility wording

/// The VoiceOver wording for the board. Pure, so it is unit tested.
enum CricketBoardAccessibility {
    static func targetLabel(_ target: CricketTarget) -> String {
        target == .bull ? "Bull" : "\(target.rawValue)"
    }

    static func marksPhrase(_ marks: Int) -> String {
        switch min(max(marks, 0), 3) {
        case 0: return "no marks"
        case 1: return "1 mark"
        case 2: return "2 marks"
        default: return "closed"
        }
    }

    /// "Dan closed, Sam 1 mark, Alex no marks", plus ", dead, nobody can score" on a dead row.
    static func rowValue(columns: [CricketBoardColumn], target: CricketTarget, isDead: Bool) -> String {
        let marks = columns.map { "\($0.name) \(marksPhrase($0.markCounts[target] ?? 0))" }
        let sentence = marks.joined(separator: ", ")
        return isDead ? sentence + ", dead, nobody can score" : sentence
    }

    static func headerLabel(for column: CricketBoardColumn) -> String {
        let base = "\(column.name), \(column.points) points"
        return column.isCurrent ? base + ", throwing" : base
    }
}

// MARK: - Marks

/// 1 mark: a slash. 2 marks: a cross. 3 marks (closed): a cross inside an outlined circle.
struct CricketMarkView: View {
    let count: Int
    let color: Color

    private let stroke = StrokeStyle(lineWidth: 2.6, lineCap: .round)
    private var marks: Int { min(max(count, 0), 3) }

    var body: some View {
        ZStack {
            switch marks {
            case 1:
                CricketSlash().stroke(color, style: stroke)
            case 2:
                CricketCross().stroke(color, style: stroke)
            case 3:
                Circle().stroke(color, style: stroke).padding(1.3)
                CricketCross().stroke(color, style: stroke).padding(4)
            default:
                EmptyView()
            }
        }
        .frame(width: 26, height: 26)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: marks)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch marks {
        case 0: return "No marks"
        case 1: return "1 mark"
        case 2: return "2 marks"
        default: return "Closed"
        }
    }
}

private struct CricketSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.22))
        return path
    }
}

private struct CricketCross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY - rect.height * 0.22))
        path.move(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.22))
        return path
    }
}

#Preview("Cricket Board") {
    let marks: [CricketTarget: Int] = [.twenty: 3, .nineteen: 2, .eighteen: 1]
    return CricketBoardView(
        columns: [
            CricketBoardColumn(id: UUID(), name: "Dan", avatarURL: nil, color: AppColor.player1,
                               markCounts: marks, points: 40, isCurrent: true),
            CricketBoardColumn(id: UUID(), name: "Sam", avatarURL: nil, color: AppColor.player2,
                               markCounts: [.nineteen: 3, .seventeen: 3], points: 19, isCurrent: false),
            CricketBoardColumn(id: UUID(), name: "Alex", avatarURL: nil, color: AppColor.player3,
                               markCounts: [.eighteen: 3], points: 0, isCurrent: false)
        ],
        deadTargets: [.nineteen]
    )
    .padding(16)
    .background(AppColor.backgroundPrimary)
}
