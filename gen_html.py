import csv, io, re

with open('C:/CludeHome/projects/XQ_XS/wMA20_redraw.csv', encoding='cp950', errors='replace') as f:
    content = f.read()

lines = content.splitlines()
date_str = lines[1].strip().replace('資料日期：','').strip()

header_line = lines[3]
reader = csv.reader(io.StringIO(header_line))
headers = next(reader)

rows = []
for line in lines[4:]:
    if not line.strip():
        continue
    try:
        r = next(csv.reader(io.StringIO(line)))
        if len(r) > 2 and re.match(r'\d{4}\.TW', r[1].strip()):
            rows.append([c.strip().lstrip('\t') for c in r])
    except:
        pass

def chg_color(v):
    try:
        f = float(v)
        if f > 0: return '#34d399'
        if f < 0: return '#f87171'
    except: pass
    return '#94a3b8'

def dev_color(v):
    try:
        f = float(v)
        if f > 1: return '#34d399'
        if f < -1: return '#f87171'
    except: pass
    return '#e2e8f0'

def alert_badge(v):
    try:
        if int(v) == 0:
            return '<span class="badge safe">0 安全</span>'
        else:
            return '<span class="badge warn">1 警示</span>'
    except:
        return v

def tv_url(code):
    # code 格式 "2330.TW" → TWSE:2330，週線
    ticker = code.replace('.TW', '')
    return f'https://www.tradingview.com/chart/?symbol=TWSE:{ticker}&interval=W'

def tr_row(r):
    code    = r[1]
    name    = r[2]
    price   = r[3]
    chg     = r[4]
    dev     = r[6]
    maxDev  = r[7]
    pullback= r[8]
    ptrough = r[9]
    peakbar = r[10]
    volratio= r[12]
    angle   = r[13]
    alert   = r[16]
    chival  = r[18]
    mktcap  = r[19]
    sector  = r[21] if len(r) > 21 else ''

    chg_c = chg_color(chg)
    dev_c = dev_color(dev)
    try:
        angle_f = float(angle)
        angle_c = '#34d399' if angle_f > 2 else ('#fb923c' if angle_f > 0 else '#f87171')
    except:
        angle_c = '#e2e8f0'
    try:
        vr = float(volratio)
        volratio_c = '#34d399' if vr < 0.6 else ('#fb923c' if vr < 0.85 else '#f87171')
    except:
        volratio_c = '#e2e8f0'

    return (
        f'    <tr>\n'
        f'      <td><a class="stock-link" href="{tv_url(code)}" target="_blank" rel="noopener"><strong class="name">{name}</strong><br><span class="code">{code}</span></a></td>\n'
        f'      <td class="num">{price}</td>\n'
        f'      <td class="num" style="color:{chg_c}">{chg}%</td>\n'
        f'      <td class="num" style="color:{dev_c}">{dev}%</td>\n'
        f'      <td class="num">{maxDev}%</td>\n'
        f'      <td class="num">{pullback}%</td>\n'
        f'      <td class="num">{ptrough}%</td>\n'
        f'      <td class="num">{peakbar}</td>\n'
        f'      <td class="num" style="color:{angle_c}">{angle}</td>\n'
        f'      <td class="num" style="color:{volratio_c}">{volratio}</td>\n'
        f'      <td class="num">{alert_badge(alert)}</td>\n'
        f'      <td class="num">{chival}</td>\n'
        f'      <td class="num">{mktcap}</td>\n'
        f'      <td class="sector">{sector}</td>\n'
        f'    </tr>'
    )

table_rows = '\n'.join(tr_row(r) for r in rows)

