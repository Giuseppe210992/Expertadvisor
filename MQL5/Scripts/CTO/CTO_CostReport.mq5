//+------------------------------------------------------------------+
//|                                               CTO_CostReport.mq5 |
//|  Misura sul PROPRIO broker i costi di ciascuno strumento         |
//|  candidato, prima di qualsiasi backtest:                         |
//|   - spread medio, mediano, 95° percentile e massimo (tick reali) |
//|   - spread medio per ora del giorno (rollover!)                  |
//|   - swap long/short (convertiti in % annua del nozionale)        |
//|   - giorno dello swap triplo, contratto, lotto min/step, leva    |
//|   - commissione per lotto osservata nello storico del conto      |
//|   - costo round-trip in % dell'ATR(20) D1                        |
//|  Output: Common\Files\CTO_cost_report.csv                        |
//+------------------------------------------------------------------+
#property copyright "CTO - progetto di ricerca"
#property version   "1.00"
#property script_show_inputs

input string InpSymbols   = "EURUSD,GBPUSD,AUDUSD,USDCAD,EURJPY,AUDJPY,XAUUSD,US500,USTEC,UK100,JP225,USOIL"; // Simboli (nomi del broker)
input int    InpDays      = 60;     // Giorni di tick da analizzare
input int    InpHistDays  = 365;    // Giorni di storico deal per stimare la commissione

//--- commissione per lotto per lato osservata nei deal del conto, per simbolo
double ObservedCommissionPerLot(const string sym)
  {
   if(!HistorySelect(TimeCurrent() - InpHistDays * 86400, TimeCurrent())) return -1.0;
   double c = 0.0, v = 0.0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != sym) continue;
      c += MathAbs(HistoryDealGetDouble(d, DEAL_COMMISSION));
      v += HistoryDealGetDouble(d, DEAL_VOLUME);
     }
   return (v > 0.0) ? c / v : -1.0;
  }

//--- swap in % annua del nozionale (convertendo le varie modalita' di swap MT5)
double SwapAnnualPct(const string sym, const bool isLong)
  {
   double sw = SymbolInfoDouble(sym, isLong ? SYMBOL_SWAP_LONG : SYMBOL_SWAP_SHORT);
   ENUM_SYMBOL_SWAP_MODE mode = (ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(sym, SYMBOL_SWAP_MODE);
   double px = SymbolInfoDouble(sym, SYMBOL_BID);
   double cs = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE), ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(px <= 0 || ts <= 0) return 0.0;
   double notional = px * tv / ts;                    // valore di 1 lotto in valuta conto
   double perDay = 0.0;                               // valuta conto per lotto per notte
   switch(mode)
     {
      case SYMBOL_SWAP_MODE_POINTS:            perDay = sw * pt * tv / ts; break;
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:
      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:   perDay = sw; break;   // approssimazione: valuta ~ valuta conto
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
      case SYMBOL_SWAP_MODE_INTEREST_OPEN:     return sw;            // gia' in % annua
      default:                                 return 0.0;
     }
   return (notional > 0) ? perDay * 360.0 / notional * 100.0 : 0.0;
  }

