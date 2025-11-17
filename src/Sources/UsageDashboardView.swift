import SwiftUI

struct UsageDashboardView: View {
    @ObservedObject var usageManager: UsageManager
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingDetailView = false

    var filteredStats: UsageStats {
        usageManager.getUsageStats(for: selectedTimeRange)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Usage & Analytics")
                    .font(.headline)
                Spacer()

                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("Today").tag(TimeRange.today)
                    Text("Week").tag(TimeRange.week)
                    Text("Month").tag(TimeRange.month)
                    Text("All Time").tag(TimeRange.allTime)
                }
                .pickerStyle(.segmented)
            }

            // Summary Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Total Requests",
                        value: "\(filteredStats.totalRequests)",
                        icon: "network",
                        color: .blue
                    )

                    StatCard(
                        title: "Total Tokens",
                        value: formatNumber(filteredStats.totalTokens),
                        icon: "textformat.subscript",
                        color: .purple
                    )

                    StatCard(
                        title: "Estimated Cost",
                        value: String(format: "$%.4f", filteredStats.totalCost),
                        icon: "dollarsign.circle",
                        color: .green
                    )

                    StatCard(
                        title: "Avg Cost/Request",
                        value: String(format: "$%.6f", filteredStats.averageCostPerRequest),
                        icon: "chart.line",
                        color: .orange
                    )
                }
                .padding(.horizontal)
            }

            // Breakdown by Model
            if !filteredStats.requestsByModel.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Usage by Model")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach(Array(filteredStats.requestsByModel.sorted { $0.value > $1.value }), id: \.key) { model, requests in
                            ModelBreakdownRow(
                                model: model,
                                requests: requests,
                                tokens: filteredStats.tokensByModel[model] ?? 0,
                                cost: filteredStats.costByModel[model] ?? 0
                            )
                        }
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }

            // Breakdown by Service
            if !filteredStats.requestsByService.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Usage by Service")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ForEach(Array(filteredStats.requestsByService.sorted { $0.value > $1.value }), id: \.key) { service, requests in
                            ServiceCard(
                                service: service,
                                requests: requests,
                                percentage: Double(requests) / Double(filteredStats.totalRequests) * 100
                            )
                        }
                        Spacer()
                    }
                }
            }

            // Recent Usage
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                    Spacer()
                    Button("View All") {
                        showingDetailView = true
                    }
                    .font(.caption)
                }

                if usageManager.usages.isEmpty {
                    Text("No usage recorded yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    VStack(spacing: 6) {
                        ForEach(usageManager.usages.prefix(5)) { usage in
                            UsageRow(usage: usage)
                        }
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingDetailView) {
            UsageDetailView(usageManager: usageManager, isPresented: $showingDetailView)
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
        .frame(minWidth: 120)
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ModelBreakdownRow: View {
    let model: String
    let requests: Int
    let tokens: Int
    let cost: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                Text("\(requests) requests")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTokens(tokens))
                    .font(.caption)
                Text(String(format: "$%.4f", cost))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}

struct ServiceCard: View {
    let service: String
    let requests: Int
    let percentage: Double

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(service.capitalized)
                .font(.caption)
                .fontWeight(.semibold)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))

                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(serviceColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f%%", percentage))
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .frame(width: 60, height: 60)

            Text("\(requests) requests")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    var serviceColor: Color {
        switch service.lowercased() {
        case "claude": return .purple
        case "codex": return .orange
        case "gemini": return .blue
        case "qwen": return .red
        default: return .gray
        }
    }
}

struct UsageRow: View {
    let usage: APIUsage

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.model)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(usage.inputTokens)↓ \(usage.outputTokens)↑")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(usage.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let cost = usage.estimatedCost {
                    Text(String(format: "$%.6f", cost))
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

struct UsageDetailView: View {
    @ObservedObject var usageManager: UsageManager
    @Binding var isPresented: Bool
    @State private var sortBy: SortOption = .dateNewest

    enum SortOption {
        case dateNewest
        case dateOldest
        case costHighest
        case tokensHighest
    }

    var sortedUsages: [APIUsage] {
        switch sortBy {
        case .dateNewest:
            return usageManager.usages.sorted { $0.timestamp > $1.timestamp }
        case .dateOldest:
            return usageManager.usages.sorted { $0.timestamp < $1.timestamp }
        case .costHighest:
            return usageManager.usages.sorted { ($0.estimatedCost ?? 0) > ($1.estimatedCost ?? 0) }
        case .tokensHighest:
            return usageManager.usages.sorted { $0.totalTokens > $1.totalTokens }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Detailed Usage Log")
                    .font(.headline)
                Spacer()
                Button("Close") { isPresented = false }
            }

            Picker("Sort By", selection: $sortBy) {
                Text("Newest").tag(SortOption.dateNewest)
                Text("Oldest").tag(SortOption.dateOldest)
                Text("Cost").tag(SortOption.costHighest)
                Text("Tokens").tag(SortOption.tokensHighest)
            }
            .pickerStyle(.segmented)

            if usageManager.usages.isEmpty {
                VStack(spacing: 8) {
                    Text("No usage records yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
            } else {
                List(sortedUsages) { usage in
                    UsageDetailRow(usage: usage)
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .frame(width: 700, height: 600)
    }
}

struct UsageDetailRow: View {
    let usage: APIUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(usage.model)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()
                Text(usage.service.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(serviceColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Input")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(usage.inputTokens)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Output")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(usage.outputTokens)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(usage.totalTokens)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Cost")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let cost = usage.estimatedCost {
                        Text(String(format: "$%.6f", cost))
                            .font(.caption)
                            .fontWeight(.semibold)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text(usage.timestamp, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    var serviceColor: Color {
        switch usage.service.lowercased() {
        case "claude": return .purple
        case "codex": return .orange
        case "gemini": return .blue
        case "qwen": return .red
        default: return .gray
        }
    }
}
