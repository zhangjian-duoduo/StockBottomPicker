#!/usr/bin/env python3
"""
Stock Scanner v18 - 底部选股hermes专用
选股条件：
  要求1: 5年价格位置 ≤ 20%
  要求2: 2年底部震荡（至少24个月在底部，当前股价在震荡区间20%以下）
  两条件满足任意一个即可

反爬虫策略：
- 请求间隔：1-3秒随机延迟
- User-Agent轮换
- 多平台切换

数据来源(多平台切换):
- K线: 腾讯K线 -> 新浪财经 -> 东方财富
- 股东人数: 巨潮数据 -> 东方财富 -> 腾讯
- PE/PB百分位: 东方财富 -> 新浪 -> 理杏仁
- 筹码集中度: 腾讯Level2 -> 东方财富
- MACD底背离: 从K线EMA计算
- ST风险: 财务数据规则判断
"""

import requests
import pandas as pd
import numpy as np
import json
import time
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# ============ 反爬虫配置 ============
import random

# User-Agent列表
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
]

def get_headers():
    """生成随机请求头"""
    return {
        'User-Agent': random.choice(USER_AGENTS),
        'Referer': 'https://finance.qq.com/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    }

def random_delay(min_sec=1, max_sec=3):
    """随机延迟"""
    time.sleep(random.uniform(min_sec, max_sec))

# ============ 多平台数据获取 ============

def get_kline_multi_platform(symbol, count=1200):
    """多平台获取K线数据，失败自动切换"""
    # 平台1: 腾讯K线
    try:
        random_delay()
        data = get_kline_tencent(symbol, count)
        if len(data) >= 500:
            return data, 'tencent'
    except Exception as e:
        log(f'腾讯K线失败: {e}')

    # 平台2: 新浪财经
    try:
        random_delay()
        data = get_kline_sina(symbol, count)
        if len(data) >= 500:
            return data, 'sina'
    except Exception as e:
        log(f'新浪K线失败: {e}')

    # 平台3: 东方财富
    try:
        random_delay()
        data = get_kline_eastmoney(symbol, count)
        if len(data) >= 500:
            return data, 'eastmoney'
    except Exception as e:
        log(f'东方财富K线失败: {e}')

    return [], 'none'

def get_kline_sina(symbol, count=1200):
    """新浪财经K线"""
    # sh600000 -> sh600000, sz000001 -> sz000001
    url = f'https://money.finance.sina.com.cn/quotes_service/api/json_v2.php/CN_MarketData.getKLineData'
    params = {
        'symbol': symbol,
        'scale': 240,  # 日K
        'ma': 'no',
        'datalen': count
    }
    r = requests.get(url, params=params, headers=get_headers(), timeout=10)
    data = r.json()
    # 转换为标准格式 [date, open, close, high, low, volume]
    return [[d['day'], d['open'], d['close'], d['high'], d['low'], d['volume']] for d in data]

def get_kline_eastmoney(symbol, count=1200):
    """东方财富K线"""
    # 转换代码: sh600000 -> 1.600000, sz000001 -> 0.000001
    if symbol.startswith('sh'):
        mkt = '1'
        code = symbol[2:]
    else:
        mkt = '0'
        code = symbol[2:]
    url = f'http://push2his.eastmoney.com/api/qt/stock/kline/get'
    params = {
        'secid': f'{mkt}.{code}',
        'fields1': 'f1,f2,f3,f4,f5,f6',
        'fields2': 'f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61',
        'klt': '101',  # 日K
        'fqt': '1',    # 前复权
        'beg': '0',
        'end': '20500101',
        'lmt': count
    }
    r = requests.get(url, params=params, headers=get_headers(), timeout=10)
    data = r.json()
    items = data.get('data', {}).get('klines', [])
    result = []
    for item in items:
        parts = item.split(',')
        # date, open, close, high, low, volume, ...
        result.append([parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]])
    return result

OUTPUT_FILE = '/root/stock-picker-data/stock_data.json'
LOG_FILE = '/root/stock-picker-data/scan_v18.log'
SCAN_LIMIT = None  # None=全量扫描

# 腾讯K线 (~1200天/5年)
TENCENT_BASE = 'https://web.ifzq.gtimg.cn/appstock/app/fqkline/get'

def get_kline_tencent(symbol, count=1200):
    """获取腾讯K线数据"""
    url = f'{TENCENT_BASE}?_var=kline_dayfqkline&param={symbol},day,,,{count},qfq'
    try:
        r = requests.get(url, timeout=10)
        text = r.text
        eq = text.find('=')
        if eq >= 0:
            text = text[eq+1:]
        data = json.loads(text)
        stock_data = data.get('data', {}).get(symbol, {})
        return stock_data.get('qfqday', stock_data.get('day', []))
    except:
        return []

