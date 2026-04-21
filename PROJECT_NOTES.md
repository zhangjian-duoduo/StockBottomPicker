# StockBottomPicker - 底部选股iOS App

## 项目概述

A股底部区域股票筛选工具，扫描全市场4592只股票，找出当前股价处于近5年底部位置的标的，并展示股东人数趋势、估值百分位、MACD底背离、筹码集中度等关键指标。

- **Bundle ID**: `com.stockpicker.hermes`
- **iOS版本**: iOS 17.0+
- **主设备**: iPhone 17 Pro UDID: `B73B00C8-EFDA-504F-9617-9E463235EF0A`
- **开发环境**: macOS 26.4.1, Xcode 16+

---

## 选股条件

### 要求1（5年低位）
- 5年价格位置 ≤ 20%
- 即当前股价处于近5年价格的最低20%区间

### 要求2（2年底部震荡）
- 股价在底部区域震荡至少2年（24个月）
- 当前股价处于震荡区间的20%以下
- 无振幅要求

**两条件满足任意一个即可入选**

### 要求3（排除项）
- ST股票（含退市风险）
- 可能有重大利空或可能ST的股票（连续2年亏损、净资产为负、营收<1亿、审计非标等）

---

## 技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                    阿里云服务器 (8.163.91.16)               │
│                                                             │
│  stock_scanner_v18.py                                       │
│  ├── 腾讯K线 API (web.ifzq.gtimg.cn) → 5年K线/股价位置    │
│  ├── 巨潮数据 (cninfo) → 股东人数5年(20季度)趋势              │
│  ├── 东方财富 (value.em) → PE/PB历史百分位                 │
│  ├── 腾讯Level2 → 筹码集中度                               │
│  ├── MACD计算 → 底背离信号检测                             │
│  └── 财务数据 → ST风险判断                                 │
│                           ↓                                  │
│              stock_data.json (35MB, 255只候选股)           │
│                           ↓                                  │
│              HTTP服务 (python3 -m http.server 8888)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓ SSH隧道(本地8889→远程8888)
┌─────────────────────────────────────────────────────────────┐
│                    Mac本地开发                               │
│                                                             │
│  XcodeGen → 生成StockBottomPicker.xcodeproj                 │
│  SwiftUI + Swift Charts → iOS App界面                       │
│                           ↓                                  │
│  App通过HTTP获取真实数据 或 Bundle内置stock_data.json       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓ USB调试
┌─────────────────────────────────────────────────────────────┐
│                    iPhone 17 Pro真机                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 数据源（真实有效）

### 反爬虫策略
- 请求间隔：同一API每次请求间隔1-3秒随机延迟
- User-Agent轮换：使用多个真实浏览器UA
- IP轮换：多IP代理池（可选）
- 失败重试：请求失败后自动切换下一个数据平台
- 限流处理：单平台请求过快时自动降速

### 多平台数据源

| 数据项 | 平台1 | 平台2 | 平台3 |
|--------|-------|-------|-------|
| 5年K线 | 腾讯K线 | 新浪财经 | 东方财富 |
| 股东人数 | 巨潮数据 | 东方财富 | 腾讯 |
| PE/PB百分位 | 东方财富 | 新浪 | 理杏仁 |
| 筹码集中度 | 腾讯Level2 | 东方财富 | - |
| ST风险 | 巨潮数据 | 东方财富 | 同花顺 |

**当平台1获取失败时，自动切换到平台2，依次类推**

**注意：App中所有数据均为真实来源，不含模拟/估算数据（筹码/股东趋势有真实来源，MACD基于真实K线计算）**

---

## iOS App结构

```
StockBottomPicker/
├── project.yml                    # XcodeGen配置
├── StockBottomPicker.xcodeproj/   # 生成的项目
├── Sources/
│   ├── StockBottomPickerApp.swift # App入口
│   ├── Models/
│   │   └── Stock.swift            # 数据模型
│   │                                # StockInfo, ShareholderQuarter,
│   │                                # KlineDay, TrendAnalysis, etc.
│   ├── Services/
│   │   └── DataService.swift       # 数据加载服务
│   │                                # 优先从Bundle加载fallback数据
│   │                                # 同时尝试从HTTP获取最新数据
│   ├── Views/
│   │   ├── ContentView.swift       # 股票列表页
│   │   └── StockDetailView.swift   # 股票详情页
│   ├── Components/
│   │   └── ChartComponents.swift   # Swift Charts图表组件
│   └── scan_hermes.py              # 本地扫描脚本（备用）
├── Resources/
│   └── stock_data.json             # Bundle内置数据(255只真实股票)
└── PROJECT_NOTES.md                # 本文档
```

