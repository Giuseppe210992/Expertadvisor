//+------------------------------------------------------------------+
//|                                               CTO_CostReport.mq5 |
//|  Misura sul conto (demo o reale) del broker i costi di ciascuno  |
//|  strumento candidato, per confrontare i broker PRIMA di scegliere|
//|  e per stimare quanto capitale consumano i costi della variante C.|
//|                                                                  |
//|  Per ogni simbolo:                                               |
//|   - spread medio, mediano, 95° percentile, massimo (tick reali)  |
//|     e ora del giorno con lo spread peggiore                      |
//|   - commissione per lato per 0,01 lotti (osservata nei deal del  |
//|     conto, altrimenti valore inserito a mano)                    |
//|   - costo di apertura, chiusura e round-trip di 0,01 lotti       |
//|   - swap LONG/SHORT per notte per 0,01 lotti e in % annua,       |
//|     costo per notte di un hedge, giorno dello swap triplo        |
//|   - lotto minimo, step, margine per 0,01 lotti, stop-out         |
//|   - rischio del lotto minimo con lo stop della variante C        |
//|     (4 x ATR20 D1) in valuta e in % del capitale                 |
//|   - costi attesi a 30/60/90 giorni con la frequenza della        |
//|     variante C, in valuta e in % del capitale                    |
//|   - capitale minimo perche' il lotto minimo rispetti un rischio  |
//|     per trade dello 0,25% (variante C), 1% o 2%                  |
//|  Output: Common\Files\CTO_cost_report_<server>.csv               |
//|  Unire i file di piu' broker con validation/merge_cost_reports.py|
//+------------------------------------------------------------------+
#property copyright "CTO - progetto di ricerca"
#property version   "2.00"
#property script_show_inputs

input string InpSymbols        = "EURUSD,GBPUSD,USDJPY,XAUUSD,NAS100,US500,USOIL"; // Simboli (nomi ESATTI del broker)
input double InpCapital        = 50.0;  // Capitale di riferimento (valuta del conto)
input int    InpDays           = 60;    // Giorni di tick da analizzare
input int    InpHistDays       = 365;   // Giorni di storico deal per la commissione osservata
input double InpCommPerLotSide = -1.0;  // Commissione per lotto per lato se non osservabile (-1 = sconosciuta)
input double InpStopAtr        = 4.0;   // Stop della variante C (x ATR20 D1)
input double InpTradesPerMonth = 0.8;   // Round-trip al mese per strumento (variante C nei test: ~9,5/anno)
input double InpNightsPerMonth = 2.3;   // Notti in posizione al mese (variante C: in mercato ~7,7% del tempo)

//--- commissione per lotto per lato osservata nei deal del conto
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

//--- valore in valuta conto di 1.0 di prezzo per 1 lotto
double ValuePerPriceUnit(const string sym)
  {
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE), ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   return (ts > 0.0) ? tv / ts : 0.0;
  }

