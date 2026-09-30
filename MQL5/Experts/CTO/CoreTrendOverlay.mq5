//+------------------------------------------------------------------+
//|                                             CoreTrendOverlay.mq5 |
//|  Core Trend + Counter-Trend Overlay (CTO)                         |
//|                                                                   |
//|  Posizione PRINCIPALE di lungo periodo (trend-following D1) +     |
//|  operazioni OPPOSTE con logica di trade propria (overlay), con:   |
//|   - dimensionamento a rischio fisso (mai martingala);            |
//|   - incrementi SOLO su overlay in profitto (anti-martingala),     |
//|     esposizione overlay <= InpMaxRatio x principale;             |
//|   - esecuzione in hedge (ticket opposti) o netting (riduzione);   |
//|   - edge monitor: overlay disattivati (ombra) se la loro          |
//|     aspettativa netta recente in R non e' positiva;               |
//|   - contabilita' separata principale / overlay / costi;           |
//|   - limiti: heat di portafoglio, leva lorda, margine, perdita     |
//|     giornaliera, stop operativo su drawdown.                      |
//|                                                                   |
//|  Vedi docs/ per l'analisi quantitativa che motiva ogni default.   |
//+------------------------------------------------------------------+
#property copyright "CTO - progetto di ricerca"
#property version   "1.00"
#property description "Core Trend + Counter-Trend Overlay. Default = variante PROPOSTA della ricerca (docs/)."

#include <CTO/Defines.mqh>
#include <CTO/SymbolMath.mqh>
#include <CTO/Indicators.mqh>
#include <CTO/Signals.mqh>
#include <CTO/Execution.mqh>
#include <CTO/RiskManager.mqh>
#include <CTO/CostTracker.mqh>
#include <CTO/EdgeMonitor.mqh>
#include <CTO/OverlayBook.mqh>
#include <CTO/TradeLog.mqh>

//=== input ===========================================================
input group "=== Posizione principale (trend di lungo periodo) ==="
input ENUM_TIMEFRAMES InpTfCore        = PERIOD_D1; // Timeframe principale
input int             InpEmaFast       = 50;        // EMA veloce (regime)
input int             InpEmaSlow       = 200;       // EMA lenta (regime)
input int             InpDonchEntry    = 55;        // Breakout Donchian di ingresso (barre)
input int             InpAtrCore       = 20;        // ATR principale
input double          InpKStop         = 4.0;       // Stop iniziale = k x ATR
input double          InpKTrail        = 4.0;       // Chandelier = estremo chiusure - k x ATR
input double          InpCoreRiskPct   = 0.25;      // Rischio per principale (% equity allo stop)
input double          InpMinLotMaxRiskPct = 0.0;    // Conti piccoli: consenti il lotto minimo se il suo rischio <= % (0 = mai)
input bool            InpAllowLong     = true;      // Principale LONG ammessa
input bool            InpAllowShort    = true;      // Principale SHORT ammessa
input double          InpCoreDayTpAtr  = 0.5;       // Presa di profitto giornaliera (x ATR D1; 0 = tenuta lunga)

input group "=== Overlay (operazioni opposte) ==="
input ENUM_OV_AGAINST InpOvAgainst     = OV_AGAINST_SHORT_CORE; // Contro quale principale
input ENUM_TIMEFRAMES InpTfOv          = PERIOD_H4; // Timeframe overlay
input int             InpDonchOv       = 120;       // Breakout contro-trend (barre TF overlay; 120 H4 ~ 20 giorni)
input int             InpDonchOvExit   = 60;        // Trailing Donchian overlay (barre)
input int             InpAtrOv         = 14;        // ATR overlay
input double          InpKOvStop       = 4.0;       // Stop overlay = k x ATR(TF overlay)
input double          InpHStep         = 0.5;       // Dimensione di ogni ingresso (frazione della principale)
input double          InpMaxRatio      = 1.0;       // Overlay massimo (frazione della principale, <=1 = mai net short)
input double          InpAddR          = 1.0;       // Incremento solo se ultimo ingresso in profitto >= R x
input double          InpTpR           = 2.0;       // Take profit parziale a R x
input double          InpTpFrac        = 0.5;       // Frazione chiusa al TP
input bool            InpOvAfterCoreExit = true;    // Overlay sopravvive all'uscita della principale (solo hedge)
input int             InpEdgeN         = 20;        // Edge monitor: finestra ingressi (0 = off)
input double          InpEdgeMin       = 0.0;       // Edge monitor: R medio minimo

input group "=== Esecuzione e costi ==="
input ENUM_EXEC_MODE  InpExecMode      = EXEC_NET;  // Modalita' overlay (NET evita il doppio swap)
input int             InpRolloverStart = 23;        // Inizio finestra rollover (ora server)
input int             InpRolloverEnd   = 1;         // Fine finestra rollover (ora server)
input int             InpMaxSpreadPts  = 0;         // Spread massimo assoluto (punti, 0 = off)
input double          InpMaxSpreadAtr  = 0.05;      // Spread massimo come frazione dell'ATR del ruolo
input int             InpDeviation     = 20;        // Deviazione massima (punti)
input int             InpMaxRetries    = 3;         // Tentativi su requote
input int             InpSignalExpiryH = 24;        // Validita' di un segnale non eseguito (ore)

input group "=== Rischio e capitale ==="
input double          InpMaxHeatPct    = 6.0;       // Rischio aperto massimo di tutte le istanze CTO (% equity)
input double          InpMaxGrossLev   = 5.0;       // Nozionale lordo massimo / equity
input double          InpMinMarginLvl  = 500.0;     // Livello di margine minimo dopo un ingresso (%)
input double          InpDailyLossPct  = 3.0;       // Perdita giornaliera massima (%): blocca + chiude overlay
input double          InpHaltDDPct     = 15.0;      // Stop operativo EA: drawdown dal massimo (%)
input double          InpDailyTargetPct= 0.0;       // Target giornaliero (%) (0 = off; vedi ricerca)
input ENUM_TARGET_MODE InpTargetMode   = TGT_OFF;   // Azione al target giornaliero
input bool            InpResetHalt     = false;     // Reset manuale dello stop operativo

