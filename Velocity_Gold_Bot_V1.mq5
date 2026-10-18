//+------------------------------------------------------------------+
//|                                      Velocity_Gold_Bot_V1.mq5    |
//| Demo-first XAUUSD Expert Advisor for MetaTrader 5                |
//| Strategy: EMA crossover + RSI confirmation; ATR-based exits      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Demo-first gold EA with fixed-fraction risk controls."

#include <Trade/Trade.mqh>
CTrade trade;

// ---- User-adjustable inputs ----
input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_M15;
input int FastEMAPeriod = 20;
input int SlowEMAPeriod = 50;
input int RSIPeriod = 14;
input int ATRPeriod = 14;
input double RiskPercent = 0.50;          // Risk per trade as % of equity
input double RewardRiskRatio = 2.0;       // Take-profit distance / stop distance
input double ATRStopMultiplier = 1.5;
input double DailyLossLimitPercent = 2.0; // Locks new entries after this drawdown
input int MaxSpreadPoints = 80;           // Broker points; adjust for your broker
input int SlippagePoints = 20;
input ulong MagicNumber = 18102026;
input bool CloseOnOppositeSignal = true;
input bool RequireXAUUSDName = true;      // Allows names such as XAUUSD.a / XAUUSDm
input bool DemoOnly = true;               // EA refuses to trade on a real account

int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
int rsiHandle  = INVALID_HANDLE;
int atrHandle  = INVALID_HANDLE;

datetime lastBarTime = 0;
string dayStartKey = "";
string dayLockKey  = "";

