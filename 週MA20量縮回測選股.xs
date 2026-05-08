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
// ============================================================

// 確保足夠的歷史 K 棒長度（週K 20MA + 回看 26 週）
SetTotalBar(260);

// ── 參數設定 ────────────────────────────────────────────
// 正乖離觸發門檻（%）：股價曾高於週MA20 多少才算「乖離過大」
var: paramDevHigh(8.0);

// 回測完成門檻（%）：當前乖離率的絕對值小於此值，視為回到均線附近
var: paramDevNear(3.0);

// 量縮判斷：目前量 < 均量的比例倍數（<1 = 量縮）
var: paramVolRatio(0.85);

// 回看週數：往前幾根週K棒內確認曾有高乖離
var: paramLookback(13);

// 均量計算期數（週）
var: paramVolMa(10);

// 峰值需在幾週前以上，才確認回測已啟動（0 = 本週仍在高點，不符合）
var: paramPeakDelay(2);

// ── 週資料（明確指定頻率）───────────────────────────────
var: wClose(0), wVol(0), Wma20(0);

wClose = GetField("Close", "W");               // 週收盤價
wVol   = GetField("Volume", "W");              // 週成交量
Wma20  = Average(GetField("Close", "W"), 20);  // 週MA20

// ── 計算核心變數 ─────────────────────────────────────────
var: devNow(0);
var: highestClose(0), highestDev(0);
var: volMaVal(0), volRatioNow(0);
var: peakBar(0);
var: pullbackPct(0);    // 從近期最高週收盤回檔至今日收盤的幅度（%）

// 當前日收盤對週MA20 的乖離率（%）
// 用 GetField("Close","D") 取日收盤，與週MA20比較
if Wma20 <> 0 then
    devNow = (GetField("Close", "D") - Wma20) / Wma20 * 100
else
    devNow = 0;

// 回看期間內的最高週收盤（用來計算歷史最大正乖離）
highestClose = Highest(wClose, paramLookback);

// 歷史最大正乖離率（%）
if Wma20 <> 0 then
    highestDev = (highestClose - Wma20) / Wma20 * 100
else
    highestDev = 0;

// 週均量
volMaVal = Average(wVol, paramVolMa);

// 當前量與均量的比值
if volMaVal <> 0 then
    volRatioNow = wVol / volMaVal
else
    volRatioNow = 1;

// 最高週收盤距今幾根週K棒
// 回傳 0 = 本週就是最高點（尚未開始回測）；>= 2 = 峰值已過，回測啟動中
peakBar = NthHighestBar(1, GetField("Close", "W"), paramLookback);

// 從近期最高週收盤回檔至今日收盤的幅度（%），正值代表已下跌
if highestClose <> 0 then
    pullbackPct = (highestClose - GetField("Close", "D")) / highestClose * 100
else
    pullbackPct = 0;

// ── 布林輔助旗標 ─────────────────────────────────────────
var: isMaRising(false);     // 週MA20 斜率向上
var: hadHighDev(false);     // 曾有顯著正乖離
var: isPeakPast(false);     // 峰值已在 paramPeakDelay 週前以上
var: isNearMa(false);       // 當前已回到均線附近（乖離收斂）
var: isVolShrink(false);    // 量縮確認

// 條件一：週MA20 上揚
// xf_GetValue("W", Wma20, 1) = 取前一根週K棒的 Wma20 值（官方正確寫法）
if Wma20 > xf_GetValue("W", Wma20, 1) then
    isMaRising = true
else
    isMaRising = false;

// 條件二：回看期間內曾有正乖離 >= paramDevHigh
if highestDev >= paramDevHigh then
    hadHighDev = true
else
    hadHighDev = false;

// 條件三：峰值已在 paramPeakDelay 週前以上（確認回測已啟動，非本週才見頂）
if peakBar >= paramPeakDelay then
    isPeakPast = true
else
    isPeakPast = false;

// 條件四：當前乖離率絕對值 <= paramDevNear（回到均線附近）
// 允許略低於MA20（-paramDevNear ~ +paramDevNear）
if devNow <= paramDevNear and devNow >= (-1 * paramDevNear) then
    isNearMa = true
else
    isNearMa = false;

// 條件五：量縮（本週成交量 < 均量 * paramVolRatio）
if volRatioNow < paramVolRatio then
    isVolShrink = true
else
    isVolShrink = false;

// ── 選股觸發 ─────────────────────────────────────────────
if isMaRising = true
    and hadHighDev = true
    and isPeakPast = true
    and isNearMa = true
    and isVolShrink = true
then begin
    ret = 1;

    // 九宮格輸出欄位
    OutputField1(devNow,                   "當前乖離率(%)");
    OutputField2(highestDev,               "期間最大正乖離(%)");
    OutputField3(pullbackPct,              "近高回檔幅度(%)");
    OutputField4(peakBar,                  "峰值距今(週)");
    OutputField5(volRatioNow,              "量/均量比值");
    OutputField6(GetField("Close", "D"),   "日收盤價");
end;
