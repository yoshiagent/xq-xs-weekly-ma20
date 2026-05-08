// ============================================================
// 策略名稱：週MA20量縮回測選股
// 執行環境：選股腳本（Screener）/ 週K線圖
// 策略邏輯：
//   1. 週MA20 斜率向上（多頭趨勢確認）
//   2. 近期曾有顯著正乖離（股價一度強勢衝高）
//   3. 峰值已在 2 週前以上（確認回測已啟動）
//   4. 目前以量縮方式回測（修正非恐慌賣壓）
//   5. 當前乖離率已收斂至週MA20附近
// 版本日期：2026-05-08
// 修正紀錄：
//   v2 - 使用 GetField("Close","W") 明確取週資料
//   v3 - 改用 xf_GetValue("W",Wma20,1) 取前一週MA20，消除警告
//   v4 - 加入 NthHighestBar 確認峰值已在 2 週前以上
//   v5 - 加入 NthLowestBar 谷底位置、峰谷落差、壓力/支撐量計算
//   v6 - 加入高檔長黑爆量警訊計數
//   v7 - 改用週 High 取峰值、週 Low（2x 回看）取谷底
// ============================================================

// 確保足夠的歷史 K 棒長度
SetTotalBar(260);

// ── 參數設定 ────────────────────────────────────────────
var: paramDevHigh(8.0);     // 正乖離觸發門檻（%）
var: paramDevNear(3.0);     // 回測完成門檻（%）
var: paramVolRatio(0.85);   // 量縮比例閾值
var: paramLookback(13);     // 回看週數
var: paramVolMa(10);        // 均量計算期數
var: paramPeakDelay(2);     // 峰值需在幾週前以上才確認回測啟動
var: paramLongBlack(3.0);   // 長黑實體門檻（%）：開盤 vs 收盤跌幅超過此值視為長黑
var: paramHeavyVol(1.5);    // 爆量倍數門檻：成交量 > 均量 × 此倍數視為爆量

// ── 週資料（明確指定頻率）───────────────────────────────
var: wClose(0), wVol(0), Wma20(0);

wClose = GetField("Close", "W");
wVol   = GetField("Volume", "W");
Wma20  = Average(GetField("Close", "W"), 20);

// ── 計算核心變數 ─────────────────────────────────────────
var: devNow(0);
var: highestHigh(0), highestDev(0);
var: lowestLow(0), peakToTrough(0);
var: volMaVal(0), volRatioNow(0);
var: peakBar(0), troughBar(0);
var: pullbackPct(0);

// 當前日收盤對週MA20 的乖離率（%）
if Wma20 <> 0 then
    devNow = (GetField("Close", "D") - Wma20) / Wma20 * 100
else
    devNow = 0;

// 回看期間週高點最高值 / 週低點最低值（低點用 2x 回看抓更深支撐）
highestHigh = Highest(GetField("High", "W"), paramLookback);
lowestLow   = Lowest(GetField("Low", "W"), 2*paramLookback);

// 歷史最大正乖離率（%）
if Wma20 <> 0 then
    highestDev = (highestHigh - Wma20) / Wma20 * 100
else
    highestDev = 0;

// 峰谷落差（%）：從高點到回測谷底跌了多少（5-20% 為合理洗盤區間）
if highestHigh <> 0 then
    peakToTrough = (highestHigh - lowestLow) / highestHigh * 100
else
    peakToTrough = 0;

// 週均量與量縮比值
volMaVal = Average(wVol, paramVolMa);
if volMaVal <> 0 then
    volRatioNow = wVol / volMaVal
else
    volRatioNow = 1;

// 從近期最高週收盤回檔至今日收盤的幅度（%）
if highestHigh <> 0 then
    pullbackPct = (highestHigh - GetField("Close", "D")) / highestHigh * 100
else
    pullbackPct = 0;

// 峰值距今幾根週K棒（以週 High 取峰，與 highestHigh 一致）
peakBar = NthHighestBar(1, GetField("High", "W"), paramLookback);

