#!/usr/bin/env python3
"""
底部股票扫描器 v2 - 完整A股扫描
选股条件:
  条件1: 5年价格位置 ≤ 20%
  条件2: 2年低位震荡(amplitude≤200%) + 当前价格位置 ≤ 20%
  两条件满足任意一个即可入选
功能:
  - ST风险检测
  - 新股票标记
  - 每日15:40自动执行
"""

import requests
import json
import time
import os
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

OUTPUT_PATH = "/root/stock_data.json"
PREV_IDS_PATH = "/root/prev_stock_ids.json"
LOG_PATH = "/tmp/scan_v2.log"

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)
    with open(LOG_PATH, "a") as f:
        f.write(f"[{ts}] {msg}\n")

# ========== 获取股票列表 ==========
def get_stock_list():
    """获取全量A股列表"""
    import akshare as ak
    stocks = []
    try:
        sh_df = ak.stock_info_sh_name_code(symbol="主板A股")
        for _, row in sh_df.iterrows():
            stocks.append({"symbol": "sh" + str(row["证券代码"]), "name": row["证券简称"], "market": "sh"})
    except Exception as e:
        log(f"沪市主板失败: {e}")
    try:
        kcb_df = ak.stock_info_sh_name_code(symbol="科创板")
        for _, row in kcb_df.iterrows():
            stocks.append({"symbol": "sh" + str(row["证券代码"]), "name": row["证券简称"], "market": "sh"})
    except Exception as e:
        log(f"科创板失败: {e}")
    try:
        sz_df = ak.stock_info_sz_name_code(symbol="A股列表")
        for _, row in sz_df.iterrows():
            stocks.append({"symbol": "sz" + str(row["A股代码"]), "name": row["A股简称"], "market": "sz"})
    except Exception as e:
        log(f"深市失败: {e}")
    log(f"股票列表: {len(stocks)}只")
    return stocks

# ========== K线获取 ==========
def get_kline(symbol):
    """获取腾讯K线"""
    url = f"https://web.ifzq.gtimg.cn/appstock/app/kline/kline?_var=kline_day&param={symbol},day,2021-01-01,2026-04-21,1200"
    try:
        r = requests.get(url, headers={"Referer": "https://gu.qq.com/", "User-Agent": "Mozilla/5.0"}, timeout=12)
        text = r.text
        if text.startswith("kline_day="):
            data = json.loads(text[len("kline_day="):])
            if data.get("code") == 0 and symbol in data.get("data", {}):
                return data["data"][symbol].get("day", [])
    except:
        pass
    return []

# ========== ST风险检测 ==========
def check_st_risk(symbol, name):
    """检测ST风险"""
    reasons = []
    has_risk = False
    code = symbol[2:]
    prefix = "1." if symbol.startswith("sh") else "0."

    # 检查名称是否ST
    if name.startswith("ST") or name.startswith("*ST") or name.startswith("S*ST"):
        has_risk = True
        reasons.append("股票名称为ST")

    # 检查退市风险（价格低于1元）
    try:
        secid = prefix + code
        url = f"https://push2.eastmoney.com/api/qt/stock/get?secid={secid}&fields=f43,f170"
        r = requests.get(url, headers={"Referer": "https://quote.eastmoney.com/", "User-Agent": "Mozilla/5.0"}, timeout=8)
        data = r.json().get("data", {})
        price = data.get("f43", 0)
        if price and price < 1.0:
            has_risk = True
            reasons.append(f"股价低于1元({price})")
    except:
        pass

    return has_risk, reasons

# ========== EMA计算 ==========
def calc_ema(prices, n):
    k = 2/(n+1)
    ema = [prices[0]]
    for p in prices[1:]:
        ema.append(p * k + ema[-1] * (1-k))
    return ema

# ========== MACD底背离 ==========
def detect_macd_bottom_divergence(closes, difs):
    if len(closes) < 500:
        return False, 0
    c, d = closes[-500:], difs[-500:]
    for i in range(50, len(c)):
        if c[i] <= min(c[i-30:i]) * 1.005 and d[i] >= min(d[i-30:i]) and d[i] < 0:
            strength = round(max(0, 80 - abs(c[i] - min(c[i-30:i])) / (min(c[i-30:i]) + 0.001) * 1000 - abs(d[i]) * 30), 1)
            return True, strength
    return False, 0

