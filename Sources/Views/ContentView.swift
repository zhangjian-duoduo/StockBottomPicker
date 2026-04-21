import SwiftUI

// MARK: - 主入口

@main
struct StockBottomPickerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - 列表页

struct ContentView: View {
    @StateObject private var dataService = DataService.shared

    @State private var showCondition1 = true  // 5年低位
    @State private var showCondition2 = true  // 2年震荡
    @State private var excludeSTRisk = false  // 排除ST风险
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选栏
                filterBar

                // 股票列表
                if dataService.isLoading && dataService.stocks.isEmpty {
                    loadingView
                } else if let error = dataService.errorMessage, dataService.stocks.isEmpty {
                    errorView(error)
                } else {
                    stockList
                }
            }
            .navigationTitle("底部选股")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dataService.loadData(forceRefresh: true) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            dataService.loadData()
        }
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "5年低位≤20%",
                    isSelected: $showCondition1
                )
                FilterChip(
                    title: "2年震荡+位置≤30%",
                    isSelected: $showCondition2
                )
                FilterChip(
                    title: "排除ST风险",
                    isSelected: $excludeSTRisk
                )
                Spacer()
            }

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索股票名称或代码", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - 股票列表

    private var stockList: some View {
        let filtered = dataService.filteredStocks(
            showCondition1: showCondition1,
            showCondition2: showCondition2,
            excludeSTRisk: excludeSTRisk,
            searchText: searchText
        )

        return List(filtered, id: \.id) { stock in
            NavigationLink(destination: StockDetailView(stock: stock)) {
                StockRowView(stock: stock)
            }
        }
        .listStyle(.plain)
        .overlay {
            if filtered.isEmpty && !dataService.isLoading {
                Text("没有符合条件的股票")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("加载中...")
            Spacer()
        }
    }

    // MARK: - 错误

    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("加载失败: \(message)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("重试") {
                    dataService.loadData(forceRefresh: true)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }
}

// MARK: - 筛选标签

struct FilterChip: View {
    let title: String
    @Binding var isSelected: Bool

    var body: some View {
        Button(action: { isSelected.toggle() }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.orange.opacity(0.2))
                .foregroundColor(isSelected ? .white : .orange)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color.orange, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 股票行视图

struct StockRowView: View {
    let stock: StockInfo

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // 股票名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(stock.isNewStock ? .orange : .primary)  // 新股票标橙
                    Text(stock.id)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80, alignment: .leading)

                Spacer()

                // 5年位置
                ConditionBadge(
                    title: "5年",
                    value: String(format: "%.0f%%", stock.fiveYearPosition),
                    isMet: stock.meetsCondition1
                )

                // 2年震荡
                ConditionBadge(
                    title: "2年",
                    value: String(format: "%.0f%%", stock.twoYearPosition),
                    isMet: stock.meetsCondition2
                )

                // 股东趋势迷你图
                MiniShareholderChart(data: stock.shareholderTrend)
                    .frame(width: 50, height: 20)

                // PE/PB百分位
                VStack(alignment: .trailing, spacing: 2) {
                    if let pe = stock.pePercentile {
                        Text("PE \(String(format: "%.0f", pe))%")
                            .font(.caption2)
                    }
                    if let pb = stock.pbPercentile {
                        Text("PB \(String(format: "%.0f", pb))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 50)

                // MACD底背离
                Image(systemName: stock.hasMacdBottomDivergence ? "arrow.up.right.circle.fill" : "minus.circle")
                    .foregroundColor(stock.hasMacdBottomDivergence ? .green : .gray)
                    .frame(width: 24)

                // 筹码集中度
                ChipLevelView(level: stock.chipLevel, value: stock.chipConcentration)
                    .frame(width: 40)

                // ST风险
                if stock.hasSTRisk {
                    STRiskBadge(reasons: stock.stRiskReasons)
                        .frame(width: 24)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(minWidth: 400)
    }
}

// MARK: - 条件标记

struct ConditionBadge: View {
    let title: String
    let value: String
    let isMet: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isMet ? .green : .secondary)
        }
        .frame(width: 40)
    }
}

// MARK: - 股东人数迷你图

struct MiniShareholderChart: View {
    let data: [ShareholderQuarter]

    var body: some View {
        GeometryReader { geo in
            if data.count >= 2 {
                let shareholders = data.map { Double($0.shareholders) }
                let minVal = shareholders.min() ?? 0
                let maxVal = shareholders.max() ?? 1
                let range = maxVal - minVal

                Path { path in
                    for (i, val) in shareholders.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(shareholders.count - 1)
                        let y = range > 0 ? geo.size.height * (1 - CGFloat((val - minVal) / range)) : geo.size.height / 2
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 1.5)
            }
        }
    }
}

// MARK: - 筹码等级视图

struct ChipLevelView: View {
    let level: Int  // 1-10
    let value: Double  // 0-100

    var body: some View {
        VStack(spacing: 1) {
            Text("\(level)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(colorForLevel(level))
            Text(String(format: "%.0f", value))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...10: return .red
        default: return .gray
        }
    }
}

// MARK: - ST风险标记

struct STRiskBadge: View {
    let reasons: [String]

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
            .help(reasons.joined(separator: "\n"))
    }
}