input group "=== Identificazione e log ==="
input long            InpMagic         = 710100;    // Magic principale (overlay = +1); unico per simbolo
input bool            InpLogCsv        = true;      // Report giornaliero CSV (cartella Common\Files)
input bool            InpDashboard     = true;      // Pannello a grafico
input bool            InpTradeLog      = true;      // Log di ogni deal (CSV) per validation/analyze_mt5.py
input double          InpReferenceTargetPct = 10.0; // Target TEORICO giornaliero (%): SOLO visualizzato, nessun effetto sul trading

//=== stato globale =====================================================
SCtoSettings   g_s;
CSymbolMath    g_sm;
CCtoIndicators g_ind;
CCoreSignal    g_core;
COverlaySignal g_ov;
CCtoExecution  g_exec;
CCtoRisk       g_risk;
CCostTracker   g_cost;
CEdgeMonitor   g_edge;
COverlayBook   g_book;
CTradeLog      g_log;
bool           g_net = true;          // overlay come gambe virtuali (netting)
datetime       g_lastCoreBar = 0, g_lastOvBar = 0;
double         g_commPerLot = 0.0;    // commissione per lotto per lato osservata (per le gambe ombra)
double         g_coreStop = 0.0;      // stop corrente della principale (netting: da ripristinare)

//--- segnali in attesa di esecuzione (fuori rollover / spread accettabile)
struct SPending
  {
   bool     active;
   int      dir;
   double   stopDist;
   datetime created;
   bool     shadow;
  };
SPending g_pendCore, g_pendOv;
bool     g_pendCoreClose = false;     // uscita per regime in attesa (fuori rollover)
bool     g_pendDayTp = false;         // presa di profitto giornaliera in attesa (fuori rollover)
datetime g_dayTpDay = 0;              // giornata D1 in cui e' scattata la presa di profitto
datetime g_lastH1Bar = 0;

//--- prototipi (alcune funzioni sono richiamate prima della loro definizione)
void CloseVirtualLeg(const int i, const string why);
void RecordLegR(const SVirtualLeg &l, const double netMoney);
void CloseAllOverlays(const string why, const bool includeShadow);
void CloseCore(const string why);
void CloseEverything(const string why);
void SyncNettingAfterCoreGone(const string why);
void EnsureCoreStop(void);

//+------------------------------------------------------------------+
//| Posizione principale                                             |
//+------------------------------------------------------------------+
bool GetCore(ulong &ticket, int &dir, double &vol, double &entry, double &sl, datetime &t)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != g_s.magicCore) continue;
      ticket = tk;
      dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      vol = PositionGetDouble(POSITION_VOLUME);
      entry = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      t = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

//--- volume nominale della principale (in netting la posizione netta e' ridotta dagli overlay reali)
double CoreNominalVolume(const double posVol)
  {
   return g_net ? posVol + g_book.VirtualVolume(false) : posVol;
  }

//+------------------------------------------------------------------+
//| Overlay reali (hedging)                                          |
//+------------------------------------------------------------------+
int CollectOverlayTickets(ulong &tickets[])
  {
   ArrayResize(tickets, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != g_s.magicOv) continue;
      int k = ArraySize(tickets);
      ArrayResize(tickets, k + 1);
      tickets[k] = tk;
     }
   return ArraySize(tickets);
  }

double OverlayVolumeReal(void)
  {
   if(g_net) return g_book.VirtualVolume(false);
   ulong tk[];
   double v = 0.0;
   int n = CollectOverlayTickets(tk);
   for(int i = 0; i < n; i++)
      if(PositionSelectByTicket(tk[i])) v += PositionGetDouble(POSITION_VOLUME);
   return v;
  }

bool AnyOverlayOpen(void)
  {
   ulong tk[];
   return g_book.LegsTotal() > 0 || CollectOverlayTickets(tk) > 0;
  }

//+------------------------------------------------------------------+
//| Chiusura degli overlay (reali, virtuali, ombra)                  |
//+------------------------------------------------------------------+
void CloseVirtualLeg(const int i, const string why)
  {
   SVirtualLeg l = g_book.Leg(i);
   double px = (l.dir > 0) ? g_sm.Bid() : g_sm.Ask();
   double vpu = g_sm.ValuePerPriceUnit();
   double cost = l.costAcc + 0.5 * g_sm.Spread() * l.volume * vpu + g_commPerLot * l.volume;
   if(!l.shadow)
     {
      SFillInfo fi;
      // gamba overlay short in netting = chiudere significa RIACQUISTARE il volume
      if(!g_exec.Open(g_s.magicOv, l.dir > 0 ? -1 : 1, l.volume, 0.0, 0.0, "CTO OVx " + why, fi)) return;
      px = fi.filled;
      g_cost.OnFill(ROLE_OVERLAY, l.volume, fi.spreadAtFill, fi.slippage);
      g_log.RememberFill(fi.deal, fi.requested, fi.slippage);
      cost = l.costAcc + fi.slippage * l.volume * vpu;   // commissioni reali registrate dai deal
      if(HistoryDealSelect(fi.deal)) cost -= HistoryDealGetDouble(fi.deal, DEAL_COMMISSION);
     }
   double pnl = l.dir * (px - l.entry) * l.volume * vpu;
   if(!l.shadow) g_cost.OnVirtualClose(pnl);
   RecordLegR(l, (pnl - cost));
   PrintFormat("[CTO] overlay %s #%I64d chiuso (%s): pnl=%.2f costi=%.2f", l.shadow ? "OMBRA" : "virtuale", l.id, why, pnl, cost);
   g_book.RemoveLeg(i);
   EnsureCoreStop();
  }

