// ============================================================
// 策略名稱：週MA20量縮回測選股
// 執行環境：選股腳本（Screener）/ 週K線圖
// 策略邏輯：
//   1. 週MA20 斜率向上（多頭趨勢確認）
//   2. 近期曾有顯著正乖離（股價一度強勢衝高）
//   3. 目前以量縮方式回測（修正非恐慌賣壓）
//   4. 當前乖離率已收斂至週MA20附近
// 版本日期：2026-05-08
// 修正紀錄：使用 GetField("Close","W") 明確取週資料
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

// ── 取週資料（明確指定 "W" 頻率）────────────────────────
var: wClose(0), wVol(0);

wClose = GetField("Close", "W");      // 週收盤價
wVol   = GetField("Volume", "W");     // 週成交量

// ── 計算核心變數 ─────────────────────────────────────────
// 注意：ma20Now 為 var: 變數，ma20Now[1] 取前一期快取值是安全的。
// 避免使用 Average(wClose,20)[1]（wClose 為變數時系統會警告）
var: ma20Now(0);
var: devNow(0);
var: highestClose(0), highestDev(0);
var: volMaVal(0), volRatioNow(0);

// 週MA20（直接以 GetField 序列傳入，避免透過中間變數取 [1]）
ma20Now = Average(GetField("Close", "W"), 20);

// 當前收盤對週MA20 的乖離率（%）
if ma20Now <> 0 then
    devNow = (wClose - ma20Now) / ma20Now * 100
else
    devNow = 0;

// 回看期間內的最高週收盤（用來計算歷史最大正乖離）
highestClose = Highest(wClose, paramLookback);

// 歷史最大正乖離率（%）
if ma20Now <> 0 then
    highestDev = (highestClose - ma20Now) / ma20Now * 100
else
    highestDev = 0;

// 週均量
volMaVal = Average(wVol, paramVolMa);

// 當前量與均量的比值
if volMaVal <> 0 then
    volRatioNow = wVol / volMaVal
else
    volRatioNow = 1;

// ── 布林輔助旗標 ─────────────────────────────────────────
var: isMaRising(false);     // 週MA20 斜率向上
var: hadHighDev(false);     // 曾有顯著正乖離
var: isNearMa(false);       // 當前已回到均線附近（乖離收斂）
var: isVolShrink(false);    // 量縮確認

// 條件一：週MA20 上揚
// ma20Now[1] = 上一根週K棒的 MA20 快取值，var: 變數的歷史取值安全無警告
if ma20Now > ma20Now[1] then
    isMaRising = true
else
    isMaRising = false;

// 條件二：回看期間內曾有正乖離 >= paramDevHigh
if highestDev >= paramDevHigh then
    hadHighDev = true
else
    hadHighDev = false;

// 條件三：當前乖離率絕對值 <= paramDevNear（回到均線附近）
// 允許略低於MA20（-paramDevNear ~ +paramDevNear）
if devNow <= paramDevNear and devNow >= (-1 * paramDevNear) then
    isNearMa = true
else
    isNearMa = false;

// 條件四：量縮（本週成交量 < 均量 * paramVolRatio）
if volRatioNow < paramVolRatio then
    isVolShrink = true
else
    isVolShrink = false;

// ── 選股觸發 ─────────────────────────────────────────────
if isMaRising = true
    and hadHighDev = true
    and isNearMa = true
    and isVolShrink = true
then begin
    ret = 1;

    // 九宮格輸出欄位
    OutputField1(devNow,        "當前乖離率(%)");
    OutputField2(highestDev,    "期間最大正乖離(%)");
    OutputField3(volRatioNow,   "量/均量比值");
    OutputField4(ma20Now,       "週MA20");
    OutputField5(wClose,        "週收盤價");
end;