// 谷底距今幾根週K棒（以週 Low 取谷，與 lowestLow 一致，回看 2x）
troughBar = NthLowestBar(1, GetField("Low", "W"), 2*paramLookback);

// ── 壓力量 / 支撐量計算 ──────────────────────────────────
// 以今日收盤為分界，遍歷回看期間每根週K棒：
//   壓力量：週收盤 > 今日收盤 → 價位之上的歷史成交量（解套賣壓）
//   支撐量：前低 <= 週收盤 <= 今日收盤 → 今日價至前低之間的歷史成交量（套牢支撐）
var: i(0), volAbove(0), volBelow(0), curPrice(0);
var: alertCount(0), blackBody(0);   // 高檔長黑爆量警訊計數、實體幅度暫存

curPrice = GetField("Close", "D");

for i = 0 to paramLookback - 1 begin
    // 壓力：週收盤在當前價位之上
    if GetField("Close", "W")[i] > curPrice then
        volAbove = volAbove + GetField("Volume", "W")[i];

    // 支撐：週收盤介於前一谷底到當前價位之間
    if GetField("Low", "W")[i] >= lowestLow and
       GetField("Close", "W")[i] <= curPrice then
        volBelow = volBelow + GetField("Volume", "W")[i];
end;

// 高檔長黑爆量警訊：只檢查近期峰值那根週K棒
// 峰值週若為長黑（實體跌幅 >= paramLongBlack%）且爆量，視為高檔出貨訊號
if GetField("Open", "W")[peakBar] <> 0 then
    blackBody = (GetField("Open", "W")[peakBar] - GetField("Close", "W")[peakBar])
                / GetField("Open", "W")[peakBar] * 100
else
    blackBody = 0;

if blackBody >= paramLongBlack
   and GetField("Volume", "W")[peakBar] > volMaVal * paramHeavyVol then
    alertCount = 1;

// ── 布林輔助旗標 ─────────────────────────────────────────
var: isMaRising(false);
var: hadHighDev(false);
var: isPeakPast(false);
var: isNearMa(false);
var: isVolShrink(false);

// 條件一：週MA20 上揚
if Wma20 > xf_GetValue("W", Wma20, 1) then
    isMaRising = true
else
    isMaRising = false;

// 條件二：曾有顯著正乖離
if highestDev >= paramDevHigh then
    hadHighDev = true
else
    hadHighDev = false;

// 條件三：峰值已在 paramPeakDelay 週前以上
if peakBar >= paramPeakDelay then
    isPeakPast = true
else
    isPeakPast = false;

// 條件四：當前乖離率收斂至均線附近
if devNow <= paramDevNear and devNow >= (-1 * paramDevNear) then
    isNearMa = true
else
    isNearMa = false;

// 條件五：量縮
if volRatioNow < paramVolRatio then
    isVolShrink = true
else
    isVolShrink = false;

// ── 選股觸發 ─────────────────────────────────────────────
// 條件：週MA20上揚 + 開始回檔 + 股價 >= 50
if isMaRising = true
   and peakBar >= 1
   and pullbackPct > 0
   and curPrice >= 50
then begin
    ret = 1;

    // 九宮格輸出欄位
    OutputField1(devNow,        "當前乖離率(%)");
    OutputField2(pullbackPct,   "近高回檔幅度(%)");
    OutputField3(peakToTrough,  "峰谷落差(%)");
    OutputField4(peakBar,       "峰值距今(週)");
    OutputField5(troughBar,     "谷底距今(週)");
    OutputField6(volRatioNow,   "量/均量比值");
    OutputField7(highestDev,    "期間最大正乖離(%)");
    OutputField8(volAbove,      "壓力量(週加總)");
    OutputField9(volBelow,      "支撐量(週加總)");
    OutputField10(alertCount,   "高檔長黑爆量(次)");
end;