//--- R per INGRESSO: i frammenti TP accumulano nel resto della gamba; l'R entra nell'edge monitor
//    solo quando l'intero ingresso e' chiuso (evita di contare due volte i vincenti)
void RecordLegR(const SVirtualLeg &l, const double netMoney)
  {
   double r = (l.risk0 > 0.0) ? netMoney / l.risk0 : 0.0;
   if(l.isPart)
     {
      for(int k = 0; k < g_book.LegsTotal(); k++)
        {
         SVirtualLeg m = g_book.Leg(k);
         if(m.id == l.id && !m.isPart) { m.rAcc += r; g_book.SetLeg(k, m); return; }
        }
     }
   g_edge.Add(l.rAcc + r);
  }

void CloseAllOverlays(const string why, const bool includeShadow)
  {
   for(int i = g_book.LegsTotal() - 1; i >= 0; i--)
     {
      SVirtualLeg l = g_book.Leg(i);
      if(includeShadow || !l.shadow) CloseVirtualLeg(i, why);
     }
   ulong tk[];
   int n = CollectOverlayTickets(tk);
   for(int i = 0; i < n; i++)
     {
      SFillInfo fi;
      if(PositionSelectByTicket(tk[i]))
        {
         double v = PositionGetDouble(POSITION_VOLUME);
         if(g_exec.ClosePosition(tk[i], 0.0, fi))
           {
            g_cost.OnFill(ROLE_OVERLAY, v, fi.spreadAtFill, fi.slippage);
            g_log.RememberFill(fi.deal, fi.requested, fi.slippage);
           }
        }
     }
   g_pendOv.active = false;
  }

void CloseCore(const string why)
  {
   ulong t; int d; double v, e, sl; datetime ot;
   if(!GetCore(t, d, v, e, sl, ot)) return;
   SFillInfo fi;
   if(g_exec.ClosePosition(t, 0.0, fi))
     {
      g_cost.OnFill(ROLE_CORE, v, fi.spreadAtFill, fi.slippage);
      g_log.RememberFill(fi.deal, fi.requested, fi.slippage);
      PrintFormat("[CTO] principale chiusa (%s) @ %.5f", why, fi.filled);
     }
   // in netting la chiusura della posizione netta chiude implicitamente anche gli overlay reali
   if(g_net) SyncNettingAfterCoreGone(why);
   else if(!g_s.ovAfterCoreExit) CloseAllOverlays("core_exit", true);
  }

//--- chiude tutto sul simbolo con il minimo di esecuzioni:
//    in netting basta chiudere la posizione netta (le gambe virtuali si chiudono contabilmente allo stesso prezzo);
//    in hedging si chiudono prima gli overlay e poi la principale
void CloseEverything(const string why)
  {
   if(g_net)
     {
      CloseCore(why);
      SyncNettingAfterCoreGone(why);
     }
   else
     {
      CloseAllOverlays(why, true);
      CloseCore(why);
     }
  }

//--- netting: se la posizione netta non esiste piu', le gambe virtuali reali sono state chiuse con essa
void SyncNettingAfterCoreGone(const string why)
  {
   if(!g_net) return;
   ulong t; int d; double v, e, sl; datetime ot;
   if(GetCore(t, d, v, e, sl, ot)) return;
   double vpu = g_sm.ValuePerPriceUnit();
   for(int i = g_book.LegsTotal() - 1; i >= 0; i--)
     {
      SVirtualLeg l = g_book.Leg(i);
      double px = (l.dir > 0) ? g_sm.Bid() : g_sm.Ask();
      double pnl = l.dir * (px - l.entry) * l.volume * vpu;
      if(!l.shadow) g_cost.OnVirtualClose(pnl);
      l.isPart = false;
      RecordLegR(l, pnl - l.costAcc);
      g_book.RemoveLeg(i);
     }
   PrintFormat("[CTO] netting: gambe overlay chiuse insieme alla principale (%s)", why);
  }

//--- netting: gli ordini di riduzione non devono alterare lo stop della posizione netta
void EnsureCoreStop(void)
  {
   if(!g_net || g_coreStop <= 0.0) return;
   ulong t; int d; double v, e, sl; datetime ot;
   if(!GetCore(t, d, v, e, sl, ot)) return;
   if(MathAbs(sl - g_coreStop) > g_sm.Point()) g_exec.Modify(t, g_coreStop, 0.0);
  }