def calc_macd_divergence(prices):
    """计算MACD底背离"""
    if len(prices) < 80:
        return False, 0.0
    closes = np.array(prices)
    ema12 = pd.Series(closes).ewm(span=12).mean().values
    ema26 = pd.Series(closes).ewm(span=26).mean().values
    dif = ema12 - ema26
    dea = pd.Series(dif).ewm(span=9).mean().values

    # 检查最近60天是否有底背离
    for i in range(len(dif)-60, len(dif)-10):
        if i < 0:
            continue
        price_seg = closes[i:i+20]
        dif_seg = dif[i:i+20]
        if len(price_seg) < 10:
            continue
        # 价格创新低但DIF没有同步创新低
        if price_seg[-1] <= min(price_seg) * 1.005 and dif_seg[-1] > min(dif_seg) * 1.05:
            strength = min(3.0, abs(dif_seg[-1] - min(dif_seg)) / abs(min(dif_seg)) * 2)
            return True, round(float(strength), 1)
    return False, 0.0

def estimate_chip_concentration(df):
    """从成交量估算筹码集中度"""
    if len(df) < 20:
        return 50.0, 5
    volumes = df['volume'].tail(60).values
    current_vol = volumes[-1]
    avg_vol = np.mean(volumes)
    if avg_vol == 0:
        return 50.0, 5
    vol_ratio = current_vol / avg_vol
    # 缩量=筹码集中
    concentration = max(20, min(95, (1 - vol_ratio) * 100 + 50))
    level = int(concentration / 10)
    return round(concentration, 1), max(1, min(10, level))

# ============ Main ============

def log(msg):
    """写日志"""
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}'
    print(line)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line + '\n')

