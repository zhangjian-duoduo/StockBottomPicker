import Foundation

// MARK: - 数据服务

class DataService: ObservableObject {
    static let shared = DataService()

    @Published var stocks: [StockInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var newStockCount: Int = 0  // 新股票数量

    // 远程API地址（阿里云 - gzip压缩版）
    private let remoteURL = "http://8.163.91.16:8888/stock_data.json"

    private init() {}

    // MARK: - 加载数据（本地Bundle优先，失败则请求远程）

    func loadData(forceRefresh: Bool = false) {
        isLoading = true
        errorMessage = nil

        // 1. 先尝试加载Bundle内的兜底数据
        if let bundledStocks = loadBundledData() {
            self.stocks = bundledStocks
            self.lastUpdated = Date()
            print("[DataService] 从Bundle加载了 \(bundledStocks.count) 只股票")
        }

        // 2. 尝试请求远程数据（如果需要刷新或Bundle为空）
        if forceRefresh || stocks.isEmpty {
            fetchRemoteData()
        } else {
            isLoading = false
        }
    }

    // MARK: - 加载Bundle数据

    private func loadBundledData() -> [StockInfo]? {
        guard let url = Bundle.main.url(forResource: "stock_data", withExtension: "json") else {
            print("[DataService] Bundle中未找到stock_data.json")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(StockResponse.self, from: data)
            return response.stocks
        } catch {
            print("[DataService] Bundle数据解析失败: \(error)")
            return nil
        }
    }

    // MARK: - 请求远程数据

    private func fetchRemoteData() {
        guard let url = URL(string: remoteURL) else {
            self.errorMessage = "无效的URL"
            self.isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("[DataService] 网络请求失败: \(error.localizedDescription)")
                    // 网络失败不算错，Bundle兜底数据还在
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "无数据返回"
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(StockResponse.self, from: data)
                    self?.stocks = response.stocks
                    self?.lastUpdated = Date()
                    self?.newStockCount = response.newStockCount ?? 0
                    print("[DataService] 从远程加载了 \(response.stocks.count) 只股票，新股票: \(response.newStockCount ?? 0) 只")
                } catch {
                    print("[DataService] 远程数据解析失败: \(error)")
                    self?.errorMessage = "数据格式错误"
                }
            }
        }.resume()
    }

    // MARK: - 筛选股票

    func filteredStocks(
        showCondition1: Bool,
        showCondition2: Bool,
        excludeSTRisk: Bool,
        searchText: String
    ) -> [StockInfo] {
        var result = stocks

        // 按条件筛选
        if showCondition1 && !showCondition2 {
            result = result.filter { $0.meetsCondition1 }
        } else if showCondition2 && !showCondition1 {
            result = result.filter { $0.meetsCondition2 }
        } else if !showCondition1 && !showCondition2 {
            // 两个都不选，返回空
            return []
        }
        // 如果两个都选，不过滤（OR关系）

        // 排除ST风险
        if excludeSTRisk {
            result = result.filter { !$0.hasSTRisk }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - 获取单只股票详情

    func stockDetail(id: String) -> StockInfo? {
        return stocks.first { $0.id == id }
    }
}
