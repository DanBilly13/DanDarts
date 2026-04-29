//
//  ThreeDartAverageTrendChart.swift
//  Dart Freak
//
//  Interactive line graph showing 3-dart average trend over time
//

import SwiftUI

struct ThreeDartAverageTrendChart: View {
    let dataPoints: [ThreeDartDataPoint]
    let isLoading: Bool
    
    @State private var selectedPoint: ThreeDartDataPoint?
    @State private var dragLocation: CGPoint?
    
    private let yAxisLabels = [0, 60, 120, 180]
    private let chartHeight: CGFloat = 112
    private let lineColor = Color(red: 1.0, green: 0.4, blue: 0.3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3-Dart Average Trend")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)

            if isLoading {
                loadingState
            } else if dataPoints.isEmpty {
                noDataState
            } else {
                // Value overlay sits above the chart with its own spacing
                Group {
                    if let selected = selectedPoint {
                        dataOverlay(point: selected)
                    } else if let lastPoint = dataPoints.last {
                        dataOverlay(point: lastPoint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false)
                
                chartArea
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                SkeletonBlock(height: 28, cornerRadius: 10, isShimmering: true)
                    .frame(width: 140)
                SkeletonBlock(height: 12, cornerRadius: 6, isShimmering: true)
                    .frame(width: 160)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            SkeletonBlock(height: chartHeight, cornerRadius: 12, isShimmering: true)
        }
    }

    private var noDataState: some View {
        VStack(spacing: 12) {
            Text("No games played yet — no data")
                .font(.caption)
                .foregroundColor(AppColor.textSecondary.opacity(0.7))

            VStack(spacing: 2) {
                Text("0.00 pts")
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppColor.textPrimary)
                Text("—")
                    .font(.caption)
                    .foregroundColor(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .allowsHitTesting(false)

            SkeletonBlock(height: chartHeight, cornerRadius: 12, isShimmering: false)
        }
    }
    
    // Fixed-height chart container. Geometry inside uses its own width/height for all calculations.
    private var chartArea: some View {
        ZStack {
            HStack(spacing: 8) {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    ZStack(alignment: .leading) {
                        gridLines(width: width, height: height)
                        linePath(width: width, height: height)
                        gradientFill(width: width, height: height)
                        
                        if let dragLoc = dragLocation {
                            scrubberLine(at: dragLoc, height: height)
                        }
                        
                        if let selected = selectedPoint {
                            dataThumb(for: selected, width: width, height: height)
                        }
                    }
                    .contentShape(Rectangle()) // ensures gestures work across empty areas
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(at: value.location, width: width, height: height)
                            }
                            .onEnded { _ in
                                dragLocation = nil
                                selectedPoint = nil
                            }
                    )
                }
                
                yAxisLabelsView
            }
        }
        .frame(height: chartHeight)
    }
    
    private func dataOverlay(point: ThreeDartDataPoint) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.2f pts", point.average))
                .font(.title2.weight(.bold))
                .foregroundColor(AppColor.textPrimary)
            