//+------------------------------------------------------------------+
//| Gestione delle gambe virtuali a ogni tick (stop / TP software)   |
//+------------------------------------------------------------------+
void ManageVirtualLegs(void)
  {
   for(int i = g_book.LegsTotal() - 1; i >= 0; i--)
     {
      SVirtualLeg l = g_book.Leg(i);
      double px = (l.dir > 0) ? g_sm.Bid() : g_sm.Ask();   // prezzo di uscita
      bool stopHit = (l.dir > 0) ? (px <= l.sl) : (px >= l.sl);
      if(stopHit) { CloseVirtualLeg(i, "sl"); continue; }
      if(l.tp > 0.0 && !l.tpDone)
        {
         bool tpHit = (l.dir > 0) ? (px >= l.tp) : (px <= l.tp);
         if(tpHit && l.tpVolume > 0.0 && l.tpVolume < l.volume)
           {
            //--- chiusura parziale: si divide la gamba in due e si chiude la parte TP
            SVirtualLeg part = l;
            part.volume = l.tpVolume;
            part.costAcc = l.costAcc * l.tpVolume / l.volume;
            part.tp = 0.0;
            part.isPart = true;
            l.volume -= l.tpVolume;
            l.costAcc -= part.costAcc;
            l.tpDone = true;
            g_book.SetLeg(i, l);
            g_book.AddLeg(part);
            CloseVirtualLeg(g_book.LegsTotal() - 1, "tp");
           }
         else if(tpHit)
           {
            l.tpDone = true;
            g_book.SetLeg(i, l);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Presa di profitto giornaliera della principale (modalita' harvest)|
//| Alla chiusura di ogni barra H1: se il movimento favorevole dalla  |
//| chiusura D1 precedente (o dall'ingresso, se aperta oggi) e' >=    |
//| k x ATR D1, si chiude tutto e non si rientra prima della chiusura |
//| D1 successiva; il rientro richiede di nuovo il segnale di breakout.|
//| Motivazione: docs/ sezione 5 (ritorno alla media a 20-60 giorni   |
//| e swap: tenere a lungo restituisce il profitto).                  |
//+------------------------------------------------------------------+
void CheckDayTakeProfit(void)
  {
   if(InpCoreDayTpAtr <= 0.0 || g_pendDayTp) return;
   ulong t; int d; double v, e, sl; datetime ot;
   if(!GetCore(t, d, v, e, sl, ot)) return;
   datetime today = iTime(_Symbol, InpTfCore, 0);
   if(g_dayTpDay == today) return;
   double a = g_ind.AtrCore(1);
   if(a == EMPTY_VALUE || a <= 0.0) return;
   double ref = (ot >= today) ? e : iClose(_Symbol, InpTfCore, 1);
   double c = iClose(_Symbol, PERIOD_H1, 1);          // barra H1 chiusa, come nel backtest
   if(d * (c - ref) >= InpCoreDayTpAtr * a)
     {
      g_dayTpDay = today;
      g_pendDayTp = true;
      PrintFormat("[CTO] presa di profitto giornaliera: movimento %.2f ATR >= %.2f", d * (c - ref) / a, InpCoreDayTpAtr);
     }
  }

//+------------------------------------------------------------------+
//| Logica della principale (alla chiusura di ogni barra D1)         |
//+------------------------------------------------------------------+
void OnNewCoreBar(void)
  {
   ulong t; int d; double v, e, sl; datetime ot;
   if(GetCore(t, d, v, e, sl, ot))
     {
      //--- trend invalidato? l'uscita e' eseguita fuori dalla finestra di rollover
      if(g_core.RegimeExit(d)) { g_pendCoreClose = true; return; }
      //--- chandelier: lo stop si muove solo a favore
      double tr = g_core.TrailLevel(d, ot, e);
      if(tr > 0.0)
        {
         double nsl = (d > 0) ? MathMax(sl, tr) : ((sl > 0.0) ? MathMin(sl, tr) : tr);
         if(MathAbs(nsl - sl) > g_sm.Point() && g_exec.Modify(t, nsl, 0.0)) g_coreStop = nsl;
        }
      return;
     }
   //--- nessuna principale: segnale di ingresso
   g_pendCoreClose = false;
   g_pendCore.active = false;
   if(g_risk.EntriesBlocked()) return;
   //--- nella giornata della presa di profitto non si valuta un nuovo ingresso (come nel backtest)
   if(InpCoreDayTpAtr > 0.0 && g_dayTpDay != 0 && g_dayTpDay == iTime(_Symbol, InpTfCore, 1)) return;
   int sig = g_core.EntrySignal();
   if(sig != 0)
     {
      g_pendCore.active = true;
      g_pendCore.dir = sig;
      g_pendCore.stopDist = g_core.InitialStopDistance();
      g_pendCore.created = TimeCurrent();
      PrintFormat("[CTO] segnale principale %s, stop %.5f", sig > 0 ? "LONG" : "SHORT", g_pendCore.stopDist);
     }
  }

void TryExecuteCore(void)
  {
   if(g_pendDayTp && !g_exec.InRollover())
     {
      CloseEverything("day_tp");
      ulong t1; int d1; double v1, e1, s1; datetime o1;
      if(!GetCore(t1, d1, v1, e1, s1, o1)) g_pendDayTp = false;
      return;
     }
   if(g_pendCoreClose && !g_exec.InRollover())
     {
      CloseCore("regime");
      ulong t0; int d0; double v0, e0, s0; datetime o0;
      if(!GetCore(t0, d0, v0, e0, s0, o0)) g_pendCoreClose = false;
      return;
     }
   if(!g_pendCore.active) return;
   if(TimeCurrent() - g_pendCore.created > g_s.signalExpiryHours * 3600) { g_pendCore.active = false; return; }
   if(g_risk.EntriesBlocked() || g_exec.InRollover() || !g_exec.TradingAllowed()) return;
   if(!g_exec.SpreadOk(g_ind.AtrCore(1))) return;
   ulong t; int d; double v, e, sl; datetime ot;
   if(GetCore(t, d, v, e, sl, ot)) { g_pendCore.active = false; return; }
   //--- un nuovo ciclo chiude eventuali overlay residui del ciclo precedente
   if(AnyOverlayOpen()) CloseAllOverlays("new_core", true);
   double lots = g_risk.LotsForRisk(g_s.coreRiskPct, g_pendCore.stopDist);
   if(lots <= 0.0)
     {
      //--- conto piccolo: il lotto minimo rischia piu' di InpCoreRiskPct. Lo si usa SOLO se l'utente
      //    ha dichiarato un tetto esplicito e il rischio reale del lotto minimo lo rispetta.
      double eqNow = AccountInfoDouble(ACCOUNT_EQUITY);
      double minRiskPct = (eqNow > 0.0) ? g_pendCore.stopDist * g_sm.MinLot() * g_sm.ValuePerPriceUnit() / eqNow * 100.0 : 1e9;
      if(InpMinLotMaxRiskPct > 0.0 && minRiskPct <= InpMinLotMaxRiskPct)
        {
         lots = g_sm.MinLot();
         PrintFormat("[CTO] ATTENZIONE: lotto minimo con rischio reale %.1f%% dell'equity (richiesto %.2f%%)", minRiskPct, g_s.coreRiskPct);
        }
      else
        {
         PrintFormat("[CTO] ingresso saltato: il lotto minimo rischierebbe %.1f%% dell'equity (limite %.2f%%, tetto lotto minimo %.1f%%)",
                     minRiskPct, g_s.coreRiskPct, InpMinLotMaxRiskPct);
         g_pendCore.active = false;
         return;
        }
     }
   string why;
   if(!g_risk.CanOpen(g_pendCore.dir, lots, g_pendCore.stopDist, true, why)) { PrintFormat("[CTO] ingresso principale rifiutato: %s", why); g_pendCore.active = false; return; }
   double px = (g_pendCore.dir > 0) ? g_sm.Ask() : g_sm.Bid();
   double slp = px - g_pendCore.dir * g_pendCore.stopDist;
   SFillInfo fi;
   if(g_exec.Open(g_s.magicCore, g_pendCore.dir, lots, slp, 0.0, "CTO CORE", fi))
     {
      g_cost.OnFill(ROLE_CORE, lots, fi.spreadAtFill, fi.slippage);
      g_log.RememberFill(fi.deal, fi.requested, fi.slippage);
      g_coreStop = g_sm.NormalizePrice(slp);
      PrintFormat("[CTO] principale %s %.2f lotti @ %.5f SL %.5f (spread %.1f pt, slippage %.1f pt)",
                  g_pendCore.dir > 0 ? "LONG" : "SHORT", lots, fi.filled, slp, fi.spreadAtFill / g_sm.Point(), fi.slippage / g_sm.Point());
      g_pendCore.active = false;
     }
  }

//+------------------------------------------------------------------+
//| Logica degli overlay (alla chiusura di ogni barra H4)            |
//+------------------------------------------------------------------+
void OnNewOvBar(void)
  {
   //--- trailing Donchian: reali (hedging)
   ulong tk[];
   int n = CollectOverlayTickets(tk);
   for(int i = 0; i < n; i++)
     {
      if(!PositionSelectByTicket(tk[i])) continue;
      int od = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double sl = PositionGetDouble(POSITION_SL), tr = g_ov.TrailLevel(od);
      if(tr == EMPTY_VALUE) continue;
      double nsl = (od < 0) ? MathMin(sl, tr) : MathMax(sl, tr);
      if(MathAbs(nsl - sl) > g_sm.Point()) g_exec.Modify(tk[i], nsl, PositionGetDouble(POSITION_TP));
     }
   //--- trailing: virtuali e ombra
   for(int i = 0; i < g_book.LegsTotal(); i++)
     {
      SVirtualLeg l = g_book.Leg(i);
      double tr = g_ov.TrailLevel(l.dir);
      if(tr == EMPTY_VALUE) continue;
      l.sl = (l.dir < 0) ? MathMin(l.sl, tr) : MathMax(l.sl, tr);
      g_book.SetLeg(i, l);
     }

   //--- nuovi ingressi
   g_pendOv.active = false;
   if(g_s.ovAgainst == OV_DISABLED || g_risk.EntriesBlocked()) return;
   ulong t; int d; double v, e, sl; datetime ot;
   if(!GetCore(t, d, v, e, sl, ot)) return;
   double coreNom = CoreNominalVolume(v);
   double ovVol = OverlayVolumeReal() + g_book.VirtualVolume(true);
   if(ovVol >= g_s.maxRatio * coreNom - g_sm.MinLot() * 0.5) return;
   if(g_net && v - g_sm.MinLot() < g_sm.MinLot() * 0.5) return;   // netting: la posizione netta non deve azzerarsi

   bool go = false;
   bool followShadow = false, hasOpen = false;
   //--- ultimo ingresso: gamba virtuale/ombra piu' recente oppure ingresso reale hedging
   double lastEntry = 0.0, lastR = 0.0;
   if(g_book.LegsTotal() > 0)
     {
      SVirtualLeg l = g_book.Leg(g_book.LegsTotal() - 1);
      lastEntry = l.entry; lastR = l.R; followShadow = l.shadow; hasOpen = true;
     }
   SOvEntry oe;
   if(!g_net && g_book.LastEntry(oe) && CollectOverlayTickets(tk) > 0)
     {
      lastEntry = oe.entry; lastR = oe.R; followShadow = false; hasOpen = true;
     }
   if(!hasOpen) go = g_ov.FirstEntry(d);
   else go = g_ov.AddEntry(d, lastEntry, lastR);
   if(!go) return;

   g_pendOv.active = true;
   g_pendOv.dir = -d;
   g_pendOv.stopDist = g_ov.StopDistance();
   g_pendOv.created = TimeCurrent();
   g_pendOv.shadow = hasOpen ? followShadow : !g_edge.Enabled();
   PrintFormat("[CTO] segnale overlay %s (%s), edge R medio=%.3f su %d", g_pendOv.dir > 0 ? "LONG" : "SHORT",
               g_pendOv.shadow ? "OMBRA" : "REALE", g_edge.RecentMean(), g_edge.Count());
  }

void TryExecuteOverlay(void)
  {
   if(!g_pendOv.active) return;
   if(TimeCurrent() - g_pendOv.created > g_s.signalExpiryHours * 3600) { g_pendOv.active = false; return; }
   if(g_risk.EntriesBlocked() || g_exec.InRollover()) return;
   ulong t; int d; double v, e, sl; datetime ot;
   if(!GetCore(t, d, v, e, sl, ot)) { g_pendOv.active = false; return; }
   double coreNom = CoreNominalVolume(v);
   double room = g_s.maxRatio * coreNom - (OverlayVolumeReal() + g_book.VirtualVolume(true));
   //--- netting: una riduzione pari al 100% azzererebbe la posizione netta (MT5 la chiuderebbe);
   //    resta sempre almeno un lotto minimo di esposizione nella direzione della principale
   if(g_net && !g_pendOv.shadow) room = MathMin(room, v - g_sm.MinLot());
   double lots = g_sm.NormalizeLotsDown(MathMin(g_s.hStep * coreNom, room));
   if(lots <= 0.0) { g_pendOv.active = false; return; }
   int od = g_pendOv.dir;
   double R = g_pendOv.stopDist;
   double vpu = g_sm.ValuePerPriceUnit();

   //--- OMBRA: solo tracciata (prezzo corrente, costi stimati)
   if(g_pendOv.shadow)
     {
      SVirtualLeg l;
      ZeroMemory(l);
      l.id = g_book.NewId(); l.dir = od; l.volume = lots;
      l.entry = (od > 0) ? g_sm.Ask() : g_sm.Bid();
      l.sl = l.entry - od * R; l.R = R; l.openTime = TimeCurrent(); l.shadow = true;
      l.tp = (g_s.tpR > 0) ? l.entry + od * g_s.tpR * R : 0.0;
      l.tpVolume = g_sm.NormalizeLotsDown(lots * g_s.tpFrac);
      l.costAcc = 0.5 * g_sm.Spread() * lots * vpu + g_commPerLot * lots;
      l.risk0 = lots * R * vpu;
      g_book.AddLeg(l);
      g_pendOv.active = false;
      return;
     }
   if(!g_exec.TradingAllowed() || !g_exec.SpreadOk(g_ind.AtrOv(1))) return;
   //--- in hedging il ticket opposto aggiunge nozionale e margine: controlli completi.
   //    in netting l'overlay RIDUCE l'esposizione: nessun controllo di leva/margine necessario.
   string why;
   if(!g_net && !g_risk.CanOpen(od, lots, R, false, why)) { PrintFormat("[CTO] overlay rifiutato: %s", why); g_pendOv.active = false; return; }

   if(g_net)
     {
      //--- NETTING: l'overlay riduce la posizione netta; stop/TP gestiti dall'EA
      SFillInfo fi;
      if(!g_exec.Open(g_s.magicOv, od, lots, 0.0, 0.0, "CTO OV net", fi)) return;
      g_cost.OnFill(ROLE_OVERLAY, lots, fi.spreadAtFill, fi.slippage);
      g_log.RememberFill(fi.deal, fi.requested, fi.slippage);
      SVirtualLeg l;
      ZeroMemory(l);
      l.id = g_book.NewId(); l.dir = od; l.volume = lots; l.entry = fi.filled;
      l.sl = fi.filled - od * R; l.R = R; l.openTime = TimeCurrent(); l.shadow = false;
      l.tp = (g_s.tpR > 0) ? fi.filled + od * g_s.tpR * R : 0.0;
      l.tpVolume = g_sm.NormalizeLotsDown(lots * g_s.tpFrac);
      l.costAcc = fi.slippage * lots * vpu;
      if(HistoryDealSelect(fi.deal)) l.costAcc -= HistoryDealGetDouble(fi.deal, DEAL_COMMISSION);
      l.risk0 = lots * R * vpu;
      g_book.AddLeg(l);
      EnsureCoreStop();
     }
   else
     {
      //--- HEDGING: due ticket (A con TP parziale, B runner), stop sul server
      double px = (od > 0) ? g_sm.Ask() : g_sm.Bid();
      double slp = px - od * R;
      double tpp = (g_s.tpR > 0) ? px + od * g_s.tpR * R : 0.0;
      double vA = g_sm.NormalizeLotsDown(lots * g_s.tpFrac);
      double vB = g_sm.NormalizeLotsDown(lots - vA);
      if(vA <= 0.0 || vB <= 0.0 || tpp <= 0.0) { vA = 0.0; vB = lots; }
      SOvEntry en;
      ZeroMemory(en);
      en.id = g_book.NewId(); en.dir = od; en.R = R; en.entry = px;
      en.riskMoney = (vA + vB) * R * vpu;
      SFillInfo fa, fb;
      if(vA > 0.0 && g_exec.Open(g_s.magicOv, od, vA, slp, tpp, StringFormat("CTO OV#%I64dA", en.id), fa))
        {
         g_cost.OnFill(ROLE_OVERLAY, vA, fa.spreadAtFill, fa.slippage);
         g_log.RememberFill(fa.deal, fa.requested, fa.slippage);
         if(HistoryDealSelect(fa.deal)) en.tickets[0] = (ulong)HistoryDealGetInteger(fa.deal, DEAL_POSITION_ID);
         en.openTickets++;
        }
      if(g_exec.Open(g_s.magicOv, od, vB, slp, 0.0, StringFormat("CTO OV#%I64dB", en.id), fb))
        {
         g_cost.OnFill(ROLE_OVERLAY, vB, fb.spreadAtFill, fb.slippage);
         g_log.RememberFill(fb.deal, fb.requested, fb.slippage);
         if(HistoryDealSelect(fb.deal)) en.tickets[1] = (ulong)HistoryDealGetInteger(fb.deal, DEAL_POSITION_ID);
         en.openTickets++;
         en.entry = fb.filled;
        }
      if(en.openTickets > 0) g_book.AddEntry(en);
     }
   g_pendOv.active = false;
  }

//+------------------------------------------------------------------+
//| Pannello                                                          |
//+------------------------------------------------------------------+
void Dashboard(void)
  {
   if(!InpDashboard || MQLInfoInteger(MQL_OPTIMIZATION)) return;
   ulong t; int d; double v, e, sl; datetime ot;
   bool hasCore = GetCore(t, d, v, e, sl, ot);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   SRoleBook bc = g_cost.Book(ROLE_CORE), bo = g_cost.Book(ROLE_OVERLAY);
   string s = StringFormat("CTO %s | %s | modo overlay: %s%s\n", CTO_VERSION, _Symbol, g_net ? "NETTING" : "HEDGE",
                           g_risk.Halted() ? "  *** STOP OPERATIVO ***" : (g_risk.EntriesBlocked() ? "  [ingressi bloccati oggi]" : ""));
   s += StringFormat("Equity inizio giorno %.2f | oggi %+.2f%% (target teorico %.1f%%: solo riferimento, non guida il trading) | DD giorno %.2f%% | DD dal massimo %.2f%%\n",
                     g_risk.DayStartEquity(), g_risk.DayReturn() * 100, InpReferenceTargetPct, g_risk.DayDrawdown() * 100, g_risk.DrawdownFromPeak() * 100);
   s += hasCore ? StringFormat("Principale %s %.2f lotti @ %.5f  SL %.5f  (nominale %.2f) | modalita' %s\n", d > 0 ? "LONG" : "SHORT", v, e, sl,
                               CoreNominalVolume(v), InpCoreDayTpAtr > 0.0 ? StringFormat("harvest %.2f ATR", InpCoreDayTpAtr) : "tenuta lunga")
                : "Principale: nessuna\n";
   s += StringFormat("Overlay reali %.2f lotti | ombra %.2f | edge R medio %.3f (%d ingressi) -> %s\n",
                     OverlayVolumeReal(), g_book.VirtualVolume(true), g_edge.RecentMean(), g_edge.Count(), g_edge.Enabled() ? "ATTIVO" : "OMBRA");
   s += StringFormat("Netto realizzato: principale %.2f | overlay %.2f | commissioni %.2f | swap %.2f | spread stim. %.2f | slippage %.2f\n",
                     g_cost.RealizedNet(ROLE_CORE), g_cost.RealizedNet(ROLE_OVERLAY), bc.commission + bo.commission,
                     bc.swap + bo.swap, bc.spreadCost + bo.spreadCost, bc.slippage + bo.slippage);
   s += StringFormat("Spread: ora %d pt | medio %.1f | max %d | Heat %.2f%% | Leva lorda %.2f",
                     g_sm.SpreadPoints(), g_cost.AvgSpreadPoints(), g_cost.MaxSpreadPoints(),
                     (eq > 0.0 ? g_risk.OpenRiskMoney() / eq * 100.0 : 0.0), (eq > 0.0 ? g_risk.GrossNotional() / eq : 0.0));
   Comment(s);
  }

//+------------------------------------------------------------------+
//| Eventi                                                            |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   //--- impostazioni
   g_s.tfCore = InpTfCore; g_s.emaFast = InpEmaFast; g_s.emaSlow = InpEmaSlow; g_s.donchEntry = InpDonchEntry;
   g_s.atrCore = InpAtrCore; g_s.kStop = InpKStop; g_s.kTrail = InpKTrail; g_s.coreRiskPct = InpCoreRiskPct;
   g_s.allowLong = InpAllowLong; g_s.allowShort = InpAllowShort;
   g_s.tfOv = InpTfOv; g_s.ovAgainst = InpOvAgainst; g_s.donchOv = InpDonchOv; g_s.donchOvExit = InpDonchOvExit;
   g_s.atrOv = InpAtrOv; g_s.kOvStop = InpKOvStop; g_s.hStep = InpHStep; g_s.maxRatio = InpMaxRatio; g_s.addR = InpAddR;
   g_s.tpR = InpTpR; g_s.tpFrac = InpTpFrac; g_s.ovAfterCoreExit = InpOvAfterCoreExit; g_s.edgeN = InpEdgeN; g_s.edgeMin = InpEdgeMin;
   g_s.execMode = InpExecMode; g_s.rolloverStartHour = InpRolloverStart; g_s.rolloverEndHour = InpRolloverEnd;
   g_s.maxSpreadPoints = InpMaxSpreadPts; g_s.maxSpreadAtrFrac = InpMaxSpreadAtr; g_s.deviationPoints = InpDeviation;
   g_s.maxRetries = InpMaxRetries; g_s.signalExpiryHours = InpSignalExpiryH;
   g_s.maxHeatPct = InpMaxHeatPct; g_s.maxGrossLeverage = InpMaxGrossLev; g_s.minMarginLevel = InpMinMarginLvl;
   g_s.dailyLossPct = InpDailyLossPct; g_s.haltDDPct = InpHaltDDPct; g_s.dailyTargetPct = InpDailyTargetPct; g_s.targetMode = InpTargetMode;
   g_s.magicCore = InpMagic; g_s.magicOv = InpMagic + 1; g_s.tag = "CTO"; g_s.logCsv = InpLogCsv;

   //--- validazione (nessuna martingala: incrementi limitati e solo su overlay in profitto)
   if(PeriodSeconds(InpTfOv) >= PeriodSeconds(InpTfCore)) { Print("[CTO] il TF overlay deve essere inferiore al TF principale"); return INIT_PARAMETERS_INCORRECT; }
   if(InpCoreDayTpAtr < 0.0) { Print("[CTO] InpCoreDayTpAtr non puo' essere negativo"); return INIT_PARAMETERS_INCORRECT; }
   if(InpMinLotMaxRiskPct < 0.0 || InpMinLotMaxRiskPct > 60.0) { Print("[CTO] InpMinLotMaxRiskPct fuori range (0-60%)"); return INIT_PARAMETERS_INCORRECT; }
   if(InpCoreRiskPct <= 0.0 || InpCoreRiskPct > 5.0) { Print("[CTO] rischio principale fuori range (0-5%)"); return INIT_PARAMETERS_INCORRECT; }
   if(InpMaxRatio <= 0.0 || InpMaxRatio > 1.5 || InpHStep <= 0.0 || InpHStep > InpMaxRatio) { Print("[CTO] parametri overlay non validi"); return INIT_PARAMETERS_INCORRECT; }
   if(InpKStop <= 0.0 || InpKTrail <= 0.0 || InpKOvStop <= 0.0) { Print("[CTO] stop non validi"); return INIT_PARAMETERS_INCORRECT; }

   //--- modalita' di esecuzione
   bool hedgingAccount = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(InpExecMode == EXEC_HEDGE && !hedgingAccount) Print("[CTO] conto NETTING: EXEC_HEDGE non disponibile, uso EXEC_NET");
   g_net = (InpExecMode == EXEC_NET) || !hedgingAccount;
   if(g_net && InpMaxRatio > 1.0) { Print("[CTO] in netting InpMaxRatio deve essere <= 1"); return INIT_PARAMETERS_INCORRECT; }

   g_sm.Init(_Symbol);
   if(!g_ind.Init(_Symbol, g_s)) return INIT_FAILED;
   g_core.Init(GetPointer(g_ind), g_s);
   g_ov.Init(GetPointer(g_ind), g_s);
   g_exec.Init(GetPointer(g_sm), g_s);
   g_risk.Init(g_s, GetPointer(g_sm));
   if(InpResetHalt) g_risk.ResetHalt();
   g_cost.Init(GetPointer(g_sm), g_s, g_net);
   g_edge.Init(_Symbol, g_s.magicOv, g_s.edgeN, g_s.edgeMin);
   g_book.Init(_Symbol, g_s.magicOv);
   g_log.Init(GetPointer(g_sm), g_s.magicCore, InpTradeLog);
   if(!g_net) g_book.Purge();
   g_pendCore.active = false;
   g_pendOv.active = false;
   ulong t; int d; double v, e, sl; datetime ot;
   if(GetCore(t, d, v, e, sl, ot)) g_coreStop = sl;
   g_lastCoreBar = iTime(_Symbol, InpTfCore, 0);
   g_lastOvBar = iTime(_Symbol, InpTfOv, 0);
   g_lastH1Bar = iTime(_Symbol, PERIOD_H1, 0);
   PrintFormat("[CTO] avvio %s su %s, overlay=%s, modo=%s, spread medio da misurare",
               CTO_VERSION, _Symbol, EnumToString(InpOvAgainst), g_net ? "NETTING" : "HEDGE");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Print("[CTO] riepilogo costi e P&L:\n" + g_cost.Summary());
   g_cost.Deinit();
   g_log.Deinit();
   g_ind.Release();
   Comment("");
  }

void OnTick(void)
  {
   if(!g_ind.Ready()) return;
   //--- 1. giornata, report giornaliero, limiti
   double dsEq = g_risk.DayStartEquity(), dDD = g_risk.DayDrawdown();
   datetime prevDay = iTime(_Symbol, PERIOD_D1, 1);
   if(g_risk.OnNewTick()) g_cost.WriteDay(prevDay, dsEq, AccountInfoDouble(ACCOUNT_EQUITY), dDD);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_cost.SampleSpread(eq > 0.0 ? g_risk.GrossNotional() / eq : 0.0);
   bool closeOv, closeAll;
   g_risk.Evaluate(closeOv, closeAll);
   if(closeAll) CloseEverything("risk");
   else if(closeOv) CloseAllOverlays("daily", false);

   //--- 2. la principale e' stata chiusa dallo stop sul server?
   if(g_net && g_book.LegsTotal() > 0) SyncNettingAfterCoreGone("core_stop");
   if(!g_net && !g_s.ovAfterCoreExit && AnyOverlayOpen())
     {
      ulong t0; int d0; double v0, e0, s0; datetime o0;
      if(!GetCore(t0, d0, v0, e0, s0, o0)) CloseAllOverlays("core_exit", true);
     }

   //--- 3. stop/TP software delle gambe virtuali e ombra
   ManageVirtualLegs();

   //--- 4. nuove barre (decisioni solo su barre chiuse)
   datetime hb = iTime(_Symbol, PERIOD_H1, 0);
   if(hb != g_lastH1Bar) { g_lastH1Bar = hb; CheckDayTakeProfit(); }
   datetime cb = iTime(_Symbol, InpTfCore, 0);
   if(cb != g_lastCoreBar) { g_lastCoreBar = cb; OnNewCoreBar(); }
   datetime ob = iTime(_Symbol, InpTfOv, 0);
   if(ob != g_lastOvBar) { g_lastOvBar = ob; OnNewOvBar(); }

   //--- 5. esecuzione differita (fuori rollover, spread accettabile)
   if(!g_risk.Halted())
     {
      TryExecuteCore();
      TryExecuteOverlay();
     }
   Dashboard();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   long mg = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(mg != g_s.magicCore && mg != g_s.magicOv) return;
   g_cost.OnDeal(trans.deal);
   g_log.OnDeal(trans.deal);
   double vol = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double comm = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   if(vol > 0.0 && comm != 0.0) g_commPerLot = MathAbs(comm) / vol;
   //--- R per ingresso degli overlay reali in hedging
   if(!g_net && mg == g_s.magicOv)
     {
      ulong pos = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      double net = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + comm + HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                   HistoryDealGetDouble(trans.deal, DEAL_FEE);
      bool closed = (en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY) && !PositionSelectByTicket(pos);
      double r;
      if(g_book.OnExitDeal(pos, net, closed, r))
        {
         g_edge.Add(r);
         PrintFormat("[CTO] ingresso overlay chiuso: R netto = %.3f | edge R medio %.3f", r, g_edge.RecentMean());
        }
     }
  }

//--- criterio personalizzato per l'ottimizzatore: recovery factor, penalizzato con pochi trade
double OnTester(void)
  {
   double profit = TesterStatistics(STAT_PROFIT);
   double dd = TesterStatistics(STAT_EQUITY_DD);
   double trades = TesterStatistics(STAT_TRADES);
   Print("[CTO] riepilogo tester:\n" + g_cost.Summary());
   if(trades < 30 || dd <= 0.0) return 0.0;
   return profit / dd * MathMin(1.0, MathSqrt(trades / 100.0));
  }
//+------------------------------------------------------------------+