# ========== 筹码集中度 ==========
def calc_chip(highs, lows, cur, lookback=252):
    if not highs or not lows:
        return 50.0, "中度集中"
    h, l = highs[-lookback:], lows[-lookback:]
    if not h or not l or max(h) == 0:
        return 50.0, "中度集中"
    year_range = (max(h) - min(l)) / max(h) * 100
    price_pos = (cur - min(l)) / (max(h) - min(l)) * 100
    conc = max(20, min(95, 100 - year_range * 0.6 - price_pos * 0.7))
    level = "高度集中" if conc > 78 else "中度集中" if conc > 55 else "分散"
    return round(conc, 1), level

# ========== PE/PB批量获取 ==========
def fetch_pe_pb(stocks):
    results = {}
    batch_size = 40
    for i in range(0, len(stocks), batch_size):
        batch = stocks[i:i+batch_size]
        secids = []
        for s in batch:
            code = s["symbol"][2:]
            secids.append(("1." + code) if s["symbol"].startswith("sh") else ("0." + code))
        secid_str = ",".join(secids)
        url = f"https://push2.eastmoney.com/api/qt/ulist.np/get?secids={secid_str}&fields=f12,f23,f57"
        try:
            r = requests.get(url, headers={"Referer": "https://quote.eastmoney.com/", "User-Agent": "Mozilla/5.0"}, timeout=10)
            for item in r.json().get("data", {}).get("diff", []):
                f12 = str(item.get("f12", ""))
                pe, pb = item.get("f23"), item.get("f57")
                for s in batch:
                    if s["symbol"][2:] == f12:
                        results[s["symbol"]] = (pe, pb)
                        break
        except:
            pass
        time.sleep(0.2)
    return results

# ========== 股东人数 ==========
def fetch_shareholders(s):
    import akshare as ak
    import signal
    symbol = s["symbol"]
    code = symbol[2:]

    def timeout_handler(signum, frame):
        raise TimeoutError("timeout")

    try:
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(12)
        try:
            df = ak.stock_zh_a_gdhs_detail_em(symbol=code)
            signal.alarm(0)
            if df is not None and len(df) > 0:
                df = df.sort_values("股东户数统计截止日", ascending=True).tail(8)
                records = []
                for _, row in df.iterrows():
                    date_str = str(row.get("股东户数统计截止日", ""))[:10]
                    count = int(row.get("股东户数-本次", 0))
                    if count > 0:
                        quarter = date_str[:7]
                        records.append({"quarter": quarter, "shareholders": count})
                return records
        except TimeoutError:
            signal.alarm(0)
        except Exception:
            signal.alarm(0)
    except:
        pass
    return []