            Text(formatTimestamp(point.timestamp))
                .font(.caption)
                .foregroundColor(AppColor.textSecondary)
        }
    }
    
    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(yAxisLabels, id: \.self) { value in
                let y = yPosition(for: Double(value), height: height)
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: width, height: 1)
                    .position(x: width / 2, y: y)
            }
        }
    }
    
    private func linePath(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            guard !dataPoints.isEmpty else { return }
            
            let points = dataPoints.enumerated().map { index, point -> CGPoint in
                let x = xPosition(for: index, width: width)
                let y = yPosition(for: point.average, height: height)
                return CGPoint(x: x, y: y)
            }
            
            if points.count == 1 {
                path.addEllipse(in: CGRect(x: points[0].x - 2, y: points[0].y - 2, width: 4, height: 4))
            } else {
                path.move(to: points[0])
                
                for i in 1..<points.count {
                    let current = points[i]
                    let previous = points[i - 1]
                    
                    let controlPoint1 = CGPoint(
                        x: previous.x + (current.x - previous.x) * 0.5,
                        y: previous.y
                    )
                    let controlPoint2 = CGPoint(
                        x: previous.x + (current.x - previous.x) * 0.5,
                        y: current.y
                    )
                    
                    path.addCurve(to: current, control1: controlPoint1, control2: controlPoint2)
                }
            }
        }
        .stroke(lineColor, lineWidth: 3)
    }
    
    private func gradientFill(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            guard !dataPoints.isEmpty else { return }
            
            let points = dataPoints.enumerated().map { index, point -> CGPoint in
                let x = xPosition(for: index, width: width)
                let y = yPosition(for: point.average, height: height)
                return CGPoint(x: x, y: y)
            }
            
            if points.count == 1 {
                return
            }
            
            path.move(to: CGPoint(x: points[0].x, y: height))
            path.addLine(to: points[0])
            
            for i in 1..<points.count {
                let current = points[i]
                let previous = points[i - 1]
                
                let controlPoint1 = CGPoint(
                    x: previous.x + (current.x - previous.x) * 0.5,
                    y: previous.y
                )
                let controlPoint2 = CGPoint(
                    x: previous.x + (current.x - previous.x) * 0.5,
                    y: current.y
                )
                
                path.addCurve(to: current, control1: controlPoint1, control2: controlPoint2)
            }
            
            path.addLine(to: CGPoint(x: points.last!.x, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.0)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func scrubberLine(at location: CGPoint, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.5))
            .frame(width: 1, height: height)
            .position(x: location.x, y: height / 2)
    }
    
    private func dataThumb(for point: ThreeDartDataPoint, width: CGFloat, height: CGFloat) -> some View {
        guard let index = dataPoints.firstIndex(where: { $0.id == point.id }) else {
            return AnyView(EmptyView())
        }
        
        let x = xPosition(for: index, width: width)
        let y = yPosition(for: point.average, height: height)
        
        return AnyView(
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(lineColor, lineWidth: 2)
                )
                .position(x: x, y: y)
        )
    }
    
    private var yAxisLabelsView: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                ForEach(yAxisLabels, id: \.self) { value in
                    let y = yPosition(for: Double(value), height: height)
                    Text("\(value)")
                        .font(.caption2)
                        .foregroundColor(AppColor.textSecondary)
                        .position(x: 15, y: y)
                }
            }
        }
        .frame(width: 30)
    }
    
    private func xPosition(for index: Int, width: CGFloat) -> CGFloat {
        guard dataPoints.count > 1 else { return width / 2 }
        let spacing = width / CGFloat(dataPoints.count - 1)
        return CGFloat(index) * spacing
    }
    
    private func yPosition(for value: Double, height: CGFloat) -> CGFloat {
        let maxValue: Double = 180
        let minValue: Double = 0
        let range = maxValue - minValue
        let clamped = min(max(value, minValue), maxValue)
        let normalizedValue = (clamped - minValue) / range
        return height * (1.0 - CGFloat(normalizedValue))
    }
    
    private func handleDrag(at location: CGPoint, width: CGFloat, height: CGFloat) {
        dragLocation = CGPoint(x: min(max(location.x, 0), width), y: location.y)
        
        var closestPoint: ThreeDartDataPoint?
        var closestDistance: CGFloat = .infinity
        
        for (index, point) in dataPoints.enumerated() {
            let x = xPosition(for: index, width: width)
            let distance = abs(location.x - x)
            
            if distance < closestDistance {
                closestDistance = distance
                closestPoint = point
            }
        }
        
        if let point = closestPoint, point.id != selectedPoint?.id {
            selectedPoint = point
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM HH:mm"
        return formatter.string(from: date)
    }
}

#Preview("With Data") {
    ThreeDartAverageTrendChart(
        dataPoints: [
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 7), average: 45, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 6), average: 52, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 5), average: 48, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 4), average: 61, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 3), average: 58, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 2), average: 67, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date().addingTimeInterval(-86400 * 1), average: 72, matchId: UUID()),
            ThreeDartDataPoint(timestamp: Date(), average: 86, matchId: UUID())
        ],
        isLoading: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Empty State") {
    ThreeDartAverageTrendChart(dataPoints: [], isLoading: false)
        .padding()
        .background(AppColor.backgroundPrimary)
}
