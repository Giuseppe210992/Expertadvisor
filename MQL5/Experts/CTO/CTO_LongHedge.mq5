//+------------------------------------------------------------------+
//|                                                CTO_LongHedge.mq5 |
//|  Test dell'idea "long SEMPRE aperto + short di copertura".       |
//|  SOLO PER IL TESTER / CONTO DEMO: non e' la variante C.          |
//|                                                                  |
//|  Regole (identiche a research/exp15_hedge_con_leva.py):          |
//|   - all'avvio apre un long pari a InpLongLeverage x il capitale  |
//|     e non lo chiude mai (lo riapre solo se sparisce, es. stop-out)|
//|   - a ogni chiusura D1, se il prezzo e' sceso del InpTriggerPct% |
//|     dal massimo, apre uno short di InpHedgeMult x il volume long |
//|   - chiude lo short quando la chiusura D1 rimbalza del           |
//|     InpReboundPct% dal minimo toccato durante la copertura       |
//|   - InpEscalate=true: dopo ogni copertura chiusa in perdita il   |
//|     moltiplicatore raddoppia (martingala) fino a un nuovo massimo|
//|   - gli ordini partono alla prima ora fuori rollover del giorno  |
//|  Output: Diario + Common\Files\CTO_longhedge_<sym>_<tester|live>.csv
//+------------------------------------------------------------------+
#property copyright "CTO - progetto di ricerca"
#property version   "1.00"
#include <Trade/Trade.mqh>

input double InpLongLeverage = 1.0;   // Long: esposizione = leva x capitale iniziale (1 = senza leva)
input bool   InpHedge        = true;  // Attiva le coperture (false = solo long, per confronto)
input double InpHedgeMult    = 1.0;   // Short di copertura = moltiplicatore x volume long (1, 2, 3, 5...)
input double InpTriggerPct   = 5.0;   // Apre lo short se la chiusura D1 scende di X% dal massimo
input double InpReboundPct   = 3.0;   // Chiude lo short se la chiusura D1 risale di R% dal minimo
input bool   InpEscalate     = false; // Raddoppia il moltiplicatore dopo ogni copertura persa (martingala)
input int    InpExecHour     = 1;     // Ora server da cui eseguire gli ordini del giorno (fuori rollover)
input long   InpMagic        = 720200;

CTrade   g_trade;
double   g_longLots = 0.0;
double   g_peak = 0.0, g_ath = 0.0, g_min = 0.0, g_mult = 1.0;
bool     g_inHedge = false;
double   g_hedgeLots = 0.0, g_hedgeEntry = 0.0;
datetime g_hedgeTime = 0, g_lastDay = 0;
int      g_pendAction = 0;            // 0 niente, 1 apri short, -1 chiudi short
int      g_nHedges = 0, g_nWins = 0, g_nLongReopen = 0;
double   g_hedgeRealized = 0.0;
double   g_eqPeak = 0.0, g_maxDD = 0.0;
int      g_fh = INVALID_HANDLE;
bool     g_hedging = true;

double NormLots(double v)
  {
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   v = MathFloor(v / st) * st;
   if(v < mn) v = mn;
   if(v > mx) v = mx;
   return NormalizeDouble(v, 2);
  }

//--- volume per un nozionale pari a lev x capitale (in valuta del conto)
double LotsForLeverage(const double lev)
  {
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE), ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(tv <= 0.0 || ts <= 0.0 || px <= 0.0) return 0.0;
   double notionalPerLot = tv / ts * px;
   return NormLots(lev * AccountInfoDouble(ACCOUNT_BALANCE) / notionalPerLot);
  }

bool HasPosition(const ENUM_POSITION_TYPE type, ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type) { ticket = t; return true; }
     }
   return false;
  }

