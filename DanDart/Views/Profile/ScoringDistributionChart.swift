//
//  ScoringDistributionChart.swift
//  Dart Freak
//
//  Donut chart showing scoring distribution across 5 buckets
//

import SwiftUI

struct ScoringDistributionChart: View {
    let distribution: ScoringDistribution
    let isLoading: Bool
    
    private let donutSize: CGFloat = 140
    private let donutThickness: CGFloat = 28
    private let columnWidth: CGFloat = 85 // Fixed width for legend columns
    private let legendGutter: CGFloat = 24 // Fixed spacing between legend columns
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scoring Distribution (\(distribution.totalVisits) visits)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)

            if isLoading {
                loadingState
            } else {
                chartView
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 20) {
            SkeletonBlock(height: donutSize, cornerRadius: donutSize / 2, isShimmering: true)
                .frame(width: donutSize, height: donutSize)
                .mask {
                    Circle()
                        .stroke(lineWidth: donutThickness)
                        .frame(width: donutSize, height: donutSize)
                }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<5) { _ in
                    SkeletonBlock(height: 14, cornerRadius: 6, isShimmering: true)
                }
            }
        }
        .frame(height: 160)
    }
    
    private var chartView: some View {
        HStack(spacing: 16) { // Fixed spacing between donut and legend start
            if distribution.totalVisits == 0 {
                emptyDonut
            } else {
                donutChart
            }
            
            // This spacer pushes the legend to the right and absorbs
            // all extra width on Pro Max screens.
            Spacer()
            
            legendView
        }
    }

    private var emptyDonut: some View {
        Circle()
            .stroke(AppColor.interactivePrimaryBackground, lineWidth: donutThickness)
            .frame(width: donutSize, height: donutSize)
    }
    
    private var donutChart: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                DonutSegment(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    thickness: donutThickness
                )
                .fill(colorForBucket(segment.bucket.color))
            }
        }
        .frame(width: donutSize, height: donutSize)
    }
    
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First row: 0-40 and 41-99
            HStack(alignment: .top, spacing: legendGutter) {
                legendItem(for: distribution.buckets[0])
                legendItem(for: distribution.buckets[1])
            }
            
            // Second row: 100-139 and 140-179
            HStack(alignment: .top, spacing: legendGutter) {
                legendItem(for: distribution.buckets[2])
                legendItem(for: distribution.buckets[3])
            }
            
            // Third row: 180
            legendItem(for: distribution.buckets[4])
        }
    }
    
    private func legendItem(for bucket: BucketData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(bucket.range)
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(colorForBucket(bucket.color))
            
            HStack(spacing: 4) {
                Text(String(format: "%.1f%%", distribution.totalVisits == 0 ? 0 : bucket.percentage))
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("(\(distribution.totalVisits == 0 ? 0 : bucket.count))")
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .frame(width: columnWidth, alignment: .leading) // Keeps column alignment stable
    }
    
    private var segments: [(bucket: BucketData, startAngle: Angle, endAngle: Angle)] {
        var result: [(BucketData, Angle, Angle)] = []
        var currentAngle: Double = -90
        
        for bucket in distribution.buckets {
            let startAngle = Angle(degrees: currentAngle)
            let sweepAngle = (bucket.percentage / 100.0) * 360.0
            let endAngle = Angle(degrees: currentAngle + sweepAngle)
            
            result.append((bucket, startAngle, endAngle))
            currentAngle += sweepAngle
        }
        
        return result
    }
    
    private func colorForBucket(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

struct DonutSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let thickness: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius - thickness
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        path.addLine(to: CGPoint(
            x: center.x + innerRadius * CGFloat(cos(endAngle.radians)),
            y: center.y + innerRadius * CGFloat(sin(endAngle.radians))
        ))
        
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        
        path.closeSubpath()
        return path
    }
}
#Preview("With Data") {
    ScoringDistributionChart(
        distribution: ScoringDistribution(
            bucket0_40: BucketData(range: "0-40", count: 45, percentage: 30.0, color: "blue"),
            bucket41_99: BucketData(range: "41-99", count: 60, percentage: 40.0, color: "green"),
            bucket100_139: BucketData(range: "100-139", count: 30, percentage: 20.0, color: "yellow"),
            bucket140_179: BucketData(range: "140-179", count: 12, percentage: 8.0, color: "orange"),
            bucket180: BucketData(range: "180", count: 3, percentage: 2.0, color: "red")
        ),
        isLoading: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Empty State") {
    ScoringDistributionChart(distribution: .empty, isLoading: false)
        .padding()
        .background(AppColor.backgroundPrimary)
}