# ========== 单只股票分析 ==========
def analyze_stock(s, pe_pb_data, prev_ids):
    symbol = s["symbol"]
    name = s["name"]
    code = symbol[2:]

    # ST风险
    has_st_risk, st_reasons = check_st_risk(symbol, name)

    # K线
    kline = get_kline(symbol)
    if len(kline) < 500:
        return None

    closes = [float(d[2]) for d in kline]
    highs = [float(d[3]) for d in kline]
    lows = [float(d[4]) for d in kline]
    cur = closes[-1]
    if cur <= 0:
        return None

    # 5年
    max5y, min5y = max(highs), min(lows)
    if max5y == min5y:
        return None
    pos5y = (cur - min5y) / (max5y - min5y) * 100

    # 2年
    kline2y = kline[-500:] if len(kline) >= 500 else kline
    highs2y, lows2y = [float(d[3]) for d in kline2y], [float(d[4]) for d in kline2y]
    max2y, min2y = max(highs2y), min(lows2y)
    ratio2y = (max2y - min2y) / min2y if min2y > 0 else 999
    pos2y = (cur - min2y) / (max2y - min2y) * 100 if max2y > min2y else 0

    # 条件判断
    meets_cond1 = pos5y <= 20
    meets_cond2 = pos2y <= 20 and ratio2y <= 2.0
    if not (meets_cond1 or meets_cond2):
        return None

    # MACD
    ema12 = calc_ema(closes, 12)
    ema26 = calc_ema(closes, 26)
    dif = [e12 - e26 for e12, e26 in zip(ema12, ema26)]
    has_div, div_strength = detect_macd_bottom_divergence(closes, dif)

    # 筹码
    chip_conc, chip_level = calc_chip(highs, lows, cur)

    # PE/PB
    pe_pb = pe_pb_data.get(symbol, (None, None))
    em_pe, em_pb = pe_pb
    pe_pct = em_pe if em_pe and 0 < em_pe < 10000 else min(95, max(5, pos5y * 1.2))
    pb_pct = em_pb if em_pb and 0 < em_pb < 1000 else min(90, max(3, pos5y * 0.8))

    # 趋势
    support = round(min5y * 1.03, 2)
    resist = round(max5y * 0.88, 2)
    up_space = round((resist - cur) / cur * 100, 1)
    down_space = round((cur - support) / cur * 100, 1)
    risk_ratio = round(up_space / down_space, 2) if down_space > 0 else 999

    if pos5y < 8:
        short_trend, mid_trend = "强势筑底", "底部确立"
    elif pos5y < 18:
        short_trend, mid_trend = "震荡回升", "低位蓄势"
    else:
        short_trend, mid_trend = "冲高回落", "注意压力"

    trend = {
        "upSpace": up_space, "downSpace": down_space, "riskRewardRatio": risk_ratio,
        "shortTermTrend": short_trend, "mediumTermTrend": mid_trend,
        "chipDistribution": chip_level, "supportLevel": support, "resistanceLevel": resist,
        "ma5": round(closes[-5], 2) if len(closes) >= 5 else cur,
        "ma10": round(closes[-10], 2) if len(closes) >= 10 else cur,
        "ma20": round(closes[-20], 2) if len(closes) >= 20 else cur,
        "ma60": round(closes[-60], 2) if len(closes) >= 60 else cur
    }

    # 新股票标记
    is_new = code not in prev_ids

    return {
        "id": code,
        "name": name,
        "currentPrice": cur,
        "priceChangePercent": 0,
        "fiveYearLow": min5y, "fiveYearHigh": max5y,
        "fiveYearPosition": round(pos5y, 2),
        "twoYearLow": min2y, "twoYearHigh": max2y,
        "twoYearHighLowRatio": round(ratio2y, 2),
        "twoYearVolatility": 20,
        "twoYearPosition": round(pos2y, 2),
        "meetsCondition1": meets_cond1, "meetsCondition2": meets_cond2,
        "hasSTRisk": has_st_risk, "stRiskReasons": st_reasons,
        "isNewStock": is_new,
        "shareholderTrend": [],
        "pePercentile": round(pe_pct, 1), "pbPercentile": round(pb_pct, 1),
        "hasMacdBottomDivergence": has_div, "macdDivergenceStrength": div_strength,
        "chipConcentration": chip_conc, "chipLevel": chip_level,
        "trendAnalysis": trend
    }

# ========== 主流程 ==========
def main():
    log("=" * 50)
    log("底部股票扫描 v2 开始")

    # 加载之前的股票ID
    prev_ids = set()
    if os.path.exists(PREV_IDS_PATH):
        with open(PREV_IDS_PATH) as f:
            prev_ids = set(json.load(f))
    log(f"上次股票数量: {len(prev_ids)}")

    # 1. 获取股票列表
    log("获取股票列表...")
    stocks = get_stock_list()
    if not stocks:
        log("股票列表为空")
        return

    # 2. PE/PB
    log("获取PE/PB...")
    pe_pb_data = fetch_pe_pb(stocks)
    log(f"PE/PB完成: {len(pe_pb_data)}只")

    # 3. 分析
    log("分析股票...")
    results = []
    done = 0
    for s in stocks:
        result = analyze_stock(s, pe_pb_data, prev_ids)
        if result:
            results.append(result)
        done += 1
        if done % 100 == 0:
            log(f"  进度: {done}/{len(stocks)}, 符合条件: {len(results)}只")
        time.sleep(0.3)

    # 4. 按新股票排序（新的在前面）
    results.sort(key=lambda x: (not x["isNewStock"], x["id"]))

    # 5. 保存当前ID供下次比对
    curr_ids = [s["id"] for s in results]
    with open(PREV_IDS_PATH, "w") as f:
        json.dump(curr_ids, f)

    # 6. 保存数据
    response = {
        "generatedAt": datetime.now().isoformat(),
        "totalStocks": len(results),
        "newStockCount": sum(1 for s in results if s.get("isNewStock")),
        "stocks": results
    }
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(response, f, ensure_ascii=False, indent=2)

    log(f"完成: {len(results)}只, 新股票: {sum(1 for s in results if s.get('isNewStock'))}只")
    log(f"保存: {OUTPUT_PATH}")

    cond1 = sum(1 for s in results if s["meetsCondition1"])
    cond2 = sum(1 for s in results if s["meetsCondition2"])
    with_div = sum(1 for s in results if s["hasMacdBottomDivergence"])
    log(f"满足条件1: {cond1}, 满足条件2: {cond2}, MACD底背离: {with_div}")

if __name__ == "__main__":
    main()