//--- swap per notte per 1 lotto in valuta conto (approssimato per le modalita' in valuta diversa dal conto)
double SwapPerNightPerLot(const string sym, const bool isLong)
  {
   double sw = SymbolInfoDouble(sym, isLong ? SYMBOL_SWAP_LONG : SYMBOL_SWAP_SHORT);
   ENUM_SYMBOL_SWAP_MODE mode = (ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(sym, SYMBOL_SWAP_MODE);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double notional = SymbolInfoDouble(sym, SYMBOL_BID) * ValuePerPriceUnit(sym);
   switch(mode)
     {
      case SYMBOL_SWAP_MODE_POINTS:            return sw * pt * ValuePerPriceUnit(sym);
      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:
      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:   return sw;
      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
      case SYMBOL_SWAP_MODE_INTEREST_OPEN:     return notional * sw / 100.0 / 360.0;
      default:                                 return 0.0;
     }
  }

string Sanitize(string s)
  {
   string bad[] = {" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"};
   for(int i = 0; i < ArraySize(bad); i++) StringReplace(s, bad[i], "_");
   return s;
  }

void OnStart(void)
  {
   string syms[];
   int n = StringSplit(InpSymbols, ',', syms);
   string server = AccountInfoString(ACCOUNT_SERVER);
   string fname = "CTO_cost_report_" + Sanitize(server) + ".csv";
   int h = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_COMMON, ';');
   if(h == INVALID_HANDLE) { Print("impossibile creare il file"); return; }
   string ccy = AccountInfoString(ACCOUNT_CURRENCY);
   bool hedging = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   bool soPct = (AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE) == ACCOUNT_STOPOUT_MODE_PERCENT);
   FileWrite(h, "broker", "server", "account_currency", "hedging_account", "margin_call", "stop_out", "stop_out_mode",
             "symbol", "ticks", "spread_avg_pts", "spread_median_pts", "spread_p95_pts", "spread_max_pts",
             "worst_hour_server", "worst_hour_avg_pts",
             "min_lot", "lot_step", "contract_size", "margin_min_lot", "margin_min_lot_pct_capital",
             "comm_per_lot_side", "comm_source",
             "cost_open_min_lot", "cost_close_min_lot", "cost_roundtrip_min_lot",
             "swap_long_night_min_lot", "swap_short_night_min_lot", "swap_long_pct_yr", "swap_short_pct_yr",
             "hedge_cost_night_min_lot", "triple_swap_day",
             "atr20_d1", "roundtrip_pct_atr", "risk_min_lot_at_stop", "risk_min_lot_pct_capital",
             "cost_30d", "cost_60d", "cost_90d", "cost_90d_pct_capital",
             "capital_needed_risk_0_25pct", "capital_needed_risk_1pct", "capital_needed_risk_2pct");
   for(int k = 0; k < n; k++)
     {
      string s = syms[k];
      StringTrimLeft(s); StringTrimRight(s);
      if(!SymbolSelect(s, true)) { PrintFormat("%s: simbolo non trovato su %s", s, server); continue; }
      double pt = SymbolInfoDouble(s, SYMBOL_POINT);
      double vpu = ValuePerPriceUnit(s);
      double minLot = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
      //--- tick reali
      MqlTick ticks[];
      ulong to = (ulong)TimeCurrent() * 1000, from = to - (ulong)InpDays * 86400 * 1000;
      int nt = CopyTicksRange(s, ticks, COPY_TICKS_INFO, from, to);
      double sum = 0, mx = 0;
      double hourSum[24];
      long   hourN[24];
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
      double avg = (m > 0) ? sum / m : 0, med = (m > 0) ? sp[m / 2] : 0, p95 = (m > 0) ? sp[(int)(m * 0.95)] : 0;
      int wh = 0; double wv = 0;
      for(int hh = 0; hh < 24; hh++)
         if(hourN[hh] > 0 && hourSum[hh] / hourN[hh] > wv) { wv = hourSum[hh] / hourN[hh]; wh = hh; }
      //--- ATR D1
      double atrv = 0, a[1];
      int ha = iATR(s, PERIOD_D1, 20);
      if(ha != INVALID_HANDLE)
        {
         for(int w = 0; w < 50 && BarsCalculated(ha) <= 0; w++) Sleep(100);
         if(CopyBuffer(ha, 0, 1, 1, a) == 1) atrv = a[0];
         IndicatorRelease(ha);
        }
      //--- commissione
      double comm = ObservedCommissionPerLot(s);
      string commSrc = "osservata";
      if(comm < 0.0) { comm = InpCommPerLotSide; commSrc = (comm < 0.0) ? "sconosciuta" : "inserita"; }
      double commMin = MathMax(comm, 0.0) * minLot;
      //--- costi per il lotto minimo (valuta conto)
      double halfSpread = 0.5 * avg * pt * minLot * vpu;
      double costOpen = halfSpread + commMin, costClose = halfSpread + commMin, rt = costOpen + costClose;
      double swL = SwapPerNightPerLot(s, true) * minLot, swS = SwapPerNightPerLot(s, false) * minLot;
      double notionalMin = SymbolInfoDouble(s, SYMBOL_BID) * vpu * minLot;
      double swLpct = (notionalMin > 0) ? swL * 360.0 / notionalMin * 100.0 : 0.0;
      double swSpct = (notionalMin > 0) ? swS * 360.0 / notionalMin * 100.0 : 0.0;
      double margin = 0.0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, s, minLot, SymbolInfoDouble(s, SYMBOL_ASK), margin))
        {
         margin = -1.0;   // calcolo non riuscito: segnalato nel file con -1
         PrintFormat("%s: OrderCalcMargin non riuscito (errore %d): margine non disponibile", s, GetLastError());
        }
      double riskMin = InpStopAtr * atrv * minLot * vpu;
      //--- costi attesi della variante C con il lotto minimo: round-trip + swap (caso peggiore tra long e short)
      double swapWorst = MathMin(swL, swS);                       // negativo = costo
      double monthly = InpTradesPerMonth * rt - InpNightsPerMonth * MathMin(swapWorst, 0.0);
      double rtPriceUnits = (minLot * vpu > 0) ? rt / (minLot * vpu) : 0.0;
      FileWrite(h, AccountInfoString(ACCOUNT_COMPANY), server, ccy, hedging ? "si" : "no",
                DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL), 1), DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO), 1),
                soPct ? "percentuale" : "denaro",
                s, m, DoubleToString(avg, 1), DoubleToString(med, 1), DoubleToString(p95, 1), DoubleToString(mx, 1),
                wh, DoubleToString(wv, 1),
                DoubleToString(minLot, 2), DoubleToString(SymbolInfoDouble(s, SYMBOL_VOLUME_STEP), 2),
                DoubleToString(SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE), 2),
                DoubleToString(margin, 2), DoubleToString(InpCapital > 0 ? margin / InpCapital * 100 : 0, 1),
                DoubleToString(comm, 2), commSrc,
                DoubleToString(costOpen, 3), DoubleToString(costClose, 3), DoubleToString(rt, 3),
                DoubleToString(swL, 3), DoubleToString(swS, 3), DoubleToString(swLpct, 2), DoubleToString(swSpct, 2),
                DoubleToString(-(swL + swS), 3),
                EnumToString((ENUM_DAY_OF_WEEK)SymbolInfoInteger(s, SYMBOL_SWAP_ROLLOVER3DAYS)),
                DoubleToString(atrv, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)),
                DoubleToString(atrv > 0 ? rtPriceUnits / atrv * 100 : 0, 2),
                DoubleToString(riskMin, 2), DoubleToString(InpCapital > 0 ? riskMin / InpCapital * 100 : 0, 1),
                DoubleToString(monthly, 2), DoubleToString(2 * monthly, 2), DoubleToString(3 * monthly, 2),
                DoubleToString(InpCapital > 0 ? 3 * monthly / InpCapital * 100 : 0, 1),
                // capitale minimo perche' il lotto minimo rispetti il rischio per trade indicato
                DoubleToString(riskMin / 0.0025, 0), DoubleToString(riskMin / 0.01, 0), DoubleToString(riskMin / 0.02, 0));
      PrintFormat("%s: spread medio %.1f pt (max %.0f), A+C 0,01 lotti %.2f %s, swap L/S %.3f/%.3f per notte, "
                  "rischio lotto minimo allo stop %.2f %s (%.0f%% di %.0f), costi 90g %.2f %s",
                  s, avg, mx, rt, ccy, swL, swS, riskMin, ccy, InpCapital > 0 ? riskMin / InpCapital * 100 : 0, InpCapital, 3 * monthly, ccy);
      if(commSrc == "sconosciuta")
         PrintFormat("%s: commissione non osservabile (nessun deal): inserirla in InpCommPerLotSide", s);
     }
   FileClose(h);
   PrintFormat("Report scritto in Common\\Files\\%s", fname);
  }
//+------------------------------------------------------------------+