### 列表页功能
- 股票名称、代码、当前价
- 5年价格位置（彩色进度条）
- 2年震荡标记（月数+幅度）
- 股东人数趋势迷你图
- PE/PB历史百分位
- MACD底背离信号图标
- 筹码集中度图标
- ST风险警告图标
- 筛选开关：☑要求1 ☑要求2 ☑排除ST

### 详情页功能
1. **K线图** - 5年/3年/1年/季线/月线周期切换，Swift Charts绘制
2. **股东人数趋势** - 近5年(20季度)历史折线图
3. **MACD指标** - 带底背离标记
4. **筹码集中度** - 仪表盘显示
5. **PE/PB历史百分位** - 数值+位置图
6. **ST风险警示** - 显示具体原因（连续2年亏损/净资产为负等）
7. **趋势分析** - 规则引擎（MA/MACD/KDJ/RSI/Bollinger）

---

## 阿里云服务器

- **地址**: `root@8.163.91.16`
- **密码**: `6732501Fei@`
- **数据目录**: `/root/`
- **HTTP端口**: 8888
- **扫描脚本**: `/root/stock_scanner_v2.py`

### Crontab自动任务
```
40 15 * * 1-5 cd /root && python3 stock_scanner_v2.py >> /tmp/scan_v2.log 2>&1
```
= 北京时间周一至周五 15:40 自动执行全市场扫描

### HTTP服务启动
```bash
cd /root
python3 -m http.server 8888 --bind 0.0.0.0
```

### 数据格式
```json
{
  "generatedAt": "2026-04-21T15:40:00",
  "totalStocks": 1152,
  "newStockCount": 5,
  "stocks": [
    {
      "id": "600004",
      "name": "白云机场",
      "isNewStock": true,   // 本次新增
      "hasSTRisk": false,
      ...
    }
  ]
}
```

### 新股票标记
- 新股票（本次扫描新增）显示在列表前面
- 新股票名称显示为**橙色**
- 点击刷新按钮获取最新数据

---

## 编译与安装

### 编译
```bash
cd /Volumes/移动硬盘/hermes/ios_app/hermes
xcodegen generate
xcodebuild -project StockBottomPicker.xcodeproj \
  -scheme StockBottomPicker \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### 模拟器运行
```bash
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl install "iPhone 17 Pro" <app-path>
xcrun simctl launch "iPhone 17 Pro" com.stockpicker.hermes
```

### 真机安装（需要UDID授权）
```bash
# 确认设备连接
xcrun devicectl list devices

# 安装
xcrun simctl install "iPhone 17 Pro" <app-path>
xcrun simctl launch "iPhone 17 Pro" com.stockpicker.hermes
```

---

## 历史记录

### 2026-04-21 11:00 - 真实数据扫描完成
- 阿里云扫描全市场4592只A股
- 扫描结果: 255只满足底部条件
- 数据量: 35MB (stock_data.json)
- 数据分割: 5个part文件（各51只）解决大文件传输问题
- 通过SSH隧道下载到本地

### 2026-04-21 07:42 - 首次编译成功
- XcodeGen生成项目
- SwiftUI + Swift Charts实现
- 20只模拟数据用于测试
- 安装到模拟器 PID 74992

### 2026-04-21 初始化
- 用户提出需求：底部选股iOS App
- 确定选股条件、数据源、App功能
- 建立阿里云扫描环境

---

## GitHub仓库

- **仓库**: https://github.com/zhangjian-duoduo/StockBottomPicker
- **分支**: main

### 文件说明
- `Sources/` - iOS App Swift源码
- `Resources/` - App资源文件（含真实数据）
- `PROJECT_NOTES.md` - 项目文档
- `project.yml` - XcodeGen配置
