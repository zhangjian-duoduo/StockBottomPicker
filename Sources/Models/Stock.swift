import Foundation

// MARK: - 股票数据模型

struct StockInfo: Codable, Identifiable {
    let id: String
    let name: String
    let currentPrice: Double
    let priceChangePercent: Double

    // 5年数据（要求1用）
    let fiveYearHigh: Double
    let fiveYearLow: Double
    let fiveYearPosition: Double  // 0-100%

    // 2年震荡数据（要求2用）
    let twoYearHigh: Double
    let twoYearLow: Double
    let twoYearConsolidationMonths: Int  // 连续震荡月数
    let twoYearAmplitude: Double  // 振幅%
    let twoYearPosition: Double  // 当前在2年中的位置%

    // 是否满足各条件
    let meetsCondition1: Bool  // 5年位置≤20%
    let meetsCondition2: Bool  // 2年震荡+当前位置≤30%

    // 股东人数趋势
    let shareholderTrend: [ShareholderQuarter]

    // 估值
    let pePercentile: Double?  // PE历史百分位
    let pbPercentile: Double?  // PB历史百分位

    // MACD
    let hasMacdBottomDivergence: Bool
    let macdDivergenceStrength: Double  // 0.0-1.0

    // 筹码
    let chipConcentration: Double  // 0-100%
    let chipLevel: Int  // 1-10集中度等级

    // ST风险
    let hasSTRisk: Bool
    let stRiskReasons: [String]  // 具体原因列表

    // 趋势分析
    let trendAnalysis: TrendAnalysis

    // 新股票标记（本次扫描新增）
    let isNewStock: Bool

    // K线数据（详情页用）
    let klineData: [KlineDay]?

    enum CodingKeys: String, CodingKey {
        case id, name, currentPrice, priceChangePercent
        case fiveYearHigh, fiveYearLow, fiveYearPosition
        case twoYearHigh, twoYearLow, twoYearConsolidationMonths, twoYearAmplitude, twoYearPosition
        case meetsCondition1, meetsCondition2
        case shareholderTrend
        case pePercentile, pbPercentile
        case hasMacdBottomDivergence, macdDivergenceStrength
        case chipConcentration, chipLevel
        case hasSTRisk, stRiskReasons
        case isNewStock
        case trendAnalysis, klineData
    }
}

// MARK: - 股东人数季度数据

struct ShareholderQuarter: Codable, Identifiable {
    var id: String { quarter }
    let quarter: String  // "2024Q1" 格式
    let shareholders: Int  // 股东人数
    let changePercent: Double?  // 环比变化%
}

// MARK: - 趋势分析

struct TrendAnalysis: Codable {
    let shortTerm: String   // 短期趋势
    let mediumTerm: String  // 中期趋势
    let longTerm: String    // 长期趋势
    let supportLevel: Double  // 支撑位
    let resistanceLevel: Double  // 压力位
    let riskRewardRatio: String  // 风险收益比 "2.5:1"
    let ma排列: String  // "多头排列" / "空头排列" / "震荡"
    let macd信号: String  // "金叉" / "死叉" / "震荡"
    let kdj状态: String  // "超买" / "超卖" / "中性"
    let rsi值: Double  // 0-100
}

// MARK: - K线日数据

struct KlineDay: Codable, Identifiable {
    var id: String { date }
    let date: String  // "2024-01-15"
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double  // 成交量
    let ma5: Double?
    let ma10: Double?
    let ma20: Double?
    let ma60: Double?
}

// MARK: - 股票响应

struct StockResponse: Codable {
    let generatedAt: String
    let totalStocks: Int
    let newStockCount: Int?  // 新股票数量
    let stocks: [StockInfo]
}