html = '''<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>週MA20量縮回測選股 — ''' + date_str + '''</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #080e18;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans TC", sans-serif;
      font-size: 14px;
      line-height: 1.7;
      padding: 32px 16px 60px;
    }
    .container { max-width: 1400px; margin: 0 auto; }
    header { margin-bottom: 24px; border-bottom: 1px solid #2d3f55; padding-bottom: 20px; }
    .tag {
      display: inline-block;
      background: #0f2040;
      border: 1px solid rgba(59,130,246,0.3);
      color: #93c5fd;
      font-size: 11px;
      padding: 2px 10px;
      border-radius: 4px;
      margin-bottom: 10px;
      letter-spacing: 0.05em;
    }
    h1 { font-size: 22px; font-weight: 700; color: #e2e8f0; margin-bottom: 6px; }
    .meta { color: #94a3b8; font-size: 13px; }
    .count { color: #3b82f6; font-weight: 700; }
    .table-wrap {
      overflow-x: auto;
      border: 1px solid #2d3f55;
      border-radius: 10px;
    }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    thead { background: #0f2040; position: sticky; top: 0; z-index: 1; }
    th {
      padding: 10px 12px;
      text-align: left;
      color: #93c5fd;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.05em;
      border-bottom: 1px solid #2d3f55;
      white-space: nowrap;
      cursor: pointer;
      user-select: none;
    }
    th:hover { color: #e2e8f0; }
    th.sort-asc::after  { content: " ↑"; color: #fb923c; }
    th.sort-desc::after { content: " ↓"; color: #fb923c; }
    td { padding: 10px 12px; border-bottom: 1px solid #1e2d42; vertical-align: middle; }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(59,130,246,0.06); }
    tr:nth-child(even) td { background: rgba(19,31,46,0.4); }
    tr:nth-child(even):hover td { background: rgba(59,130,246,0.06); }
    .name { font-size: 14px; font-weight: 600; color: #e2e8f0; }
    .code { font-size: 11px; color: #64748b; font-family: monospace; }
    .num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
    .sector { color: #94a3b8; font-size: 12px; }
    .stock-link { text-decoration: none; display: block; }
    .stock-link:hover .name { color: #60a5fa; text-decoration: underline; }
    .badge {
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 4px;
    }
    .badge.safe { background: rgba(52,211,153,0.15); color: #34d399; border: 1px solid rgba(52,211,153,0.3); }
    .badge.warn { background: rgba(239,68,68,0.15);  color: #f87171; border: 1px solid rgba(239,68,68,0.3); }
    .legend {
      display: flex;
      gap: 20px;
      flex-wrap: wrap;
      margin-top: 14px;
      font-size: 12px;
      color: #94a3b8;
    }
    .legend span { display: flex; align-items: center; gap: 6px; }
    .dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
    footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid #2d3f55; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
<div class="container">

  <header>
    <div class="tag">週K線選股 · wMA20_redraw</div>
    <h1>週MA20 量縮回測選股</h1>
    <p class="meta">資料日期：''' + date_str + ''' &nbsp;·&nbsp; 篩選結果：<span class="count">''' + str(len(rows)) + ''' 檔</span></p>
    <div class="legend">
      <span><span class="dot" style="background:#34d399"></span>正值 / 低量比 / 安全</span>
      <span><span class="dot" style="background:#fb923c"></span>中等</span>
      <span><span class="dot" style="background:#f87171"></span>負值 / 高量比 / 警示</span>
      <span>點擊欄位標題可排序</span>
    </div>
  </header>

  <div class="table-wrap">
    <table id="mainTable">
      <thead>
        <tr>
          <th onclick="sortTable(0)">股票</th>
          <th onclick="sortTable(1)">成交</th>
          <th onclick="sortTable(2)">漲幅</th>
          <th onclick="sortTable(3)">當前乖離</th>
          <th onclick="sortTable(4)">最大正乖離</th>
          <th onclick="sortTable(5)">近高回檔</th>
          <th onclick="sortTable(6)">峰谷落差</th>
          <th onclick="sortTable(7)">峰值(週)</th>
          <th onclick="sortTable(8)">MA20角度</th>
          <th onclick="sortTable(9)">量/峰值量</th>
          <th onclick="sortTable(10)">長黑爆量</th>
          <th onclick="sortTable(11)">成值(億)</th>
          <th onclick="sortTable(12)">市值(百萬)</th>
          <th>細產業</th>
        </tr>
      </thead>
      <tbody>
''' + table_rows + '''
      </tbody>
    </table>
  </div>

  <footer>
    <p>策略：週MA20量縮回測選股 · 執行環境：XQ 全球贏家 / 週K線選股腳本 · 資料日期：''' + date_str + '''</p>
  </footer>

</div>
<script>
  let sortCol = -1, sortDir = 1;
  function getVal(td) {
    const txt = td.innerText.replace(/%/g,'').replace(/,/g,'').trim();
    const n = parseFloat(txt);
    return isNaN(n) ? txt.toLowerCase() : n;
  }
  function sortTable(col) {
    const table = document.getElementById('mainTable');
    const ths   = table.querySelectorAll('th');
    const tbody = table.querySelector('tbody');
    const rows  = Array.from(tbody.querySelectorAll('tr'));
    if (sortCol === col) sortDir *= -1;
    else { sortCol = col; sortDir = 1; }
    ths.forEach((th, i) => {
      th.classList.remove('sort-asc','sort-desc');
      if (i === col) th.classList.add(sortDir === 1 ? 'sort-asc' : 'sort-desc');
    });
    rows.sort((a, b) => {
      const av = getVal(a.querySelectorAll('td')[col]);
      const bv = getVal(b.querySelectorAll('td')[col]);
      return av < bv ? -sortDir : av > bv ? sortDir : 0;
    });
    rows.forEach(r => tbody.appendChild(r));
  }
</script>
</body>
</html>'''

with open('C:/CludeHome/projects/XQ_XS/wMA20_redraw.html', 'w', encoding='utf-8') as f:
    f.write(html)

print(f'Done. {len(rows)} rows.')
