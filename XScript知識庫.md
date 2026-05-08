# XScript 知識庫 — 快速參考手冊

> 根據 XQ 官方語法文件整理，撰寫腳本前請先對照此文件

---

## 一、硬性語法規則（違反即編譯失敗）

| 規則 | 正確 | 錯誤 |
|------|------|------|
| 變數命名：只能英數、駝峰式 | `volToday`, `maUp` | `vol_today`, `daily_vol` |
| 禁用底線 `_` | `maRising` | `ma_rising` |
| 禁用 `daily` 字串在變數名 | `volToday` | `dailyVol` |
| 等於判斷用單一等號 | `if x = 1` | `if x == 1` |
| 不等於 | `<>` | `!=` |
| 所有變數需在 `var:` 區塊宣告 | `var: myVal(0);` | 直接使用未宣告變數 |
| 除法必須防呆 | `if b <> 0 then x = a / b else x = 0;` | `x = a / b;` |
| 長天期歷史 K 棒 | 開頭加 `SetTotalBar(N);` | 直接讀取超出預設長度 |

---

## 二、腳本類型差異對照

| 功能 | 選股腳本（Screener） | 警示腳本（Sensor） |
|------|-------------------|--------------------|
| 觸發 | `ret = 1;` | `ret = 1;` |
| 輸出欄位 | `OutputField1(值, "名稱");` | **禁用** OutputField |
| 推播文字 | 不適用 | `retmsg = "文字" + NumToStr(值, 2);` |
| 漲跌幅欄位 | 可直接 `GetField("漲跌幅","D")` | 必須手動計算 |

---

## 三、週期資料取得（重要）

在選股腳本中，**不可直接用 `Close`、`Volume` 等內建變數**讀取週資料，
必須明確用 `GetField` 指定頻率：

```pascal
var: wClose(0), wVol(0), Wma20(0);
wClose = GetField("Close", "W");               // 週收盤價
wVol   = GetField("Volume", "W");              // 週成交量
Wma20  = Average(GetField("Close","W"), 20);   // 週MA20（直接傳入序列）

// 日收盤（與週指標比較時使用）
GetField("Close", "D")
```

| 頻率 | 第二參數 |
|------|---------|
| 日 | `"D"` |
| 週 | `"W"` |
| 月 | `"M"` |
| 季 | `"Q"` |
| 年 | `"Y"` |

### ⚠️ 取前 N 期值：必須用 xf_GetValue，禁用 [n] 於函數參數為變數時

當 `Average()`、`Highest()` 等函數的**第一參數是 var: 變數**時，
在函數後加 `[n]` 系統會警告，正確做法是改用 `xf_GetValue`：

```pascal
// ❌ 錯誤：Average 第一參數為變數時，[1] 會觸發警告
Average(wClose, 20)[1]

// ✅ 正確：先把結果存入 var: 變數，再用 xf_GetValue 取前一期
var: Wma20(0);
Wma20 = Average(GetField("Close","W"), 20);

// 取前一根週K棒的 Wma20（官方正確寫法）
xf_GetValue("W", Wma20, 1)
```

**`xf_GetValue` 語法：**
```
xf_GetValue("頻率", 變數名, 往前N期)
```

實戰範例（判斷週MA20上揚）：
```pascal
if Wma20 > xf_GetValue("W", Wma20, 1) then isMaRising = true;
```

---

## 四、NthHighestBar — 極大值位置函數

計算序列資料的第 N 個極大值距當期 K 棒的**相對位置（距今幾根棒）**。

```
回傳值 = NthHighestBar(第幾個極大值, 數列, 期數)
```

| 參數 | 說明 |
|------|------|
| 第1參數 | 要取第幾個極大值（1 = 最高，2 = 次高…） |
| 第2參數 | 價格數列（Close、High、GetField("Close","W") 等） |
| 第3參數 | 回看期數 |

**實戰應用：確認峰值已在 N 週前（回測啟動確認）**

```pascal
var: peakBar(0);
peakBar = NthHighestBar(1, GetField("Close","W"), 13);
// peakBar = 0  → 最高點在本週（尚未開始回測）
// peakBar >= 2 → 最高點在 2 週前以上（回測已啟動）
if peakBar >= 2 then ...  // 確認回測已在進行中
```

**與 `Highest` 的差異：**
- `Highest(series, N)` → 回傳最高**值**
- `NthHighestBar(1, series, N)` → 回傳最高值距今**幾根棒**

---

## 五、常用函數速查

```
// 均線
Average(Close, 20)          // 20 期均線
Average(Close, 20)[1]       // 前一根 K 棒的均線值

// 最高/最低
Highest(Close, 13)          // 近 13 根最高收盤
Lowest(Low, 13)             // 近 13 根最低低點

// 交叉
CrossOver(MA5, MA20)        // 黃金交叉（MA5 由下往上穿越 MA20）
CrossUnder(MA5, MA20)       // 死亡交叉

// 標準差
StandardDev(Close, 20, 1)   // 20 期樣本標準差

// 字串轉數值輸出（警示腳本用）
NumToStr(值, 小數位數)
```

---

## 四、GetField 欄位正確名稱字典

### 財報類（錯一個字就讀不到）

| 資料 | 正確欄位名稱 | 常見錯誤 |
|------|------------|---------|
| EPS | `每股稅後淨利(元)` | 每股盈餘、EPS |
| 負債 | `負債總額` | 總負債 |
| 資產 | `資產總額` | 總資產 |
| 企業價值 | `企業價值` | — |
| 現金流估值 | `股價自由現金流比` | 股價現金流比 |
| 內部人持股 | `董監持股佔股本比例` | 董監持股比例 |

### 營收成長率（依頻率變形）

| 頻率 | 正確欄位 |
|------|---------|
| 年 `"Y"` / 季 `"Q"` | `營收成長率` |
| 月 `"M"` | `營收年增率` |

### 即時欄位 GetQuote 常用

```
GetQuote("q_DailyOpen")      // 今日開盤價
GetQuote("q_DailyVolume")    // 今日累積成交量
GetQuote("q_BestBid1")       // 最佳買價
GetQuote("q_BestAsk1")       // 最佳賣價
```

---

## 五、標準腳本架構模板

```pascal
// 策略說明
SetTotalBar(260);   // 週K需足夠長度（260週≒5年）

// 參數宣告
input: paramA(20);

// 變數宣告
var: result(0), flag(false);

// 計算邏輯
if 分母 <> 0 then
    result = 分子 / 分母
else
    result = 0;

// 條件判斷
if 條件A = true and 條件B = true then begin
    ret = 1;
    OutputField1(result, "欄位名稱");
end;
```

---

## 六、Self-Check 清單（每次完稿前確認）

- [ ] 變數名稱無底線、無 `daily` 字串
- [ ] 等號判斷為單一 `=`，不等於為 `<>`
- [ ] 所有變數已在 `var:` 區塊宣告並給初始值
- [ ] 所有除法有 `<> 0` 防呆
- [ ] 若用長天期資料，已加 `SetTotalBar(N)`
- [ ] 選股腳本：用 `OutputField`，不用 `retmsg`
- [ ] 警示腳本：用 `retmsg`，不用 `OutputField`
- [ ] GetField 欄位名稱對照字典確認無誤

---

*文件來源：XScript 官方語法說明文件 / 實戰範例寶典（2026-05-08 整理）*
