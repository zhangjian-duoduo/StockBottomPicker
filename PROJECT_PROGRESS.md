# 项目进度记录 - 2026-04-21

## 阿里云服务器配置 ✅

| 项目 | 值 |
|------|-----|
| 地址 | 8.163.91.16 |
| SSH用户 | root |
| SSH密码 | 6732501Fei@ |
| HTTP端口 | 8888 |
| akshare版本 | 1.18.55 |

### 服务状态
- HTTP服务: `python3 -m http.server 8888 --directory /root` (运行中)
- 数据文件: `/root/stock_data.json` (1.9MB, 1152只)

### 定时任务
```
40 15 * * 1-5 cd /root && python3 stock_scanner_v2.py >> /tmp/scan_v2.log 2>&1
```
每周1-5 下午15:40自动执行全市场扫描

---

## 扫描脚本 v2

**路径**: `/root/stock_scanner_v2.py`

### 功能
- 全市场A股扫描（4500+只）
- 获取腾讯K线数据（5年日线）
- 计算5年位置、2年震荡
- PE/PB百分位（东方财富）
- 股东人数（akshare）
- MACD底背离检测
- 筹码集中度计算
- ST风险检测
- **isNewStock新股票标记**（与上次扫描对比）

### 输出字段
```json
{
  "generatedAt": "2026-04-21T15:40:00",
  "totalStocks": 1152,
  "newStockCount": 5,
  "stocks": [{
    "id": "600004",
    "name": "白云机场",
    "isNewStock": true,
    "hasSTRisk": false,
    "stRiskReasons": [],
    "fiveYearPosition": 18.2,
    "meetsCondition1": true,
    "meetsCondition2": true,
    ...
  }]
}
```

---

## iOS App

**路径**: `/Volumes/移动硬盘/hermes/ios_app/hermes`
**Bundle ID**: com.stockpicker.hermes
**模拟器**: iPhone 17 Pro (PID: 54076)

### 数据加载流程
1. 优先从Bundle加载 `stock_data.json`
2. 同时请求远程 `http://8.163.91.16:8888/stock_data.json`
3. 远程成功则更新本地显示
4. 支持forceRefresh刷新

### 已修改文件

| 文件 | 修改内容 |
|------|----------|
| `Sources/Models/Stock.swift` | 添加`isNewStock`字段、`newStockCount`响应字段 |
| `Sources/Services/DataService.swift` | URL改为.json（非.gz），添加`newStockCount`跟踪 |
| `Sources/Views/ContentView.swift` | 新股票名称显示橙色 |
| `PROJECT_NOTES.md` | 更新阿里云配置和新股票标记说明 |

### 编译状态
- BUILD SUCCEEDED
- INSTALL SUCCEEDED

---

## GitHub

- 仓库: https://github.com/zhangjian-duoduo/StockBottomPicker
- 最新Commit: `6d9036d` feat: 添加isNewStock新股票标记

---

## 扫描结果

**最新扫描**: 2026-04-21 22:38 (全市场扫描)
- **扫描范围**: 5201只A股
- **符合条件**: 1175只
- **数据大小**: 1.3MB
- **数据文件**: http://8.163.91.16:8888/stock_data.json

### 统计
| 指标 | 数量 |
|------|------|
| 满足条件1(5年低位≤20%) | 1086只 |
| 满足条件2(2年震荡) | 411只 |
| MACD底背离 | 1175只 |
| ST风险 | 待统计 |

### 样本数据
```
平安银行(000001) 5年位置: 13.09%
```

## 选股条件

### 要求1（5年低位）
- 5年价格位置 ≤ 20%

### 要求2（2年底部震荡）
- 至少24个月在底部区域震荡
- 当前股价在震荡区间的20%以下
- 无振幅要求

**两条件满足任意一个即可入选**

### 排除项
- ST股票（含退市风险）

---

## 待办事项

- [x] 首次全量扫描（已完成：1175只）
- [ ] Bundle数据更新（255只 → 1175只）
- [ ] 真机调试验证

---

## 自动同步

**同步脚本**: `./sync_progress.sh`

### 使用方式
```bash
# 手动同步
./sync_progress.sh "更新说明"

# 自动同步（每次重要操作后）
git add -A && git commit -m "更新" && git push
```

### 包含文件
- `PROJECT_PROGRESS.md` - 项目进度
- `sync_progress.sh` - 同步脚本
- 所有修改过的源码文件