void LogRow(const string what, const double lots, const double price, const double pnl)
  {
   if(g_fh == INVALID_HANDLE) return;
   FileWrite(g_fh, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), _Symbol, what, DoubleToString(lots, 2),
             DoubleToString(price, _Digits), DoubleToString(pnl, 2), DoubleToString(g_mult, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
  }

int OnInit(void)
  {
   if(InpHedgeMult <= 0.0 || InpTriggerPct <= 0.0 || InpReboundPct <= 0.0) return INIT_PARAMETERS_INCORRECT;
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(20);
   g_hedging = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(!g_hedging) Print("[LH] conto NETTING: la copertura riduce/inverte la posizione netta (economicamente equivalente)");
   g_mult = InpHedgeMult;
   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   g_fh = FileOpen(StringFormat("CTO_longhedge_%s_%s.csv", _Symbol, tester ? "tester" : "live"),
                   FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');
   if(g_fh != INVALID_HANDLE) FileWrite(g_fh, "time", "symbol", "event", "lots", "price", "pnl", "mult", "equity");
   g_eqPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   PrintFormat("[LH] avvio su %s: long %.1fx, copertura %s (%.1fx, calo %.1f%%, rimbalzo %.1f%%%s)", _Symbol,
               InpLongLeverage, InpHedge ? "attiva" : "spenta", InpHedgeMult, InpTriggerPct, InpReboundPct,
               InpEscalate ? ", RADDOPPIO dopo perdita" : "");
   return INIT_SUCCEEDED;
  }

void EnsureLong(void)
  {
   ulong t;
   if(HasPosition(POSITION_TYPE_BUY, t)) return;
   if(!g_hedging && g_inHedge) return;            // in netting durante la copertura il long e' "dentro" la netta
   double lots = LotsForLeverage(InpLongLeverage);
   if(lots <= 0.0) return;
   if(g_trade.Buy(lots, _Symbol, 0.0, 0.0, 0.0, "LH long"))
     {
      if(g_longLots > 0.0) g_nLongReopen++;
      g_longLots = lots;
      double px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_peak == 0.0) { g_peak = px; g_ath = px; }
      LogRow(g_nLongReopen > 0 ? "LONG_REOPEN" : "LONG_OPEN", lots, px, 0.0);
     }
  }

void OpenHedge(void)
  {
   double lots = NormLots(g_longLots * g_mult);
   if(!g_trade.Sell(lots, _Symbol, 0.0, 0.0, 0.0, "LH hedge")) { PrintFormat("[LH] short rifiutato: %d", g_trade.ResultRetcode()); return; }
   g_inHedge = true; g_hedgeLots = lots; g_hedgeEntry = g_trade.ResultPrice(); g_hedgeTime = TimeCurrent();
   g_nHedges++;
   LogRow("HEDGE_OPEN", lots, g_hedgeEntry, 0.0);
  }

void CloseHedge(void)
  {
   double before = AccountInfoDouble(ACCOUNT_BALANCE);
   bool ok = false;
   if(g_hedging)
     {
      ulong t;
      if(HasPosition(POSITION_TYPE_SELL, t)) ok = g_trade.PositionClose(t);
      else ok = true;                              // chiuso altrove (stop-out)
     }
   else ok = g_trade.Buy(g_hedgeLots, _Symbol, 0.0, 0.0, 0.0, "LH hedge close");
   if(!ok) { PrintFormat("[LH] chiusura short rifiutata: %d", g_trade.ResultRetcode()); return; }
   double px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double pnl = g_hedging ? AccountInfoDouble(ACCOUNT_BALANCE) - before
                          : (g_hedgeEntry - px) * g_hedgeLots * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_hedgeRealized += pnl;
   if(pnl > 0.0) g_nWins++;
   LogRow("HEDGE_CLOSE", g_hedgeLots, px, pnl);
   g_inHedge = false; g_hedgeLots = 0.0;
   if(InpEscalate && pnl < 0.0) g_mult *= 2.0;
  }

void OnTick(void)
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_eqPeak) g_eqPeak = eq;
   if(g_eqPeak > 0.0) g_maxDD = MathMax(g_maxDD, 1.0 - eq / g_eqPeak);

   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   bool canTrade = (now.hour >= InpExecHour && now.hour < 23);

   if(canTrade) EnsureLong();

   //--- decisione a ogni nuova barra D1, sulla chiusura della barra precedente
   datetime d = iTime(_Symbol, PERIOD_D1, 0);
   if(d != g_lastDay && g_longLots > 0.0)
     {
      g_lastDay = d;
      double c = iClose(_Symbol, PERIOD_D1, 1);
      if(c > 0.0 && InpHedge)
        {
         if(!g_inHedge)
           {
            if(c > g_peak) g_peak = c;
            if(c >= g_ath) { g_ath = c; g_mult = InpHedgeMult; }
            if(c <= g_peak * (1.0 - InpTriggerPct / 100.0)) { g_pendAction = 1; g_min = c; }
           }
         else
           {
            if(c < g_min) g_min = c;
            if(c >= g_min * (1.0 + InpReboundPct / 100.0)) g_pendAction = -1;
           }
        }
     }
   if(g_pendAction != 0 && canTrade)
     {
      if(g_pendAction == 1 && !g_inHedge) OpenHedge();
      else if(g_pendAction == -1 && g_inHedge) { CloseHedge(); g_peak = iClose(_Symbol, PERIOD_D1, 1); }
      g_pendAction = 0;
     }
  }

double OnTester(void)
  {
   double longPnl = 0.0;
   ulong t;
   if(HasPosition(POSITION_TYPE_BUY, t)) longPnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dep = TesterStatistics(STAT_INITIAL_DEPOSIT);
   PrintFormat("[LH] RIEPILOGO %s: equity finale %.2f (%+.1f%% sul deposito), long aperto P&L+swap %.2f, "
               "coperture %d (in utile %d), P&L coperture chiuse %.2f, long riaperti %d, drawdown max %.1f%%",
               _Symbol, eq, (eq / dep - 1.0) * 100.0, longPnl, g_nHedges, g_nWins, g_hedgeRealized, g_nLongReopen, g_maxDD * 100.0);
   LogRow("SUMMARY", g_longLots, SymbolInfoDouble(_Symbol, SYMBOL_BID), eq - dep);
   return (eq / dep - 1.0) * 100.0;
  }

void OnDeinit(const int reason)
  {
   if(g_fh != INVALID_HANDLE) { FileClose(g_fh); g_fh = INVALID_HANDLE; }
  }
//+------------------------------------------------------------------+