void OnStart(void)
  {
   string syms[];
   int n = StringSplit(InpSymbols, ',', syms);
   int h = FileOpen("CTO_cost_report.csv", FILE_WRITE | FILE_CSV | FILE_COMMON, ';');
   if(h == INVALID_HANDLE) { Print("impossibile creare il file"); return; }
   FileWrite(h, "symbol", "ticks", "spread_avg_pts", "spread_median_pts", "spread_p95_pts", "spread_max_pts",
             "worst_hour_server", "worst_hour_avg_pts", "swap_long_pct_yr", "swap_short_pct_yr", "hedge_swap_pct_yr",
             "triple_swap_day", "contract", "min_lot", "lot_step", "margin_initial_1lot", "leverage_eff",
             "comm_per_lot_side_obs", "atr20_d1", "roundtrip_pct_atr", "hedging_account");
   bool hedging = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   for(int k = 0; k < n; k++)
     {
      string s = syms[k];
      StringTrimLeft(s); StringTrimRight(s);
      if(!SymbolSelect(s, true)) { PrintFormat("%s: simbolo non trovato", s); continue; }
      double pt = SymbolInfoDouble(s, SYMBOL_POINT);
      //--- tick reali
      MqlTick ticks[];
      ulong to = (ulong)TimeCurrent() * 1000, from = to - (ulong)InpDays * 86400 * 1000;
      int nt = CopyTicksRange(s, ticks, COPY_TICKS_INFO, from, to);
      double sum = 0, mx = 0;
      double hourSum[24]; long hourN[24];
      ArrayInitialize(hourSum, 0); ArrayInitialize(hourN, 0);
      double sp[];
      ArrayResize(sp, MathMax(nt, 0));
      int m = 0;
      for(int i = 0; i < nt; i++)
        {
         if(ticks[i].ask <= 0 || ticks[i].bid <= 0) continue;
         double x = (ticks[i].ask - ticks[i].bid) / pt;
         sp[m++] = x; sum += x; mx = MathMax(mx, x);
         MqlDateTime t; TimeToStruct((datetime)(ticks[i].time_msc / 1000), t);
         hourSum[t.hour] += x; hourN[t.hour]++;
        }
      ArrayResize(sp, m);
      ArraySort(sp);
      double med = (m > 0) ? sp[m / 2] : 0, p95 = (m > 0) ? sp[(int)(m * 0.95)] : 0;
      int wh = 0; double wv = 0;
      for(int hh = 0; hh < 24; hh++)
         if(hourN[hh] > 0 && hourSum[hh] / hourN[hh] > wv) { wv = hourSum[hh] / hourN[hh]; wh = hh; }
      //--- ATR D1
      int ha = iATR(s, PERIOD_D1, 20);
      double a[1]; double atrv = 0;
      if(ha != INVALID_HANDLE)
        {
         for(int w = 0; w < 50 && BarsCalculated(ha) <= 0; w++) Sleep(100);
         if(CopyBuffer(ha, 0, 1, 1, a) == 1) atrv = a[0];
         IndicatorRelease(ha);
        }
      double comm = ObservedCommissionPerLot(s);
      double tv = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE), ts = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
      double vpu = (ts > 0) ? tv / ts : 0;
      double spreadAvgPrice = (m > 0 ? sum / m : 0) * pt;
      double rt = spreadAvgPrice + ((comm > 0 && vpu > 0) ? 2 * comm / vpu : 0);   // round trip in prezzo
      double marg = 0;
      double bid = SymbolInfoDouble(s, SYMBOL_BID);
      OrderCalcMargin(ORDER_TYPE_BUY, s, 1.0, SymbolInfoDouble(s, SYMBOL_ASK), marg);
      double notional = bid * vpu;
      double sl = SwapAnnualPct(s, true), ss = SwapAnnualPct(s, false);
      FileWrite(h, s, m, DoubleToString(m > 0 ? sum / m : 0, 1), DoubleToString(med, 1), DoubleToString(p95, 1),
                DoubleToString(mx, 1), wh, DoubleToString(wv, 1), DoubleToString(sl, 2), DoubleToString(ss, 2),
                DoubleToString(sl + ss, 2),
                EnumToString((ENUM_DAY_OF_WEEK)SymbolInfoInteger(s, SYMBOL_SWAP_ROLLOVER3DAYS)),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE), 2),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_VOLUME_MIN), 2), DoubleToString(SymbolInfoDouble(s, SYMBOL_VOLUME_STEP), 2),
                DoubleToString(marg, 2), DoubleToString(marg > 0 ? notional / marg : 0, 1),
                DoubleToString(comm, 2), DoubleToString(atrv, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)),
                DoubleToString(atrv > 0 ? rt / atrv * 100 : 0, 2), hedging ? "si" : "no");
      PrintFormat("%s: spread medio %.1f pt, max %.0f pt (ora peggiore %d: %.1f), swap L/S %.2f%%/%.2f%% annuo, hedge %.2f%%",
                  s, m > 0 ? sum / m : 0, mx, wh, wv, sl, ss, sl + ss);
     }
   FileClose(h);
   Print("Report scritto in Common\\Files\\CTO_cost_report.csv");
  }
//+------------------------------------------------------------------+
