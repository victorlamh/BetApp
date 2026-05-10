import SwiftUI

struct StatsGraphView: View {
    let points: [StatPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("PERFORMANCE")
                .font(.caption2)
                .bold()
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal)
            
            if points.count < 2 {
                contentUnavailable
            } else {
                chartContent
            }
        }
        .padding(.vertical)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.l)
    }
    
    private var chartContent: some View {
        GeometryReader { geo in
            let values = points.map { $0.value }
            let min = values.min() ?? 0
            let max = values.max() ?? 100
            let range = max - min
            
            Path { path in
                for i in points.indices {
                    let x = geo.size.width * CGFloat(i) / CGFloat(points.count - 1)
                    let y = geo.size.height * (1 - CGFloat((values[i] - min) / (range == 0 ? 1 : range)))
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [AppTheme.oddsUp, AppTheme.primary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 120)
        .padding(.horizontal)
    }
    
    private var contentUnavailable: some View {
        HStack {
            Spacer()
            Text("Need more data to show graph")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .frame(height: 120)
    }
}

struct StatPoint: Identifiable, Decodable {
    var id: String { date }
    let date: String
    let value: Double
}
