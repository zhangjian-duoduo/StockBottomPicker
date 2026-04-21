import SwiftUI
import Charts

// MARK: - 股票详情页

struct StockDetailView: View {
    let stock: StockInfo

    @State private var selectedTimeRange: TimeRange = .fiveYear

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 基本信息
                headerSection

                // 时间范围选择
                timeRangePicker

                // K线图
                klineSection

                // 股东人数趋势
                shareholderSection

                // MACD指标
                macdSection

                // 筹码集中度
                chipSection

                // PE/PB估值
                valuationSection

                // ST风险警示
                if stock.hasSTRisk {
                    stRiskSection
                }

                // 趋势分析
                trendSection
            }
            .padding()
        }
        .navigationTitle(stock.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 基本信息

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(stock.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(stock.id)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "%.2f", stock.currentPrice))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(String(format: "%+.2f%%", stock.priceChangePercent))
                        .foregroundColor(stock.priceChangePercent >= 0 ? .red : .green)
                }
            }

            HStack(spacing: 16) {
                InfoBadge(title: "5年位置", value: String(format: "%.1f%%", stock.fiveYearPosition))
                InfoBadge(title: "2年位置", value: String(format: "%.1f%%", stock.twoYearPosition))
                InfoBadge(title: "2年振幅", value: String(format: "%.0f%%", stock.twoYearAmplitude))
                if stock.twoYearConsolidationMonths > 0 {
                    InfoBadge(title: "震荡月数", value: "\(stock.twoYearConsolidationMonths)")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 时间范围选择

    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: { selectedTimeRange = range }) {
                        Text(range.title)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTimeRange == range ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - K线图

    private var klineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("K线走势")
                .font(.headline)

            if let klines = stock.klineData, !klines.isEmpty {
                KlineChartView(data: filteredKlines(klines))
                    .frame(height: 250)
            } else {
                Text("K线数据暂不可用")
                    .foregroundColor(.secondary)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func filteredKlines(_ klines: [KlineDay]) -> [KlineDay] {
        let now = Date()
        let calendar = Calendar.current
        let cutoffDays: Int

        switch selectedTimeRange {
        case .all: return klines
        case .fiveYear: cutoffDays = 5 * 365
        case .threeYear: cutoffDays = 3 * 365
        case .oneYear: cutoffDays = 365
        case .quarter: cutoffDays = 90
        case .month: cutoffDays = 30
        }

        let cutoffDate = calendar.date(byAdding: .day, value: -cutoffDays, to: now) ?? now

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return klines.filter { day in
            if let date = formatter.date(from: day.date) {
                return date >= cutoffDate
            }
            return true
        }
    }

    // MARK: - 股东人数趋势

    private var shareholderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("股东人数趋势（近20季度）")
                .font(.headline)

            if !stock.shareholderTrend.isEmpty {
                ShareholderChartView(data: stock.shareholderTrend)
                    .frame(height: 200)
            } else {
                Text("数据暂不可用")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - MACD指标

    private var macdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MACD指标")
                    .font(.headline)
                if stock.hasMacdBottomDivergence {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.green)
                        Text("底背离信号")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Text("强度: \(String(format: "%.2f", stock.macdDivergenceStrength))")
                .font(.caption)
                .foregroundColor(.secondary)

            // 简化的MACD示意
            MACDChartView(hasDivergence: stock.hasMacdBottomDivergence)
                .frame(height: 120)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - 筹码集中度

    private var chipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("筹码集中度")
                .font(.headline)

            HStack(spacing: 24) {
                // 仪表盘
                ChipGaugeView(value: stock.chipConcentration, level: stock.chipLevel)
                    .frame(width: 100, height: 100)

                // 说明
                VStack(alignment: .leading, spacing: 4) {
                    Text("集中度: \(String(format: "%.0f%%", stock.chipConcentration))")
                        .font(.subheadline)
                    Text("等级: \(stock.chipLevel)/10")
                        .font(.subheadline)
                    Text(gaugeDescription(for: stock.chipLevel))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func gaugeDescription(for level: Int) -> String {
        switch level {
        case 1...3: return "筹码分散，主力尚未建仓"
        case 4...6: return "筹码相对集中，初步控盘"
        case 7...10: return "高度集中，注意主力出货风险"
        default: return "数据不足"
        }
    }

    // MARK: - PE/PB估值

    private var valuationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("估值水平")
                .font(.headline)

            HStack(spacing: 24) {
                if let pe = stock.pePercentile {
                    PercentileGaugeView(
                        title: "PE百分位",
                        value: pe,
                        description: pe <= 30 ? "历史低位" : (pe <= 70 ? "历史中位" : "历史高位")
                    )
                }

                if let pb = stock.pbPercentile {
                    PercentileGaugeView(
                        title: "PB百分位",
                        value: pb,
                        description: pb <= 30 ? "历史低位" : (pb <= 70 ? "历史中位" : "历史高位")
                    )
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - ST风险

    private var stRiskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("ST风险警示")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            ForEach(stock.stRiskReasons, id: \.self) { reason in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(reason)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 趋势分析

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("趋势分析")
                .font(.headline)

            // 技术指标
            HStack(spacing: 16) {
                IndicatorBadge(title: "MA排列", value: stock.trendAnalysis.ma排列)
                IndicatorBadge(title: "MACD", value: stock.trendAnalysis.macd信号)
                IndicatorBadge(title: "KDJ", value: stock.trendAnalysis.kdj状态)
                IndicatorBadge(title: "RSI", value: String(format: "%.1f", stock.trendAnalysis.rsi值))
            }

            Divider()

            // 趋势描述
            VStack(alignment: .leading, spacing: 8) {
                TrendRow(title: "短期趋势", value: stock.trendAnalysis.shortTerm)
                TrendRow(title: "中期趋势", value: stock.trendAnalysis.mediumTerm)
                TrendRow(title: "长期趋势", value: stock.trendAnalysis.longTerm)
            }

            Divider()

            // 支撑压力
            HStack(spacing: 24) {
                VStack {
                    Text("支撑位")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", stock.trendAnalysis.supportLevel))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                VStack {
                    Text("压力位")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", stock.trendAnalysis.resistanceLevel))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                VStack {
                    Text("风险收益比")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(stock.trendAnalysis.riskRewardRatio)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - 时间范围

enum TimeRange: String, CaseIterable {
    case all = "全部"
    case fiveYear = "5年"
    case threeYear = "3年"
    case oneYear = "1年"
    case quarter = "季线"
    case month = "月线"

    var title: String { rawValue }
}

// MARK: - 辅助视图

struct InfoBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct IndicatorBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TrendRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