//+------------------------------------------------------------------+
int OnInit()
{
   if(FastEMAPeriod <= 0 || SlowEMAPeriod <= FastEMAPeriod ||
      RSIPeriod <= 0 || ATRPeriod <= 0 || RiskPercent <= 0 ||
      RewardRiskRatio <= 0 || ATRStopMultiplier <= 0 ||
      DailyLossLimitPercent <= 0 || MaxSpreadPoints < 0)
   {
      Print("Invalid input settings. Check EMA periods and risk inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(RequireXAUUSDName && StringFind(_Symbol, "XAUUSD") < 0)
   {
      Print("This EA is configured for XAUUSD. Current symbol: ", _Symbol);
      return INIT_FAILED;
   }

   if(DemoOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL)
   {
      Print("DemoOnly is enabled. EA will not trade on a REAL account.");
      return INIT_FAILED;
   }

   fastHandle = iMA(_Symbol, SignalTimeframe, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, SignalTimeframe, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle  = iRSI(_Symbol, SignalTimeframe, RSIPeriod, PRICE_CLOSE);
   atrHandle  = iATR(_Symbol, SignalTimeframe, ATRPeriod);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles. Error: ", GetLastError());
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   UpdateDailyKeys();
   EnsureDailyBaseline();
   lastBarTime = iTime(_Symbol, SignalTimeframe, 0);

   Print("Velocity Gold Bot V1 initialized on ", _Symbol,
         ". Start on a DEMO account and test before considering live trading.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
   if(rsiHandle  != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(atrHandle  != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   UpdateDailyKeys();
   EnsureDailyBaseline();

   if(DailyLossLimitReached())
   {
      CloseOurPositions();
      if(!GlobalVariableCheck(dayLockKey))
         GlobalVariableSet(dayLockKey, 1.0);
      Comment("Velocity Gold Bot V1\nDAILY LOSS LIMIT REACHED - trading locked for today.");
      return;
   }

   if(GlobalVariableCheck(dayLockKey))
   {
      Comment("Velocity Gold Bot V1\nDaily loss lock is active. No new trades today.");
      return;
   }

   if(!IsNewBar())
      return;

   double fast1, fast2, slow1, slow2, rsi1, atr1;
   if(!ReadIndicators(fast1, fast2, slow1, slow2, rsi1, atr1))
      return;

   bool buySignal  = (fast2 <= slow2 && fast1 > slow1 && rsi1 >= 52.0 && rsi1 <= 70.0);
   bool sellSignal = (fast2 >= slow2 && fast1 < slow1 && rsi1 <= 48.0 && rsi1 >= 30.0);

   if(CloseOnOppositeSignal)
   {
      if(buySignal) CloseOurPositionsByType(POSITION_TYPE_SELL);
      if(sellSignal) CloseOurPositionsByType(POSITION_TYPE_BUY);
   }

   if(HasOurPosition())
      return;

   if(!TradingEnvironmentOK())
      return;

   if(buySignal)
      OpenTrade(ORDER_TYPE_BUY, atr1);
   else if(sellSignal)
      OpenTrade(ORDER_TYPE_SELL, atr1);
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime barTime = iTime(_Symbol, SignalTimeframe, 0);
   if(barTime <= 0 || barTime == lastBarTime)
      return false;
   lastBarTime = barTime;
   return true;
}

//+------------------------------------------------------------------+
bool ReadIndicators(double &fast1, double &fast2,
                    double &slow1, double &slow2,
                    double &rsi1, double &atr1)
{
   if(BarsCalculated(fastHandle) < SlowEMAPeriod + 3 ||
      BarsCalculated(slowHandle) < SlowEMAPeriod + 3 ||
      BarsCalculated(rsiHandle) < RSIPeriod + 3 ||
      BarsCalculated(atrHandle) < ATRPeriod + 3)
      return false;

   double tmp[1];
   if(CopyBuffer(fastHandle, 0, 1, 1, tmp) != 1) return false;
   fast1 = tmp[0];
   if(CopyBuffer(fastHandle, 0, 2, 1, tmp) != 1) return false;
   fast2 = tmp[0];
   if(CopyBuffer(slowHandle, 0, 1, 1, tmp) != 1) return false;
   slow1 = tmp[0];
   if(CopyBuffer(slowHandle, 0, 2, 1, tmp) != 1) return false;
   slow2 = tmp[0];
   if(CopyBuffer(rsiHandle, 0, 1, 1, tmp) != 1) return false;
   rsi1 = tmp[0];
   if(CopyBuffer(atrHandle, 0, 1, 1, tmp) != 1) return false;
   atr1 = tmp[0];

   return (atr1 > 0);
}

//+------------------------------------------------------------------+
bool TradingEnvironmentOK()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread < 0 || spread > MaxSpreadPoints)
   {
      Print("Entry skipped: spread ", spread, " points exceeds limit ", MaxSpreadPoints);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void OpenTrade(const ENUM_ORDER_TYPE orderType, const double atr)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0 || atr <= 0)
      return;

   double entry = (orderType == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double stopDistance = MathMax(atr * ATRStopMultiplier,
                                 (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
   // Add a small buffer beyond broker's minimum stop distance.
   stopDistance = MathMax(stopDistance, 2.0 * point);

   double sl = (orderType == ORDER_TYPE_BUY) ? entry - stopDistance : entry + stopDistance;
   double tpDistance = stopDistance * RewardRiskRatio;
   double tp = (orderType == ORDER_TYPE_BUY) ? entry + tpDistance : entry - tpDistance;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   double volume = CalculateRiskVolume(orderType, entry, sl);
   if(volume <= 0)
   {
      Print("Entry skipped: calculated volume is below broker minimum or invalid.");
      return;
   }

   bool sent = false;
   if(orderType == ORDER_TYPE_BUY)
      sent = trade.Buy(volume, _Symbol, 0.0, sl, tp, "Velocity Gold Bot V1 BUY");
   else
      sent = trade.Sell(volume, _Symbol, 0.0, sl, tp, "Velocity Gold Bot V1 SELL");

   if(!sent || (trade.ResultRetcode() != TRADE_RETCODE_DONE &&
                trade.ResultRetcode() != TRADE_RETCODE_PLACED &&
                trade.ResultRetcode() != TRADE_RETCODE_DONE_PARTIAL))
   {
      Print("Order failed. Retcode: ", trade.ResultRetcode(),
            " - ", trade.ResultRetcodeDescription());
   }
   else
   {
      Print("Order accepted: ", EnumToString(orderType),
            " volume=", DoubleToString(volume, 2),
            " SL=", DoubleToString(sl, digits),
            " TP=", DoubleToString(tp, digits));
   }
}

//+------------------------------------------------------------------+
double CalculateRiskVolume(const ENUM_ORDER_TYPE orderType,
                           const double entry, const double sl)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * RiskPercent / 100.0;
   if(equity <= 0 || riskMoney <= 0)
      return 0;

   double oneLotProfit = 0;
   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entry, sl, oneLotProfit))
   {
      Print("OrderCalcProfit failed: ", GetLastError());
      return 0;
   }

   double oneLotLoss = MathAbs(oneLotProfit);
   if(oneLotLoss <= 0)
      return 0;

   double rawVolume = riskMoney / oneLotLoss;
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0 || minVolume <= 0 || maxVolume <= 0)
      return 0;

   // Round DOWN only. Never round up to the broker minimum if that exceeds risk.
   double volume = MathFloor(rawVolume / step) * step;
   volume = NormalizeDouble(volume, 8);

   if(volume < minVolume)
      return 0;
   volume = MathMin(volume, maxVolume);

   // Verify estimated loss at chosen size is within risk budget.
   double estimatedProfit = 0;
   if(!OrderCalcProfit(orderType, _Symbol, volume, entry, sl, estimatedProfit))
      return 0;
   if(MathAbs(estimatedProfit) > riskMoney * 1.02)
      return 0;

   return volume;
}

//+------------------------------------------------------------------+
bool HasOurPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CloseOurPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(!trade.PositionClose(ticket))
            Print("Could not close position ", ticket, ": ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
void CloseOurPositionsByType(const ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != positionType)
         continue;

      if(!trade.PositionClose(ticket))
         Print("Could not close opposite position ", ticket, ": ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void UpdateDailyKeys()
{
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(), now);
   string datePart = StringFormat("%04d%02d%02d", now.year, now.mon, now.day);
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   dayStartKey = StringFormat("VGB1_%I64d_%I64u_%s_START", login, MagicNumber, datePart);
   dayLockKey  = StringFormat("VGB1_%I64d_%I64u_%s_LOCK", login, MagicNumber, datePart);
}

//+------------------------------------------------------------------+
void EnsureDailyBaseline()
{
   if(dayStartKey == "")
      UpdateDailyKeys();
   if(!GlobalVariableCheck(dayStartKey))
      GlobalVariableSet(dayStartKey, AccountInfoDouble(ACCOUNT_EQUITY));
}

//+------------------------------------------------------------------+
bool DailyLossLimitReached()
{
   if(dayStartKey == "")
      UpdateDailyKeys();
   EnsureDailyBaseline();

   double baseline = GlobalVariableGet(dayStartKey);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(baseline <= 0)
      return false;

   return (equity <= baseline * (1.0 - DailyLossLimitPercent / 100.0));
}
//+------------------------------------------------------------------+
