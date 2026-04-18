import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var vm: EloViewModel
    @State private var selectedRange = "7D"
    let ranges = ["24H", "7D", "1M", "ALL"]
    
    var body: some View {
        NavigationView {
            ZStack {
                LiquidBackgroundView(level: vm.riskLevel)
                
                if vm.history.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Chart Card
                            VStack(alignment: .leading, spacing: 16) {
                                Picker("Range", selection: $selectedRange) {
                                    ForEach(ranges, id: \.self) { range in
                                        Text(range)
                                    }
                                }
                                pickerStyle(.segmented)
                                
                                EloChartView(history: vm.history)
                                    .frame(height: 200)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            
                            // Event Log
                            VStack(alignment: .leading, spacing: 16) {
                                Text("ELO ACTIVITY")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                
                                ForEach(vm.history) { event in
                                    EventRow(event: event)
                                }
                            }
                            
                            // Correlation Insights
                            VStack(alignment: .leading, spacing: 16) {
                                Text("SMART INSIGHTS")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                
                                SleepCorrelationChart(history: vm.history)
                                    .frame(height: 150)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                
                                InsightCard(
                                    title: "Sleep & ELO",
                                    description: "You gain 22% more ELO on days where you sleep over 7 hours.",
                                    icon: "moon.stars.fill",
                                    color: .blue
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Analytics")
        }
    }
}

struct SleepCorrelationChart: View {
    let history: [EloHistoryEvent]
    
    var body: some View {
        Chart {
            ForEach(history.filter { $0.sleepHours != nil }) { event in
                BarMark(
                    x: .value("Date", event.date),
                    y: .value("Sleep", event.sleepHours ?? 0)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(hours, specifier: "%.0f")h")
                    }
                }
            }
        }
    }
}

struct InsightCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let elo: Int
}

struct EloChartView: View {
    let history: [EloHistoryEvent]
    
    // Simple running total for the chart
    var chartData: [ChartDataPoint] {
        var runningTotal = 1200 // Base ELO
        var data: [ChartDataPoint] = []
        
        // Sort history by date to calculate running total correctly
        let sortedHistory = history.sorted { $0.date < $1.date }
        
        for event in sortedHistory {
            runningTotal += event.change
            data.append(ChartDataPoint(date: event.date, elo: runningTotal))
        }
        
        return data
    }
    
    var body: some View {
        Chart {
            ForEach(chartData) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("ELO", item.elo)
                )
                .foregroundStyle(Color(hex: "#00FFA3"))
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("ELO", item.elo)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#00FFA3").opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                AxisValueLabel().foregroundStyle(.secondary)
            }
        }
    }
}

struct EventRow: View {
    let event: EloHistoryEvent
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(event.change >= 0 ? Color(hex: "#00FFA3").opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: event.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(event.change >= 0 ? Color(hex: "#00FFA3") : .red)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.reason)
                    .font(.headline)
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(event.change >= 0 ? "+" : "")\(event.change)")
                .font(.system(.body, design: .rounded).bold())
                .foregroundStyle(event.change >= 0 ? Color(hex: "#00FFA3") : .red)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.3))
            
            Text("No Activity Yet")
                .font(.title3.bold())
            
            Text("Complete tasks or check-in to see your ELO progress.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(EloViewModel())
}
