import SwiftUI
import Charts

// MARK: - K线图

struct KlineChartView: View {
    let data: [KlineDay]

    var body: some View {
        if data.isEmpty {
            Text("暂无数据")
                .foregroundColor(.secondary)
        } else {
            Chart {
                ForEach(data) { day in
                    // 蜡烛图 - 根据涨跌决定颜色
                    RectangleMark(
                        x: .value("日期", day.date),
                        yStart: .value("开盘", day.open),
                        yEnd: .value("收盘", day.close),
                        width: 4
                    )
                    .foregroundStyle(day.close >= day.open ? Color.red : Color.green)

                    // 上下影线
                    RuleMark(
                        x: .value("日期", day.date),
                        yStart: .value("最低", day.low),
                        yEnd: .value("最高", day.high)
                    )
                    .foregroundStyle(day.close >= day.open ? Color.red : Color.green)
                }

                // 均线
                let ma5Data = data.filter { $0.ma5 != nil }
                if !ma5Data.isEmpty {
                    ForEach(ma5Data) { day in
                        LineMark(
                            x: .value("日期", day.date),
                            y: .value("MA5", day.ma5 ?? 0)
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
    }
}

// MARK: - 股东人数趋势图

struct ShareholderChartView: View {
    let data: [ShareholderQuarter]

    var body: some View {
        if data.isEmpty {
            Text("暂无数据")
                .foregroundColor(.secondary)
        } else {
            Chart {
                ForEach(data) { quarter in
                    BarMark(
                        x: .value("季度", quarter.quarter),
                        y: .value("股东人数", quarter.shareholders)
                    )
                    .foregroundStyle(Color.blue.opacity(0.7))
                }

                // 趋势线
                if data.count >= 2 {
                    let shareholders = data.map { Double($0.shareholders) }
                    let minVal = shareholders.min() ?? 0
                    let maxVal = shareholders.max() ?? 1

                    ForEach(Array(data.enumerated()), id: \.element.id) { index, quarter in
                        LineMark(
                            x: .value("季度", quarter.quarter),
                            y: .value("趋势", quarter.shareholders)
                        )
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
    }
}

// MARK: - MACD图表

struct MACDChartView: View {
    let hasDivergence: Bool

    var body: some View {
        VStack(spacing: 8) {
            // 简化MACD示意
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .cornerRadius(8)

                VStack {
                    HStack {
                        Text("DIF")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("DEA")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    Spacer()

                    // MACD柱状图示意
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<20, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i % 3 == 0 ? Color.red.opacity(0.7) : Color.green.opacity(0.7))
                                .frame(width: 8, height: CGFloat.random(in: 10...50))
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()
                }
            }

            // 底背离提示
            if hasDivergence {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.green)
                    Text("检测到底背离信号：价格创出新低，但MACD未创新低，可能预示反转")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - 筹码集中度仪表盘

struct ChipGaugeView: View {
    let value: Double  // 0-100
    let level: Int  // 1-10

    var body: some View {
        ZStack {
            // 背景圆弧
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(.systemGray5), lineWidth: 10)
                .rotationEffect(.degrees(135))

            // 进度圆弧
            Circle()
                .trim(from: 0, to: CGFloat(value / 100) * 0.75)
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            // 中心显示
            VStack(spacing: 2) {
                Text("\(level)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(gaugeColor)
                Text("集中度")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var gaugeColor: Color {
        switch level {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...10: return .red
        default: return .gray
        }
    }
}

// MARK: - PE/PB百分位仪表盘

struct PercentileGaugeView: View {
    let title: String
    let value: Double  // 0-100
    let description: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: CGFloat(value / 100) * 0.75)
                    .stroke(
                        value <= 30 ? Color.green : (value <= 70 ? Color.orange : Color.red),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))

                VStack(spacing: 0) {
                    Text(String(format: "%.0f", value))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(description)
                .font(.caption2)
                .foregroundColor(value <= 30 ? .green : (value <= 70 ? .orange : .red))
        }
    }
}

// MARK: - 趋势线迷你图（用于列表页）

struct MiniTrendChart: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geo in
            if data.count >= 2 {
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = maxVal - minVal

                Path { path in
                    for (i, val) in data.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(data.count - 1)
                        let y = range > 0 ? geo.size.height * (1 - CGFloat((val - minVal) / range)) : geo.size.height / 2
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 1)
            }
        }
    }
}