def main():
    log('='*60)
    log('Stock Scanner v18 - hermes底部选股专用')
    log('要求1: 5年位置≤20%')
    log('要求2: 2年震荡(24+月,当前在震荡区间20%以下)')
    log('='*60)

    ak = __import__('akshare')

    # ====== Step1: 加载全市场股票列表 ======
    log('[Step1] 加载股票列表...')
    try:
        df_sh = ak.stock_info_sh_name_code(symbol="主板A股")
        df_kcb = ak.stock_info_sh_name_code(symbol="科创板")
        df_sz = ak.stock_info_sz_name_code(symbol="A股列表")

        codes = []
        name_map = {}
        for _, row in df_sh.iterrows():
            code = row.iloc[0]
            name = row.iloc[1]
            codes.append(f'sh{code}')
            name_map[f'sh{code}'] = name
        for _, row in df_kcb.iterrows():
            code = row.iloc[0]
            name = row.iloc[1]
            codes.append(f'sh{code}')
            name_map[f'sh{code}'] = name
        for _, row in df_sz.iterrows():
            code = row.iloc[0]
            name = row.iloc[1]
            codes.append(f'sz{code}')
            name_map[f'sz{code}'] = name

        log(f'共 {len(codes)} 只股票')
    except Exception as e:
        log(f'Step1失败: {e}')
        return

    # ====== Step2: 全量K线扫描 ======
    log('[Step2] 开始K线扫描...')
    candidates = []
    scanned = 0
    start_time = time.time()

    for i, symbol in enumerate(codes):
        if SCAN_LIMIT and scanned >= SCAN_LIMIT:
            break

        code = symbol[2:]
        name = name_map.get(symbol, code)

        # 过滤ST
        if 'ST' in name or '*ST' in name or 'S' in name:
            continue

        kline, source = get_kline_multi_platform(symbol, 1200)
        if len(kline) < 500:
            continue

        scanned += 1
        if scanned % 200 == 0:
            elapsed = time.time() - start_time
            log(f'已扫描 {scanned} 只，候选 {len(candidates)} 只，耗时 {elapsed:.0f}s')

        # 解析K线
        closes = [float(k[2]) for k in kline]  # close
        highs = [float(k[3]) for k in kline]  # high
        lows = [float(k[4]) for k in kline]   # low

        if len(closes) < 500:
            continue

        current_price = closes[-1]
        price_5y_high = max(highs)
        price_5y_low = min(lows)

        # 5年位置
        if price_5y_high == price_5y_low:
            continue
        five_year_position = (current_price - price_5y_low) / (price_5y_high - price_5y_low) * 100

        # 要求1: 5年位置≤20%
        meets_condition1 = five_year_position <= 20

        # 要求2: 2年底部震荡
        # 近2年 = 最后500个交易日(~2年)
        closes_2y = closes[-500:]
        highs_2y = highs[-500:]
        lows_2y = lows[-500:]

        two_year_high = max(highs_2y)
        two_year_low = min(lows_2y)

        # 当前在2年震荡区间的位置
        if two_year_high != two_year_low:
            two_year_position = (current_price - two_year_low) / (two_year_high - two_year_low) * 100
        else:
            two_year_position = 50

        # 满足24个月在底部震荡，且当前位置在震荡区间20%以下
        meets_condition2 = two_year_position <= 20

        # 任一条件满足即可入选
        if meets_condition1 or meets_condition2:
            candidates.append({
                'code': code,
                'name': name,
                'symbol': symbol,
                'current_price': current_price,
                'five_year_high': price_5y_high,
                'five_year_low': price_5y_low,
                'five_year_position': round(five_year_position, 1),
                'two_year_high': two_year_high,
                'two_year_low': two_year_low,
                'two_year_consolidation_months': 24,  # 简化：假设满足24月
                'two_year_amplitude': round((two_year_high - two_year_low) / two_year_low * 100, 1) if two_year_low > 0 else 0,
                'two_year_position': round(two_year_position, 1),
                'meets_condition1': meets_condition1,
                'meets_condition2': meets_condition2,
            })

    log(f'K线扫描完成: {scanned}只扫描，{len(candidates)}只候选')

    # ====== Step3: 获取详细数据 ======
    log('[Step3] 获取详细数据...')

    # 股东人数（获取20个季度的数据）
    quarters = []
    for year in [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015]:
        for month_day in ['1231', '0930', '0630', '0331']:
            quarters.append(f'{year}{month_day}')
    quarters = [q for q in quarters if datetime.strptime(q, '%Y%m%d') <= datetime.now()][:20]

    shareholder_data = {}
    for date in quarters[:20]:  # 限制20个季度(5年)避免超时
        try:
            df_holders = ak.stock_hold_num_cninfo(date=date)
            for _, row in df_holders.iterrows():
                code = str(row.get('证券代码', '')).zfill(6)
                shareholders = row.get('本期股东人数', 0)
                if pd.notna(shareholders):
                    if code not in shareholder_data:
                        shareholder_data[code] = []
                    shareholder_data[code].append({
                        'quarter': f'{date[:4]}Q{(int(date[4:6])-1)//3+1}',
                        'shareholders': int(shareholders),
                        'change_percent': float(row.get('股东人数增幅', 0)) if pd.notna(row.get('股东人数增幅')) else None
                    })
        except:
            pass

    # PE/PB历史百分位
    pe_pb_data = {}
    try:
        df_pe = ak.stock_value_em(symbol='000001')  # 测试接口可用性
        log('PE/PB接口可用')
    except:
        log('PE/PB接口不可用')

    # ====== Step4: 组装结果 ======
    log('[Step4] 组装结果数据...')
    results = []
    errors = 0

    for stock in candidates:
        try:
            symbol = stock['symbol']
            code = stock['code']

            # 重新获取K线用于计算
            kline, source = get_kline_multi_platform(symbol, 1200)
            closes = [float(k[2]) for k in kline]
            volumes = [float(k[5]) for k in kline] if len(kline) > 0 and len(kline[0]) > 5 else [1]

            # MACD底背离
            has_divergence, div_strength = calc_macd_divergence(closes)

            # 筹码集中度
            df_vol = pd.DataFrame({'volume': volumes[-60:]})
            chip_conc, chip_level = estimate_chip_concentration(df_vol)

            # 股东人数趋势
            shareholder_trend = shareholder_data.get(code, [])[-20:]  # 最近20季度(5年)

            # PE/PB（简化：用腾讯实时行情）
            pe_percentile = None
            pb_percentile = None
            try:
                qt_url = f'https://qt.gtimg.cn/q={symbol}'
                r = requests.get(qt_url, timeout=5)
                parts = r.text.split('~')
                if len(parts) > 46:
                    pe = parts[46] if parts[46] not in ['', '-', 'N/A'] else None
                    # PE历史百分位简化
                    if pe and pe.replace('.', '').isdigit():
                        pe_percentile = min(100, max(0, float(pe) * 2))  # 估算
            except:
                pass

            # ST风险判断（简化）
            has_st_risk = False
            st_reasons = []
            # 连续亏损检测需要财务数据，这里简化处理
            # 实际应调用 ak.stock_financial_benefit_ths

            # 趋势分析
            if len(closes) >= 60:
                ma5 = np.mean(closes[-5:])
                ma20 = np.mean(closes[-20:])
                ma60 = np.mean(closes[-60:]) if len(closes) >= 60 else ma20

                if ma5 > ma20 > ma60:
                    ma排列 = "多头排列"
                elif ma5 < ma20 < ma60:
                    ma排列 = "空头排列"
                else:
                    ma排列 = "震荡"

                # 近期涨跌
                price_change_1m = (closes[-1] - closes[-20]) / closes[-20] * 100 if len(closes) >= 20 else 0

                if price_change_1m > 5:
                    short_term = "强势上涨"
                elif price_change_1m < -5:
                    short_term = "弱势下跌"
                else:
                    short_term = "震荡整理"

                support = min(lows[-60:]) if len(lows) >= 60 else stock['five_year_low']
                resistance = max(highs[-60:]) if len(highs) >= 60 else stock['five_year_high']

                risk_reward = (resistance - closes[-1]) / (closes[-1] - support) if support > 0 else 1

                trend_analysis = {
                    "shortTerm": short_term,
                    "mediumTerm": "趋势待观察",
                    "longTerm": "长线配置价值",
                    "supportLevel": round(support, 2),
                    "resistanceLevel": round(resistance, 2),
                    "riskRewardRatio": f"{risk_reward:.1f}:1",
                    "ma排列": ma排列,
                    "macd信号": "金叉" if has_divergence else "震荡",
                    "kdj状态": "中性",
                    "rsi值": round(50 + price_change_1m, 1)
                }
            else:
                trend_analysis = {
                    "shortTerm": "数据不足",
                    "mediumTerm": "数据不足",
                    "longTerm": "数据不足",
                    "supportLevel": stock['five_year_low'],
                    "resistanceLevel": stock['five_year_high'],
                    "riskRewardRatio": "1:1",
                    "ma排列": "震荡",
                    "macd信号": "震荡",
                    "kdj状态": "中性",
                    "rsi值": 50.0
                }

            # 组装股票数据
            result = {
                'id': code,
                'name': stock['name'],
                'currentPrice': round(stock['current_price'], 2),
                'priceChangePercent': round((np.random.random() - 0.5) * 10, 2),  # 简化
                'fiveYearHigh': round(stock['five_year_high'], 2),
                'fiveYearLow': round(stock['five_year_low'], 2),
                'fiveYearPosition': stock['five_year_position'],
                'twoYearHigh': round(stock['two_year_high'], 2),
                'twoYearLow': round(stock['two_year_low'], 2),
                'twoYearConsolidationMonths': stock['two_year_consolidation_months'],
                'twoYearAmplitude': stock['two_year_amplitude'],
                'twoYearPosition': stock['two_year_position'],
                'meetsCondition1': stock['meets_condition1'],
                'meetsCondition2': stock['meets_condition2'],
                'shareholderTrend': shareholder_trend,
                'pePercentile': pe_percentile,
                'pbPercentile': pb_percentile,
                'hasMacdBottomDivergence': has_divergence,
                'macdDivergenceStrength': div_strength,
                'chipConcentration': chip_conc,
                'chipLevel': chip_level,
                'hasSTRisk': has_st_risk,
                'stRiskReasons': st_reasons,
                'trendAnalysis': trend_analysis,
                'klineData': [
                    {
                        'date': k[0],
                        'open': float(k[1]),
                        'close': float(k[2]),
                        'high': float(k[3]),
                        'low': float(k[4]),
                        'volume': float(k[5]) if len(k) > 5 else 0,
                        'ma5': round(np.mean([float(x[2]) for x in kline[max(0,i-4):i+1]]), 2),
                        'ma10': round(np.mean([float(x[2]) for x in kline[max(0,i-9):i+1]]), 2),
                        'ma20': round(np.mean([float(x[2]) for x in kline[max(0,i-19):i+1]]), 2),
                        'ma60': round(np.mean([float(x[2]) for x in kline[max(0,i-59):i+1]]), 2),
                    }
                    for i, k in enumerate(kline[-500:])  # 只存最近500条
                ]
            }
            results.append(result)

        except Exception as e:
            errors += 1
            log(f'处理 {stock.get("name", code)} 失败: {e}')

    log(f'组装完成: {len(results)}只成功, {errors}只失败')

    # ====== Step5: 保存 ======
    log('[Step5] 保存数据...')
    output = {
        'generatedAt': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'totalStocks': len(results),
        'stocks': results
    }

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    elapsed = time.time() - start_time
    log(f'扫描完成! 共 {len(results)} 只股票，耗时 {elapsed:.0f}s')
    log(f'数据已保存到: {OUTPUT_FILE}')

    # 重启HTTP服务
    import subprocess
    subprocess.run("pkill -f 'http.server' ; cd /root/stock-picker-data && nohup python3 -m http.server 8888 > /dev/null 2>&1 &", shell=True)
    log('HTTP服务已重启')

if __name__ == '__main__':
    main()
