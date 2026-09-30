//+------------------------------------------------------------------+
//| CoreTrendOverlay - VERSIONE IN UN SOLO FILE (generata)            |
//| Generata da tools/build_single_file.py a partire da               |
//| Experts/CTO/CoreTrendOverlay.mq5 + Include/CTO/*.mqh.             |
//| Non modificare questo file: modificare i sorgenti e rigenerarlo. |
//+------------------------------------------------------------------+
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

//=== inizio Defines.mqh =================================================
//+------------------------------------------------------------------+
//|                                                  CTO/Defines.mqh |
//|   Core Trend + Counter-Trend Overlay (CTO) - tipi e impostazioni |
//+------------------------------------------------------------------+
#ifndef CTO_DEFINES_MQH
#define CTO_DEFINES_MQH

#define CTO_VERSION "1.00"

//--- ruolo di una "gamba" (leg) della strategia
enum ENUM_CTO_ROLE
  {
   ROLE_CORE    = 0,   // posizione principale (trend di lungo periodo)
   ROLE_OVERLAY = 1    // operazione opposta (overlay contro-trend)
  };

//--- contro quale direzione della principale sono ammessi gli overlay
enum ENUM_OV_AGAINST
  {
   OV_DISABLED           = 0, // overlay disattivato (solo principale)
   OV_AGAINST_SHORT_CORE = 1, // solo rimbalzi contro principale SHORT (default da ricerca)
   OV_AGAINST_LONG_CORE  = 2, // solo correzioni contro principale LONG (sconsigliato)
   OV_BOTH               = 3  // entrambe le direzioni (idea originale)
  };

//--- modalita' di esecuzione dell'overlay
enum ENUM_EXEC_MODE
  {
   EXEC_AUTO  = 0, // automatica: hedge su conto hedging, netting su conto netting
   EXEC_HEDGE = 1, // ticket opposti (richiede conto hedging; paga doppio swap)
   EXEC_NET   = 2  // riduzione della principale (gamba virtuale; nessun doppio swap)
  };

//--- cosa fare al raggiungimento del target giornaliero
enum ENUM_TARGET_MODE
  {
   TGT_OFF           = 0, // nessuna azione (raccomandato, vedi ricerca)
   TGT_BLOCK_NEW     = 1, // blocca nuovi ingressi fino al giorno successivo
   TGT_CLOSE_OVERLAY = 2, // chiude gli overlay e blocca nuovi ingressi
   TGT_CLOSE_ALL     = 3  // chiude tutto e blocca (sconsigliato: tronca i trend)
  };

//--- impostazioni complete (riempite da input nell'EA)
struct SCtoSettings
  {
   //--- principale
   ENUM_TIMEFRAMES   tfCore;
   int               emaFast;
   int               emaSlow;
   int               donchEntry;
   int               atrCore;
   double            kStop;
   double            kTrail;
   double            coreRiskPct;
   bool              allowLong;
   bool              allowShort;
   //--- overlay
   ENUM_TIMEFRAMES   tfOv;
   ENUM_OV_AGAINST   ovAgainst;
   int               donchOv;
   int               donchOvExit;
   int               atrOv;
   double            kOvStop;
   double            hStep;
   double            maxRatio;
   double            addR;
   double            tpR;
   double            tpFrac;
   bool              ovAfterCoreExit;
   int               edgeN;
   double            edgeMin;
   //--- esecuzione
   ENUM_EXEC_MODE    execMode;
   int               rolloverStartHour;
   int               rolloverEndHour;
   int               maxSpreadPoints;
   double            maxSpreadAtrFrac;
   int               deviationPoints;
   int               maxRetries;
   int               signalExpiryHours;
   //--- rischio
   double            maxHeatPct;
   double            maxGrossLeverage;
   double            minMarginLevel;
   double            dailyLossPct;
   double            haltDDPct;
   double            dailyTargetPct;
   ENUM_TARGET_MODE  targetMode;
   //--- identificazione
   long              magicCore;
   long              magicOv;
   string            tag;
   bool              logCsv;
  };

//--- gamba virtuale (netting o "ombra" dell'edge monitor)
struct SVirtualLeg
  {
   long              id;
   int               dir;        // +1 long, -1 short
   double            volume;
   double            entry;
   double            sl;
   double            tp;         // 0 = nessun TP
   double            tpVolume;   // volume da chiudere al TP
   double            R;          // distanza di stop iniziale (prezzo)
   datetime          openTime;
   bool              shadow;     // true = solo tracciata, nessun ordine
   bool              tpDone;
   double            costAcc;    // costi stimati accumulati (valuta conto)
   double            risk0;      // rischio iniziale in denaro dell'INGRESSO intero
   double            rAcc;       // R gia' realizzato da chiusure parziali dello stesso ingresso
   bool              isPart;     // true = frammento TP in chiusura (appartiene all'ingresso 'id')
  };

//--- utilita'
int    CtoSign(const double v) { return (v > 0.0) ? 1 : ((v < 0.0) ? -1 : 0); }
string CtoRoleName(const ENUM_CTO_ROLE r) { return (r == ROLE_CORE) ? "CORE" : "OVERLAY"; }

#endif
//+------------------------------------------------------------------+
//=== fine Defines.mqh ===================================================
//=== inizio SymbolMath.mqh ==============================================
//+------------------------------------------------------------------+
//|                                               CTO/SymbolMath.mqh |
//|   Conversioni prezzo <-> denaro, normalizzazione lotti.          |
//+------------------------------------------------------------------+
#ifndef CTO_SYMBOLMATH_MQH
#define CTO_SYMBOLMATH_MQH

class CSymbolMath
  {
private:
   string            m_sym;

public:
   void              Init(const string sym) { m_sym = sym; }
   string            Symbol(void) const { return m_sym; }

   double            Point(void)   const { return SymbolInfoDouble(m_sym, SYMBOL_POINT); }
   int               Digits(void)  const { return (int)SymbolInfoInteger(m_sym, SYMBOL_DIGITS); }
   double            Bid(void)     const { return SymbolInfoDouble(m_sym, SYMBOL_BID); }
   double            Ask(void)     const { return SymbolInfoDouble(m_sym, SYMBOL_ASK); }
   double            Spread(void)  const { return Ask() - Bid(); }
   int               SpreadPoints(void) const { return (int)MathRound(Spread() / Point()); }

   //--- valore in valuta del conto di 1.0 di movimento di prezzo per 1 lotto
   double            ValuePerPriceUnit(void) const
     {
      double tv = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tv <= 0.0) tv = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE);
      return (ts > 0.0) ? tv / ts : 0.0;
     }

   //--- nozionale in valuta del conto di 'lots' lotti
   double            Notional(const double lots, const double price) const
     {
      return lots * price * ValuePerPriceUnit();
     }

   double            NormalizePrice(const double p) const
     {
      double ts = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE);
      if(ts <= 0.0) return NormalizeDouble(p, Digits());
      return NormalizeDouble(MathRound(p / ts) * ts, Digits());
     }

   //--- arrotonda PER DIFETTO al passo di volume (non si aumenta mai il rischio arrotondando)
   double            NormalizeLotsDown(const double lots) const
     {
      double step = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_STEP);
      double vmin = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN);
      double vmax = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MAX);
      if(step <= 0.0) step = 0.01;
      double v = MathFloor(lots / step + 1e-9) * step;
      if(v < vmin - 1e-12) return 0.0;
      v = MathMin(v, vmax);
      int dg = (int)MathMax(0, MathCeil(-MathLog10(step)));
      return NormalizeDouble(v, dg);
     }

   double            MinLot(void) const { return SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN); }

   //--- distanza minima degli stop imposta dal broker (prezzo)
   double            StopsLevel(void) const
     {
      return (double)SymbolInfoInteger(m_sym, SYMBOL_TRADE_STOPS_LEVEL) * Point();
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine SymbolMath.mqh ================================================
//=== inizio Indicators.mqh ==============================================
//+------------------------------------------------------------------+
//|                                               CTO/Indicators.mqh |
//|   Accesso agli indicatori su barre CHIUSE (shift >= 1).          |
//|   Nessun valore della barra in formazione entra nelle decisioni. |
//+------------------------------------------------------------------+
#ifndef CTO_INDICATORS_MQH
#define CTO_INDICATORS_MQH


class CCtoIndicators
  {
private:
   string            m_symbol;
   SCtoSettings      m_s;
   int               m_hEmaFast;
   int               m_hEmaSlow;
   int               m_hAtrCore;
   int               m_hEma20Ov;
   int               m_hEma50Ov;
   int               m_hAtrOv;

   double            Buf(const int handle, const int shift) const
     {
      double v[1];
      if(handle == INVALID_HANDLE || CopyBuffer(handle, 0, shift, 1, v) != 1)
         return EMPTY_VALUE;
      return v[0];
     }

public:
                     CCtoIndicators(void) : m_hEmaFast(INVALID_HANDLE), m_hEmaSlow(INVALID_HANDLE),
                     m_hAtrCore(INVALID_HANDLE), m_hEma20Ov(INVALID_HANDLE),
                     m_hEma50Ov(INVALID_HANDLE), m_hAtrOv(INVALID_HANDLE) {}
                    ~CCtoIndicators(void) { Release(); }

   bool              Init(const string symbol, const SCtoSettings &s)
     {
      m_symbol = symbol;
      m_s = s;
      m_hEmaFast = iMA(symbol, s.tfCore, s.emaFast, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlow = iMA(symbol, s.tfCore, s.emaSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_hAtrCore = iATR(symbol, s.tfCore, s.atrCore);
      m_hEma20Ov = iMA(symbol, s.tfOv, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_hEma50Ov = iMA(symbol, s.tfOv, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_hAtrOv   = iATR(symbol, s.tfOv, s.atrOv);
      if(m_hEmaFast == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE || m_hAtrCore == INVALID_HANDLE ||
         m_hEma20Ov == INVALID_HANDLE || m_hEma50Ov == INVALID_HANDLE || m_hAtrOv == INVALID_HANDLE)
        {
         PrintFormat("[CTO] errore creazione indicatori: %d", GetLastError());
         return false;
        }
      return true;
     }

   void              Release(void)
     {
      if(m_hEmaFast != INVALID_HANDLE) IndicatorRelease(m_hEmaFast);
      if(m_hEmaSlow != INVALID_HANDLE) IndicatorRelease(m_hEmaSlow);
      if(m_hAtrCore != INVALID_HANDLE) IndicatorRelease(m_hAtrCore);
      if(m_hEma20Ov != INVALID_HANDLE) IndicatorRelease(m_hEma20Ov);
      if(m_hEma50Ov != INVALID_HANDLE) IndicatorRelease(m_hEma50Ov);
      if(m_hAtrOv   != INVALID_HANDLE) IndicatorRelease(m_hAtrOv);
      m_hEmaFast = m_hEmaSlow = m_hAtrCore = m_hEma20Ov = m_hEma50Ov = m_hAtrOv = INVALID_HANDLE;
     }

   //--- pronto se tutti i buffer hanno abbastanza storia
   bool              Ready(void) const
     {
      return BarsCalculated(m_hEmaSlow) > m_s.emaSlow + 2 &&
             BarsCalculated(m_hAtrCore) > m_s.atrCore + 2 &&
             BarsCalculated(m_hAtrOv) > m_s.atrOv + 2 &&
             Bars(m_symbol, m_s.tfCore) > MathMax(m_s.emaSlow, m_s.donchEntry) + 5 &&
             Bars(m_symbol, m_s.tfOv) > m_s.donchOv + 5;
     }

   //--- timeframe principale
   double            EmaFast(const int shift = 1) const { return Buf(m_hEmaFast, shift); }
   double            EmaSlow(const int shift = 1) const { return Buf(m_hEmaSlow, shift); }
   double            AtrCore(const int shift = 1) const { return Buf(m_hAtrCore, shift); }
   double            CloseCore(const int shift = 1) const { return iClose(m_symbol, m_s.tfCore, shift); }

   //--- massimo/minimo delle N barre PRECEDENTI a 'shift' (canale di Donchian)
   double            HighestCore(const int n, const int shift = 2) const
     {
      int idx = iHighest(m_symbol, m_s.tfCore, MODE_HIGH, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iHigh(m_symbol, m_s.tfCore, idx);
     }
   double            LowestCore(const int n, const int shift = 2) const
     {
      int idx = iLowest(m_symbol, m_s.tfCore, MODE_LOW, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iLow(m_symbol, m_s.tfCore, idx);
     }

   //--- regime: +1 rialzista, -1 ribassista, 0 indefinito (barra chiusa)
   int               Regime(void) const
     {
      double f = EmaFast(1), s = EmaSlow(1), c = CloseCore(1);
      if(f == EMPTY_VALUE || s == EMPTY_VALUE || c <= 0.0) return 0;
      if(f > s && c > s) return 1;
      if(f < s && c < s) return -1;
      return 0;
     }

   //--- massimo/minimo delle CHIUSURE del TF principale da 'since' all'ultima barra chiusa
   double            ExtremeCloseSince(const datetime since, const int dir) const
     {
      double closes[];
      datetime last = iTime(m_symbol, m_s.tfCore, 1);
      if(last < since) return 0.0;
      int n = CopyClose(m_symbol, m_s.tfCore, since, last, closes);
      if(n <= 0) return 0.0;
      double ext = closes[0];
      for(int i = 1; i < n; i++)
         ext = (dir > 0) ? MathMax(ext, closes[i]) : MathMin(ext, closes[i]);
      return ext;
     }

   //--- timeframe overlay
   double            AtrOv(const int shift = 1) const { return Buf(m_hAtrOv, shift); }
   double            Ema20Ov(const int shift = 1) const { return Buf(m_hEma20Ov, shift); }
   double            Ema50Ov(const int shift = 1) const { return Buf(m_hEma50Ov, shift); }
   double            CloseOv(const int shift = 1) const { return iClose(m_symbol, m_s.tfOv, shift); }
   double            HighestOv(const int n, const int shift) const
     {
      int idx = iHighest(m_symbol, m_s.tfOv, MODE_HIGH, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iHigh(m_symbol, m_s.tfOv, idx);
     }
   double            LowestOv(const int n, const int shift) const
     {
      int idx = iLowest(m_symbol, m_s.tfOv, MODE_LOW, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iLow(m_symbol, m_s.tfOv, idx);
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine Indicators.mqh ================================================
//=== inizio Signals.mqh =================================================
//+------------------------------------------------------------------+
//|                                                  CTO/Signals.mqh |
//|   Regole di ingresso/uscita della principale e dell'overlay.     |
//|   Tutte le funzioni lavorano su barre chiuse (niente repaint).   |
//+------------------------------------------------------------------+
#ifndef CTO_SIGNALS_MQH
#define CTO_SIGNALS_MQH


//+------------------------------------------------------------------+
//| Posizione principale: breakout di Donchian nel verso del regime  |
//+------------------------------------------------------------------+
class CCoreSignal
  {
private:
   CCtoIndicators   *m_ind;
   SCtoSettings      m_s;

public:
   void              Init(CCtoIndicators *ind, const SCtoSettings &s) { m_ind = ind; m_s = s; }

   //--- +1 apri long, -1 apri short, 0 nessun segnale (valutare alla chiusura della barra D1)
   int               EntrySignal(void) const
     {
      int reg = m_ind.Regime();
      if(reg == 0) return 0;
      double c = m_ind.CloseCore(1);
      if(reg > 0 && m_s.allowLong)
        {
         double hh = m_ind.HighestCore(m_s.donchEntry, 2);
         if(hh != EMPTY_VALUE && c > hh) return 1;
        }
      if(reg < 0 && m_s.allowShort)
        {
         double ll = m_ind.LowestCore(m_s.donchEntry, 2);
         if(ll != EMPTY_VALUE && c < ll) return -1;
        }
      return 0;
     }

   //--- trend invalidato: incrocio delle medie contro la posizione
   bool              RegimeExit(const int dir) const
     {
      double f = m_ind.EmaFast(1), s = m_ind.EmaSlow(1);
      if(f == EMPTY_VALUE || s == EMPTY_VALUE) return false;
      return (dir > 0 && f < s) || (dir < 0 && f > s);
     }

   //--- distanza dello stop iniziale (prezzo)
   double            InitialStopDistance(void) const
     {
      double a = m_ind.AtrCore(1);
      return (a == EMPTY_VALUE) ? 0.0 : m_s.kStop * a;
     }

   //--- livello chandelier: estremo delle chiusure dall'ingresso -/+ kTrail*ATR
   double            TrailLevel(const int dir, const datetime openTime, const double entry) const
     {
      double a = m_ind.AtrCore(1);
      if(a == EMPTY_VALUE) return 0.0;
      double ext = m_ind.ExtremeCloseSince(openTime, dir);
      if(ext <= 0.0) ext = entry;
      ext = (dir > 0) ? MathMax(ext, entry) : MathMin(ext, entry);
      return ext - dir * m_s.kTrail * a;
     }
  };

//+------------------------------------------------------------------+
//| Overlay: breakout contro-trend con propria logica di trade       |
//+------------------------------------------------------------------+
class COverlaySignal
  {
private:
   CCtoIndicators   *m_ind;
   SCtoSettings      m_s;

public:
   void              Init(CCtoIndicators *ind, const SCtoSettings &s) { m_ind = ind; m_s = s; }

   //--- l'overlay e' ammesso contro questa principale?
   bool              AllowedAgainst(const int coreDir) const
     {
      switch(m_s.ovAgainst)
        {
         case OV_BOTH:               return true;
         case OV_AGAINST_SHORT_CORE: return coreDir < 0;
         case OV_AGAINST_LONG_CORE:  return coreDir > 0;
         default:                    return false;
        }
     }

   //--- breakout del canale overlay nella direzione 'ovDir' sulla barra chiusa
   bool              Breakout(const int ovDir) const
     {
      double c = m_ind.CloseOv(1);
      if(ovDir < 0)
        {
         double ll = m_ind.LowestOv(m_s.donchOv, 2);
         return ll != EMPTY_VALUE && c < ll;
        }
      double hh = m_ind.HighestOv(m_s.donchOv, 2);
      return hh != EMPTY_VALUE && c > hh;
     }

   //--- conferma di momentum (EMA20/EMA50 del TF overlay allineate con l'overlay)
   bool              MomentumConfirm(const int ovDir) const
     {
      double e20 = m_ind.Ema20Ov(1), e50 = m_ind.Ema50Ov(1);
      if(e20 == EMPTY_VALUE || e50 == EMPTY_VALUE) return false;
      return (ovDir < 0) ? (e20 < e50) : (e20 > e50);
     }

   //--- primo ingresso
   bool              FirstEntry(const int coreDir) const
     {
      int od = -coreDir;
      return AllowedAgainst(coreDir) && Breakout(od) && MomentumConfirm(od);
     }

   //--- incremento: solo se l'ultimo ingresso e' in profitto >= addR * R e c'e' un nuovo breakout
   bool              AddEntry(const int coreDir, const double lastEntry, const double lastR) const
     {
      int od = -coreDir;
      double c = m_ind.CloseOv(1);
      if(lastR <= 0.0) return false;
      bool inProfit = od * (c - lastEntry) >= m_s.addR * lastR;
      return AllowedAgainst(coreDir) && inProfit && Breakout(od);
     }

   double            StopDistance(void) const
     {
      double a = m_ind.AtrOv(1);
      return (a == EMPTY_VALUE) ? 0.0 : m_s.kOvStop * a;
     }

   //--- trailing di Donchian (uscita): per overlay short = massimo delle ultime N barre
   double            TrailLevel(const int ovDir) const
     {
      return (ovDir < 0) ? m_ind.HighestOv(m_s.donchOvExit, 1) : m_ind.LowestOv(m_s.donchOvExit, 1);
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine Signals.mqh ===================================================
//=== inizio Execution.mqh ===============================================
//+------------------------------------------------------------------+
//|                                                CTO/Execution.mqh |
//|   Invio ordini con filtri di costo: spread massimo, finestra di  |
//|   rollover, retry su requote, misura dello slippage reale.       |
//+------------------------------------------------------------------+
#ifndef CTO_EXECUTION_MQH
#define CTO_EXECUTION_MQH

#include <Trade\Trade.mqh>

//--- esito di un'esecuzione (per il CostTracker)
struct SFillInfo
  {
   bool              ok;
   ulong             deal;
   ulong             order;
   double            requested;
   double            filled;
   double            volume;
   double            spreadAtFill;   // spread (prezzo) al momento dell'invio
   double            slippage;       // prezzo: > 0 = sfavorevole
  };

class CCtoExecution
  {
private:
   CTrade            m_trade;
   CSymbolMath      *m_sm;
   SCtoSettings      m_s;

   bool              Retryable(const uint rc) const
     {
      return rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
             rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TIMEOUT ||
             rc == TRADE_RETCODE_CONNECTION;
     }

   void              FillResult(SFillInfo &fi, const int dir, const double req)
     {
      fi.ok = true;
      fi.deal = m_trade.ResultDeal();
      fi.order = m_trade.ResultOrder();
      fi.requested = req;
      fi.filled = m_trade.ResultPrice();
      if(fi.filled <= 0.0) fi.filled = req;
      fi.volume = m_trade.ResultVolume();
      fi.slippage = dir * (fi.filled - req);
     }

public:
   void              Init(CSymbolMath *sm, const SCtoSettings &s)
     {
      m_sm = sm;
      m_s = s;
      m_trade.SetDeviationInPoints(s.deviationPoints);
      m_trade.SetTypeFillingBySymbol(sm.Symbol());
      m_trade.SetAsyncMode(false);
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
     }

   //--- finestra di rollover (ora server): spread molto ampi, niente nuovi ingressi
   bool              InRollover(void) const
     {
      MqlDateTime t;
      TimeToStruct(TimeCurrent(), t);
      int a = m_s.rolloverStartHour, b = m_s.rolloverEndHour;
      if(a == b) return false;
      if(a < b) return t.hour >= a && t.hour < b;
      return t.hour >= a || t.hour < b;   // finestra a cavallo della mezzanotte
     }

   //--- spread accettabile? (limite assoluto in punti E relativo all'ATR)
   bool              SpreadOk(const double atr) const
     {
      int sp = m_sm.SpreadPoints();
      if(m_s.maxSpreadPoints > 0 && sp > m_s.maxSpreadPoints) return false;
      if(m_s.maxSpreadAtrFrac > 0.0 && atr > 0.0 && m_sm.Spread() > m_s.maxSpreadAtrFrac * atr) return false;
      return true;
     }

   bool              TradingAllowed(void) const
     {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && !MQLInfoInteger(MQL_TESTER)) return false;
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
      long mode = SymbolInfoInteger(m_sm.Symbol(), SYMBOL_TRADE_MODE);
      return mode == SYMBOL_TRADE_MODE_FULL;
     }

   //--- apertura a mercato
   bool              Open(const long magic, const int dir, const double lots, const double sl, const double tp,
                          const string comment, SFillInfo &fi)
     {
      ZeroMemory(fi);
      m_trade.SetExpertMagicNumber((ulong)magic);
      for(int k = 0; k <= m_s.maxRetries; k++)
        {
         double req = (dir > 0) ? m_sm.Ask() : m_sm.Bid();
         fi.spreadAtFill = m_sm.Spread();
         bool sent = (dir > 0)
                     ? m_trade.Buy(lots, m_sm.Symbol(), 0.0, m_sm.NormalizePrice(sl), (tp > 0 ? m_sm.NormalizePrice(tp) : 0.0), comment)
                     : m_trade.Sell(lots, m_sm.Symbol(), 0.0, m_sm.NormalizePrice(sl), (tp > 0 ? m_sm.NormalizePrice(tp) : 0.0), comment);
         uint rc = m_trade.ResultRetcode();
         if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL))
           {
            FillResult(fi, dir, req);
            return true;
           }
         PrintFormat("[CTO] Open %s %.2f fallito rc=%u (%s) tentativo %d", (dir > 0 ? "BUY" : "SELL"), lots, rc,
                     m_trade.ResultRetcodeDescription(), k + 1);
         if(!Retryable(rc)) break;
         Sleep(250);
        }
      return false;
     }

   //--- chiusura (totale o parziale) di una posizione per ticket (conto hedging o netting)
   bool              ClosePosition(const ulong ticket, const double lots, SFillInfo &fi)
     {
      ZeroMemory(fi);
      if(!PositionSelectByTicket(ticket)) return false;
      int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double vol = PositionGetDouble(POSITION_VOLUME);
      m_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
      for(int k = 0; k <= m_s.maxRetries; k++)
        {
         double req = (dir > 0) ? m_sm.Bid() : m_sm.Ask();
         fi.spreadAtFill = m_sm.Spread();
         bool sent = (lots <= 0.0 || lots >= vol - 1e-9) ? m_trade.PositionClose(ticket)
                     : m_trade.PositionClosePartial(ticket, lots);
         uint rc = m_trade.ResultRetcode();
         if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL))
           {
            FillResult(fi, -dir, req);
            return true;
           }
         PrintFormat("[CTO] Close #%I64u fallito rc=%u (%s)", ticket, rc, m_trade.ResultRetcodeDescription());
         if(!Retryable(rc)) break;
         Sleep(250);
        }
      return false;
     }

   //--- modifica SL/TP (solo se cambia davvero e rispetta lo stops level)
   bool              Modify(const ulong ticket, const double sl, const double tp)
     {
      if(!PositionSelectByTicket(ticket)) return false;
      double csl = PositionGetDouble(POSITION_SL), ctp = PositionGetDouble(POSITION_TP);
      double nsl = m_sm.NormalizePrice(sl), ntp = (tp > 0.0) ? m_sm.NormalizePrice(tp) : ctp;
      if(MathAbs(nsl - csl) < m_sm.Point() * 0.5 && MathAbs(ntp - ctp) < m_sm.Point() * 0.5) return true;
      int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double px = (dir > 0) ? m_sm.Bid() : m_sm.Ask();
      if(dir * (px - nsl) <= m_sm.StopsLevel()) return false;   // troppo vicino: rimanda
      m_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
      return m_trade.PositionModify(ticket, nsl, ntp);
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine Execution.mqh =================================================
//=== inizio RiskManager.mqh =============================================
//+------------------------------------------------------------------+
//|                                              CTO/RiskManager.mqh |
//|   Dimensionamento a rischio fisso, limiti di esposizione, heat   |
//|   di portafoglio, margine, perdita giornaliera, stop operativo.  |
//|   Stato persistente in GlobalVariables (sopravvive ai riavvii).  |
//+------------------------------------------------------------------+
#ifndef CTO_RISKMANAGER_MQH
#define CTO_RISKMANAGER_MQH


class CCtoRisk
  {
private:
   SCtoSettings      m_s;
   CSymbolMath      *m_sm;
   string            m_gv;            // prefisso GlobalVariables
   datetime          m_day;           // giornata corrente (inizio, ora server)
   double            m_dayStartEq;
   double            m_peakEq;
   bool              m_blockedToday;
   bool              m_targetHit;
   bool              m_lossHit;
   bool              m_halted;
   double            m_dayMinEq;

   string            GV(const string k) const { return m_gv + k; }
   double            GetGV(const string k, const double def) const
     {
      return GlobalVariableCheck(GV(k)) ? GlobalVariableGet(GV(k)) : def;
     }
   void              SetGV(const string k, const double v) const { GlobalVariableSet(GV(k), v); }

   bool              IsOurMagic(const long mg) const
     {
      // tutte le istanze CTO condividono il blocco magic [magicCore/1000*1000, +999]
      long base = (m_s.magicCore / 1000) * 1000;
      return mg >= base && mg < base + 1000;
     }

public:
   void              Init(const SCtoSettings &s, CSymbolMath *sm)
     {
      m_s = s;
      m_sm = sm;
      m_gv = StringFormat("CTO_%I64d_%s_", s.magicCore, sm.Symbol());
      if(MQLInfoInteger(MQL_TESTER)) m_gv = "T" + m_gv;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      m_day = (datetime)GetGV("day", 0);
      m_dayStartEq = GetGV("dayStartEq", eq);
      m_peakEq = MathMax(GetGV("peakEq", eq), eq);
      m_halted = GetGV("halted", 0) > 0.5;
      m_blockedToday = GetGV("blocked", 0) > 0.5;
      m_targetHit = false;
      m_lossHit = false;
      m_dayMinEq = eq;
     }

   void              ResetHalt(void) { m_halted = false; SetGV("halted", 0); m_peakEq = AccountInfoDouble(ACCOUNT_EQUITY); SetGV("peakEq", m_peakEq); }

   //--- da chiamare a ogni tick: gestisce il cambio di giornata (ora server)
   bool              OnNewTick(void)
     {
      datetime today = iTime(m_sm.Symbol(), PERIOD_D1, 0);
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      bool newDay = false;
      if(today != m_day)
        {
         m_day = today;
         m_dayStartEq = eq;
         m_blockedToday = false;
         m_targetHit = false;
         m_lossHit = false;
         m_dayMinEq = eq;
         SetGV("day", (double)m_day);
         SetGV("dayStartEq", m_dayStartEq);
         SetGV("blocked", 0);
         newDay = true;
        }
      if(eq > m_peakEq) { m_peakEq = eq; SetGV("peakEq", m_peakEq); }
      m_dayMinEq = MathMin(m_dayMinEq, eq);
      return newDay;
     }

   //--- rendimento e drawdown della giornata
   double            DayReturn(void) const { return (m_dayStartEq > 0) ? AccountInfoDouble(ACCOUNT_EQUITY) / m_dayStartEq - 1.0 : 0.0; }
   double            DayDrawdown(void) const { return (m_dayStartEq > 0) ? 1.0 - m_dayMinEq / m_dayStartEq : 0.0; }
   double            DrawdownFromPeak(void) const { return (m_peakEq > 0) ? 1.0 - AccountInfoDouble(ACCOUNT_EQUITY) / m_peakEq : 0.0; }
   double            DayStartEquity(void) const { return m_dayStartEq; }

   //--- valuta target/limite giornaliero e stop operativo; ritorna le azioni richieste
   //    closeOverlay / closeAll vengono eseguite dall'EA
   void              Evaluate(bool &closeOverlay, bool &closeAll)
     {
      closeOverlay = false;
      closeAll = false;
      if(m_halted) return;
      //--- stop operativo dell'intero EA (drawdown dal massimo)
      if(m_s.haltDDPct > 0.0 && DrawdownFromPeak() >= m_s.haltDDPct / 100.0)
        {
         m_halted = true;
         SetGV("halted", 1);
         closeAll = true;
         PrintFormat("[CTO] STOP OPERATIVO: drawdown %.2f%% >= %.2f%%. Reset manuale richiesto (InpResetHalt).",
                     DrawdownFromPeak() * 100, m_s.haltDDPct);
         return;
        }
      double r = DayReturn();
      //--- perdita giornaliera massima: blocca ingressi e chiude gli overlay (la principale ha il suo stop)
      if(!m_lossHit && m_s.dailyLossPct > 0.0 && r <= -m_s.dailyLossPct / 100.0)
        {
         m_lossHit = true;
         m_blockedToday = true;
         SetGV("blocked", 1);
         closeOverlay = true;
         PrintFormat("[CTO] limite di perdita giornaliera raggiunto (%.2f%%): nuovi ingressi bloccati", r * 100);
        }
      //--- target giornaliero
      if(!m_targetHit && m_s.targetMode != TGT_OFF && m_s.dailyTargetPct > 0.0 && r >= m_s.dailyTargetPct / 100.0)
        {
         m_targetHit = true;
         m_blockedToday = true;
         SetGV("blocked", 1);
         if(m_s.targetMode == TGT_CLOSE_OVERLAY) closeOverlay = true;
         if(m_s.targetMode == TGT_CLOSE_ALL) closeAll = true;
         PrintFormat("[CTO] target giornaliero raggiunto (%.2f%%): azione %s", r * 100, EnumToString(m_s.targetMode));
        }
     }

   bool              Halted(void) const { return m_halted; }
   bool              EntriesBlocked(void) const { return m_halted || m_blockedToday; }

   //--- lotti per rischiare riskPct% dell'equity alla distanza di stop 'stopDist'
   double            LotsForRisk(const double riskPct, const double stopDist) const
     {
      double vpu = m_sm.ValuePerPriceUnit();
      if(stopDist <= 0.0 || vpu <= 0.0) return 0.0;
      double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * riskPct / 100.0;
      return m_sm.NormalizeLotsDown(riskMoney / (stopDist * vpu));
     }

   //--- rischio aperto (denaro) di tutte le posizioni CTO del conto (heat di portafoglio)
   double            OpenRiskMoney(void) const
     {
      double tot = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0 || !IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
         string sym = PositionGetString(POSITION_SYMBOL);
         double sl = PositionGetDouble(POSITION_SL), op = PositionGetDouble(POSITION_PRICE_OPEN);
         double cur = PositionGetDouble(POSITION_PRICE_CURRENT);
         double vol = PositionGetDouble(POSITION_VOLUME);
         int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS), ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
         if(ts <= 0) continue;
         // rischio = perdita dal prezzo CORRENTE allo stop (0 se lo stop e' gia' in profitto rispetto all'ingresso)
         double dist = (sl > 0.0) ? dir * (cur - sl) : cur * 0.10;   // senza stop: ipotesi di movimento 10%
         if(sl > 0.0 && dir * (sl - op) >= 0.0) dist = 0.0;
         tot += MathMax(dist, 0.0) * vol * tv / ts;
        }
      return tot;
     }

   //--- esposizione lorda (nozionale) di tutte le posizioni CTO, in valuta del conto
   double            GrossNotional(void) const
     {
      double tot = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0 || !IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
         string sym = PositionGetString(POSITION_SYMBOL);
         double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE), ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
         if(ts <= 0) continue;
         tot += PositionGetDouble(POSITION_VOLUME) * PositionGetDouble(POSITION_PRICE_CURRENT) * tv / ts;
        }
      return tot;
     }

   //--- controlli pre-trade: heat, leva lorda, livello di margine
   bool              CanOpen(const int dir, const double lots, const double stopDist, const bool isCore, string &why) const
     {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq <= 0.0) { why = "equity<=0"; return false; }
      double price = (dir > 0) ? m_sm.Ask() : m_sm.Bid();
      //--- heat: solo gli ingressi della principale aggiungono rischio direzionale netto
      if(isCore && m_s.maxHeatPct > 0.0)
        {
         double newRisk = stopDist * lots * m_sm.ValuePerPriceUnit();
         if(OpenRiskMoney() + newRisk > eq * m_s.maxHeatPct / 100.0) { why = "heat di portafoglio"; return false; }
        }
      //--- leva lorda
      if(m_s.maxGrossLeverage > 0.0 && GrossNotional() + m_sm.Notional(lots, price) > eq * m_s.maxGrossLeverage)
        {
         why = "leva lorda massima";
         return false;
        }
      //--- margine: livello di margine dopo l'operazione
      double m = 0.0;
      if(!OrderCalcMargin((dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_sm.Symbol(), lots, price, m)) { why = "OrderCalcMargin"; return false; }
      double used = AccountInfoDouble(ACCOUNT_MARGIN) + m;
      if(used > 0.0 && m_s.minMarginLevel > 0.0 && eq / used * 100.0 < m_s.minMarginLevel) { why = "livello di margine"; return false; }
      if(m > AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { why = "margine libero"; return false; }
      return true;
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine RiskManager.mqh ===============================================
//=== inizio CostTracker.mqh =============================================
//+------------------------------------------------------------------+
//|                                              CTO/CostTracker.mqh |
//|   Contabilita' separata PRINCIPALE / OVERLAY / COSTI:            |
//|   profitto lordo, commissioni, fee, swap, costo spread stimato,  |
//|   slippage misurato, statistiche di spread, report giornaliero.  |
//+------------------------------------------------------------------+
#ifndef CTO_COSTTRACKER_MQH
#define CTO_COSTTRACKER_MQH


struct SRoleBook
  {
   double            grossPrice;   // P&L ai prezzi eseguiti (include gia' lo spread pagato)
   double            commission;
   double            fee;
   double            swap;
   double            spreadCost;   // stima: meta' spread x volume a ogni esecuzione
   double            slippage;     // misurato: prezzo eseguito vs richiesto
   int               deals;
   int               closedTrades;
   double            virtualPnl;   // P&L delle gambe virtuali (netting) attribuito al ruolo
  };

class CCostTracker
  {
private:
   CSymbolMath      *m_sm;
   SCtoSettings      m_s;
   SRoleBook         m_book[2];
   //--- statistiche di spread (punti)
   double            m_spSum;
   long              m_spN;
   int               m_spMax;
   double            m_daySpSum;
   long              m_daySpN;
   int               m_daySpMax;
   double            m_dayMaxGross;
   int               m_file;
   string            m_fileName;
   bool              m_netting;     // overlay come gambe virtuali (riduzione della principale)

public:
                     CCostTracker(void) : m_file(INVALID_HANDLE) {}

   void              Init(CSymbolMath *sm, const SCtoSettings &s, const bool netting)
     {
      m_netting = netting;
      m_sm = sm;
      m_s = s;
      ZeroMemory(m_book[0]);
      ZeroMemory(m_book[1]);
      m_spSum = 0; m_spN = 0; m_spMax = 0;
      m_daySpSum = 0; m_daySpN = 0; m_daySpMax = 0; m_dayMaxGross = 0;
      m_fileName = StringFormat("CTO_daily_%s_%I64d.csv", sm.Symbol(), s.magicCore);
      if(s.logCsv && !MQLInfoInteger(MQL_OPTIMIZATION))   // niente file durante l'ottimizzazione
        {
         bool exists = FileIsExist(m_fileName, FILE_COMMON);
         m_file = FileOpen(m_fileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_SHARE_READ, ';');
         if(m_file != INVALID_HANDLE)
           {
            FileSeek(m_file, 0, SEEK_END);
            if(!exists)
               FileWrite(m_file, "date", "equity_start", "equity_end", "ret_pct", "day_dd_pct",
                         "gross_core", "gross_ov", "commission", "fee", "swap", "spread_cost_est", "slippage",
                         "net_core", "net_ov", "avg_spread_pts", "max_spread_pts", "max_gross_exposure");
           }
        }
     }

   void              Deinit(void) { if(m_file != INVALID_HANDLE) { FileClose(m_file); m_file = INVALID_HANDLE; } }

   //--- campionamento dello spread a ogni tick
   void              SampleSpread(const double grossExposureRatio)
     {
      int sp = m_sm.SpreadPoints();
      m_spSum += sp; m_spN++; m_spMax = (int)MathMax(m_spMax, sp);
      m_daySpSum += sp; m_daySpN++; m_daySpMax = (int)MathMax(m_daySpMax, sp);
      m_dayMaxGross = MathMax(m_dayMaxGross, grossExposureRatio);
     }

   double            AvgSpreadPoints(void) const { return (m_spN > 0) ? m_spSum / m_spN : 0.0; }
   int               MaxSpreadPoints(void) const { return m_spMax; }

   //--- costo stimato di spread + slippage di un'esecuzione
   void              OnFill(const ENUM_CTO_ROLE role, const double volume, const double spread, const double slip)
     {
      double vpu = m_sm.ValuePerPriceUnit();
      m_book[role].spreadCost += 0.5 * spread * volume * vpu;
      m_book[role].slippage += slip * volume * vpu;
     }

   //--- P&L di una gamba overlay virtuale (netting), calcolato ai suoi prezzi di ingresso/uscita.
   //    Il broker realizza quel P&L dentro la posizione netta (registrata come CORE): lo si sposta
   //    contabilmente da CORE a OVERLAY, cosi' il totale coincide sempre con il conto.
   void              OnVirtualClose(const double pnlMoney)
     {
      m_book[ROLE_OVERLAY].virtualPnl += pnlMoney;
      m_book[ROLE_CORE].virtualPnl -= pnlMoney;
      m_book[ROLE_OVERLAY].closedTrades++;
     }

   //--- da OnTradeTransaction: registra ogni deal dei nostri magic
   void              OnDeal(const ulong deal)
     {
      if(!HistoryDealSelect(deal)) return;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != m_sm.Symbol()) return;
      long mg = HistoryDealGetInteger(deal, DEAL_MAGIC);
      int r = -1;
      if(mg == m_s.magicCore) r = ROLE_CORE;
      else if(mg == m_s.magicOv) r = ROLE_OVERLAY;
      if(r < 0) return;
      // in netting il profitto realizzato appartiene alla posizione netta (CORE); i costi restano al ruolo
      m_book[m_netting ? ROLE_CORE : r].grossPrice += HistoryDealGetDouble(deal, DEAL_PROFIT);
      m_book[r].commission += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      m_book[r].fee += HistoryDealGetDouble(deal, DEAL_FEE);
      m_book[r].swap += HistoryDealGetDouble(deal, DEAL_SWAP);
      m_book[r].deals++;
      ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(e == DEAL_ENTRY_OUT || e == DEAL_ENTRY_OUT_BY) m_book[r].closedTrades++;
     }

   //--- swap non ancora realizzato delle posizioni aperte per ruolo
   double            OpenSwap(const long magic) const
     {
      double s = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_sm.Symbol() || PositionGetInteger(POSITION_MAGIC) != magic) continue;
         s += PositionGetDouble(POSITION_SWAP);
        }
      return s;
     }

   //--- netto realizzato del ruolo (P&L eseguito + commissioni + fee + swap + P&L virtuale)
   double            RealizedNet(const ENUM_CTO_ROLE r) const
     {
      return m_book[r].grossPrice + m_book[r].commission + m_book[r].fee + m_book[r].swap + m_book[r].virtualPnl;
     }
   //--- "lordo" = prima di TUTTI i costi (aggiunge indietro spread stimato, slippage, commissioni, swap)
   double            RealizedGrossBeforeCosts(const ENUM_CTO_ROLE r) const
     {
      return m_book[r].grossPrice + m_book[r].virtualPnl + m_book[r].spreadCost + m_book[r].slippage;
     }
   double            TotalCosts(void) const
     {
      double c = 0.0;
      for(int r = 0; r < 2; r++)
         c += m_book[r].spreadCost + m_book[r].slippage - m_book[r].commission - m_book[r].fee - MathMin(m_book[r].swap, 0.0);
      return c;
     }
   SRoleBook         Book(const ENUM_CTO_ROLE r) const { return m_book[r]; }

   //--- riga del report giornaliero (chiamata al cambio di giornata)
   void              WriteDay(const datetime day, const double eqStart, const double eqEnd, const double dayDD)
     {
      if(m_file == INVALID_HANDLE) return;
      FileWrite(m_file, TimeToString(day, TIME_DATE), DoubleToString(eqStart, 2), DoubleToString(eqEnd, 2),
                DoubleToString((eqStart > 0 ? (eqEnd / eqStart - 1) * 100 : 0), 4), DoubleToString(dayDD * 100, 4),
                DoubleToString(RealizedGrossBeforeCosts(ROLE_CORE), 2), DoubleToString(RealizedGrossBeforeCosts(ROLE_OVERLAY), 2),
                DoubleToString(m_book[0].commission + m_book[1].commission, 2), DoubleToString(m_book[0].fee + m_book[1].fee, 2),
                DoubleToString(m_book[0].swap + m_book[1].swap + OpenSwap(m_s.magicCore) + OpenSwap(m_s.magicOv), 2),
                DoubleToString(m_book[0].spreadCost + m_book[1].spreadCost, 2), DoubleToString(m_book[0].slippage + m_book[1].slippage, 2),
                DoubleToString(RealizedNet(ROLE_CORE), 2), DoubleToString(RealizedNet(ROLE_OVERLAY), 2),
                DoubleToString(m_daySpN > 0 ? m_daySpSum / m_daySpN : 0, 1), IntegerToString(m_daySpMax),
                DoubleToString(m_dayMaxGross, 3));
      FileFlush(m_file);
      m_daySpSum = 0; m_daySpN = 0; m_daySpMax = 0; m_dayMaxGross = 0;
     }

   //--- riepilogo finale (tester o chiusura EA)
   string            Summary(void) const
     {
      string s = "";
      for(int r = 0; r < 2; r++)
        {
         s += StringFormat("%s: lordo(pre-costi)=%.2f  eseguito=%.2f  comm=%.2f  fee=%.2f  swap=%.2f  spread(stima)=%.2f  slippage=%.2f  netto=%.2f  deal=%d\n",
                           CtoRoleName((ENUM_CTO_ROLE)r), RealizedGrossBeforeCosts((ENUM_CTO_ROLE)r), m_book[r].grossPrice + m_book[r].virtualPnl,
                           m_book[r].commission, m_book[r].fee, m_book[r].swap, m_book[r].spreadCost, m_book[r].slippage,
                           RealizedNet((ENUM_CTO_ROLE)r), m_book[r].deals);
        }
      double gross = RealizedGrossBeforeCosts(ROLE_CORE) + RealizedGrossBeforeCosts(ROLE_OVERLAY);
      double costs = TotalCosts();
      s += StringFormat("COSTI TOTALI=%.2f  lordo/costi=%.2f  spread medio=%.1f pt  spread max=%d pt",
                        costs, (costs > 0 ? gross / costs : 0.0), AvgSpreadPoints(), MaxSpreadPoints());
      return s;
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine CostTracker.mqh ===============================================
//=== inizio EdgeMonitor.mqh =============================================
//+------------------------------------------------------------------+
//|                                              CTO/EdgeMonitor.mqh |
//|   Misura in tempo reale l'aspettativa (in R, NETTA dei costi)    |
//|   degli overlay. Se la media degli ultimi N ingressi scende      |
//|   sotto la soglia, gli overlay diventano "ombra": continuano a   |
//|   essere tracciati virtualmente (nessun ordine) finche' la loro  |
//|   aspettativa non torna positiva.                                |
//|   Un R e' calcolato PER INGRESSO (somma dei parziali / rischio   |
//|   iniziale), non per singolo record di chiusura parziale.        |
//+------------------------------------------------------------------+
#ifndef CTO_EDGEMONITOR_MQH
#define CTO_EDGEMONITOR_MQH


class CEdgeMonitor
  {
private:
   double            m_r[];
   int               m_n;          // finestra
   double            m_min;        // soglia
   string            m_file;

   void              Save(void) const
     {
      if(MQLInfoInteger(MQL_TESTER)) return;
      int h = FileOpen(m_file, FILE_WRITE | FILE_CSV | FILE_COMMON, ';');
      if(h == INVALID_HANDLE) return;
      for(int i = 0; i < ArraySize(m_r); i++) FileWrite(h, DoubleToString(m_r[i], 5));
      FileClose(h);
     }
   void              Load(void)
     {
      ArrayResize(m_r, 0);
      if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(m_file, FILE_COMMON)) return;
      int h = FileOpen(m_file, FILE_READ | FILE_CSV | FILE_COMMON, ';');
      if(h == INVALID_HANDLE) return;
      while(!FileIsEnding(h))
        {
         string s = FileReadString(h);
         if(StringLen(s) == 0) continue;
         int k = ArraySize(m_r);
         ArrayResize(m_r, k + 1);
         m_r[k] = StringToDouble(s);
        }
      FileClose(h);
     }

public:
   void              Init(const string sym, const long magic, const int n, const double minR)
     {
      m_n = n;
      m_min = minR;
      m_file = StringFormat("CTO_edge_%s_%I64d.csv", sym, magic);
      Load();
     }

   void              Add(const double r)
     {
      int k = ArraySize(m_r);
      ArrayResize(m_r, k + 1);
      m_r[k] = r;
      if(ArraySize(m_r) > 500) ArrayRemove(m_r, 0, ArraySize(m_r) - 500);
      Save();
     }

   int               Count(void) const { return ArraySize(m_r); }

   double            RecentMean(void) const
     {
      int k = ArraySize(m_r);
      if(k == 0 || m_n <= 0) return 0.0;
      int from = MathMax(0, k - m_n);
      double s = 0.0;
      for(int i = from; i < k; i++) s += m_r[i];
      return s / (k - from);
     }

   //--- true = overlay reale; false = overlay ombra
   bool              Enabled(void) const
     {
      if(m_n <= 0 || ArraySize(m_r) < m_n) return true;   // riscaldamento: ancora nessuna evidenza
      return RecentMean() > m_min;
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine EdgeMonitor.mqh ===============================================
//=== inizio OverlayBook.mqh =============================================
//+------------------------------------------------------------------+
//|                                              CTO/OverlayBook.mqh |
//|   Registro degli ingressi overlay:                               |
//|   - gambe VIRTUALI (conto netting / modalita' EXEC_NET) e        |
//|     gambe OMBRA (edge monitor): stop/TP gestiti dall'EA          |
//|   - ingressi REALI in hedging: mappa ticket -> ingresso, per     |
//|     calcolare l'R netto per ingresso (anche con 2 ticket A/B).   |
//|   Persistenza su file (FILE_COMMON) per sopravvivere ai riavvii. |
//+------------------------------------------------------------------+
#ifndef CTO_OVERLAYBOOK_MQH
#define CTO_OVERLAYBOOK_MQH


//--- ingresso overlay reale (hedging): aggrega i ticket A (con TP) e B (runner)
struct SOvEntry
  {
   long              id;
   double            riskMoney;   // rischio iniziale in denaro (volume totale x R x valore)
   double            netAcc;      // netto accumulato (profitto + commissioni + swap)
   int               openTickets;
   ulong             tickets[2];
   double            entry;
   double            R;
   int               dir;
  };

class COverlayBook
  {
private:
   SVirtualLeg       m_legs[];
   SOvEntry          m_entries[];
   long              m_nextId;
   string            m_file;

public:
   void              Init(const string sym, const long magic)
     {
      m_file = StringFormat("CTO_ovbook_%s_%I64d.bin", sym, magic);
      m_nextId = 1;
      Load();
     }

   long              NewId(void) { return m_nextId++; }

   //------------------------------------------------------------- gambe virtuali
   int               LegsTotal(void) const { return ArraySize(m_legs); }
   SVirtualLeg       Leg(const int i) const { return m_legs[i]; }
   void              SetLeg(const int i, const SVirtualLeg &l) { m_legs[i] = l; Save(); }
   void              AddLeg(const SVirtualLeg &l)
     {
      int k = ArraySize(m_legs);
      ArrayResize(m_legs, k + 1);
      m_legs[k] = l;
      Save();
     }
   void              RemoveLeg(const int i) { ArrayRemove(m_legs, i, 1); Save(); }

   double            VirtualVolume(const bool shadow) const
     {
      double v = 0.0;
      for(int i = 0; i < ArraySize(m_legs); i++)
         if(m_legs[i].shadow == shadow) v += m_legs[i].volume;
      return v;
     }

   //------------------------------------------------------------- ingressi reali (hedging)
   void              AddEntry(const SOvEntry &e)
     {
      int k = ArraySize(m_entries);
      ArrayResize(m_entries, k + 1);
      m_entries[k] = e;
      Save();
     }
   int               EntriesTotal(void) const { return ArraySize(m_entries); }
   SOvEntry          Entry(const int i) const { return m_entries[i]; }

   //--- trova l'ingresso che contiene la posizione 'posId'; -1 se sconosciuto
   int               FindByPosition(const ulong posId) const
     {
      for(int i = 0; i < ArraySize(m_entries); i++)
         for(int j = 0; j < 2; j++)
            if(m_entries[i].tickets[j] == posId && posId != 0) return i;
      return -1;
     }

   //--- registra un deal di chiusura; ritorna true (e l'R) quando l'ingresso e' completamente chiuso
   bool              OnExitDeal(const ulong posId, const double net, const bool positionClosed, double &rOut)
     {
      int i = FindByPosition(posId);
      if(i < 0) return false;
      m_entries[i].netAcc += net;
      if(positionClosed) m_entries[i].openTickets--;
      bool done = m_entries[i].openTickets <= 0;
      if(done)
        {
         rOut = (m_entries[i].riskMoney > 0) ? m_entries[i].netAcc / m_entries[i].riskMoney : 0.0;
         ArrayRemove(m_entries, i, 1);
        }
      Save();
      return done;
     }

   //--- ultimo ingresso reale aperto (per le regole di incremento)
   bool              LastEntry(SOvEntry &e) const
     {
      int k = ArraySize(m_entries);
      if(k == 0) return false;
      e = m_entries[k - 1];
      return true;
     }

   //--- rimuove ingressi i cui ticket non esistono piu' (es. chiusi mentre l'EA era spento)
   void              Purge(void)
     {
      for(int i = ArraySize(m_entries) - 1; i >= 0; i--)
        {
         bool alive = false;
         for(int j = 0; j < 2; j++)
            if(m_entries[i].tickets[j] != 0 && PositionSelectByTicket(m_entries[i].tickets[j])) alive = true;
         if(!alive) ArrayRemove(m_entries, i, 1);
        }
      Save();
     }

   //------------------------------------------------------------- persistenza
   void              Save(void) const
     {
      if(MQLInfoInteger(MQL_TESTER)) return;
      int h = FileOpen(m_file, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(h == INVALID_HANDLE) return;
      FileWriteLong(h, m_nextId);
      FileWriteArray(h, m_legs);
      FileWriteInteger(h, ArraySize(m_entries));
      for(int i = 0; i < ArraySize(m_entries); i++) FileWriteStruct(h, m_entries[i]);
      FileClose(h);
     }
   void              Load(void)
     {
      ArrayResize(m_legs, 0);
      ArrayResize(m_entries, 0);
      if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(m_file, FILE_COMMON)) return;
      int h = FileOpen(m_file, FILE_READ | FILE_BIN | FILE_COMMON);
      if(h == INVALID_HANDLE) return;
      m_nextId = FileReadLong(h);
      FileReadArray(h, m_legs);
      int n = FileReadInteger(h);
      ArrayResize(m_entries, n);
      for(int i = 0; i < n; i++) FileReadStruct(h, m_entries[i]);
      FileClose(h);
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine OverlayBook.mqh ===============================================
//=== inizio TradeLog.mqh ================================================
//+------------------------------------------------------------------+
//|                                                 CTO/TradeLog.mqh |
//|   Registro di OGNI deal dell'EA (ingressi e uscite) in CSV, per  |
//|   l'analisi esterna dei backtest e del conto reale:              |
//|   validation/analyze_mt5.py (stress costi, Monte Carlo, criteri).|
//|   File: Common\Files\CTO_trades_<sym>_<magic>_<tester|live>.csv  |
//+------------------------------------------------------------------+
#ifndef CTO_TRADELOG_MQH
#define CTO_TRADELOG_MQH


class CTradeLog
  {
private:
   int               m_h;
   CSymbolMath      *m_sm;
   long              m_magicCore;
   //--- esecuzioni a mercato dell'EA: prezzo richiesto e slippage misurato, per deal
   ulong             m_fillDeal[];
   double            m_fillReq[];
   double            m_fillSlip[];

   int               FindFill(const ulong deal) const
     {
      for(int i = ArraySize(m_fillDeal) - 1; i >= 0; i--)
         if(m_fillDeal[i] == deal) return i;
      return -1;
     }

public:
                     CTradeLog(void) : m_h(INVALID_HANDLE) {}

   void              Init(CSymbolMath *sm, const long magicCore, const bool enabled)
     {
      m_sm = sm;
      m_magicCore = magicCore;
      if(!enabled || MQLInfoInteger(MQL_OPTIMIZATION)) return;
      bool tester = (bool)MQLInfoInteger(MQL_TESTER);
      string name = StringFormat("CTO_trades_%s_%I64d_%s.csv", sm.Symbol(), magicCore, tester ? "tester" : "live");
      // nel tester ogni esecuzione riparte da un file nuovo; dal vivo si accoda
      int flags = FILE_CSV | FILE_COMMON | FILE_SHARE_READ | (tester ? FILE_WRITE : (FILE_READ | FILE_WRITE));
      bool exists = !tester && FileIsExist(name, FILE_COMMON);
      m_h = FileOpen(name, flags, ';');
      if(m_h == INVALID_HANDLE) { PrintFormat("[CTO] impossibile aprire %s", name); return; }
      if(!tester) FileSeek(m_h, 0, SEEK_END);
      if(!exists)
         FileWrite(m_h, "time", "symbol", "magic", "role", "position_id", "entry", "type", "volume", "price", "sl",
                   "profit", "commission", "swap", "fee", "reason", "spread_price", "value_per_price_unit",
                   "deal_sl", "deal_tp", "requested_price", "slippage_price",
                   "balance", "equity", "account_currency", "broker", "server");
     }

   //--- registra prezzo richiesto e slippage di un'esecuzione a mercato (il deal arriva dopo in OnTradeTransaction)
   void              RememberFill(const ulong deal, const double requested, const double slippage)
     {
      if(deal == 0) return;
      int k = ArraySize(m_fillDeal);
      if(k >= 64) { ArrayRemove(m_fillDeal, 0, 32); ArrayRemove(m_fillReq, 0, 32); ArrayRemove(m_fillSlip, 0, 32); k = ArraySize(m_fillDeal); }
      ArrayResize(m_fillDeal, k + 1); ArrayResize(m_fillReq, k + 1); ArrayResize(m_fillSlip, k + 1);
      m_fillDeal[k] = deal; m_fillReq[k] = requested; m_fillSlip[k] = slippage;
     }

   void              Deinit(void) { if(m_h != INVALID_HANDLE) { FileClose(m_h); m_h = INVALID_HANDLE; } }

   //--- da chiamare in OnTradeTransaction per ogni deal dei nostri magic
   void              OnDeal(const ulong deal)
     {
      if(m_h == INVALID_HANDLE || !HistoryDealSelect(deal)) return;
      long mg = HistoryDealGetInteger(deal, DEAL_MAGIC);
      ulong pos = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      //--- stop della posizione (serve per il rischio iniziale = 1 R); 0 se la posizione e' gia' chiusa
      double sl = 0.0;
      if(PositionSelectByTicket(pos)) sl = PositionGetDouble(POSITION_SL);
      //--- slippage: misurato dall'EA per gli ordini a mercato; per stop/TP del server = distanza dal livello
      int fk = FindFill(deal);
      double req = (fk >= 0) ? m_fillReq[fk] : 0.0;
      double slip = (fk >= 0) ? m_fillSlip[fk] : 0.0;
      double dsl = HistoryDealGetDouble(deal, DEAL_SL), dtp = HistoryDealGetDouble(deal, DEAL_TP);
      ENUM_DEAL_REASON rsn = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
      double dpx = HistoryDealGetDouble(deal, DEAL_PRICE);
      int dealDir = (HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? 1 : -1;
      if(fk < 0 && rsn == DEAL_REASON_SL && dsl > 0.0) { req = dsl; slip = dealDir * (dpx - dsl); }
      if(fk < 0 && rsn == DEAL_REASON_TP && dtp > 0.0) { req = dtp; slip = dealDir * (dpx - dtp); }
      string enS = (en == DEAL_ENTRY_IN) ? "IN" : ((en == DEAL_ENTRY_OUT) ? "OUT" : ((en == DEAL_ENTRY_INOUT) ? "INOUT" : "OUT_BY"));
      string tyS = (HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      FileWrite(m_h,
                TimeToString((datetime)HistoryDealGetInteger(deal, DEAL_TIME), TIME_DATE | TIME_SECONDS),
                HistoryDealGetString(deal, DEAL_SYMBOL), IntegerToString(mg),
                (mg == m_magicCore) ? "CORE" : "OVERLAY", IntegerToString((long)pos), enS, tyS,
                DoubleToString(HistoryDealGetDouble(deal, DEAL_VOLUME), 2),
                DoubleToString(HistoryDealGetDouble(deal, DEAL_PRICE), m_sm.Digits()),
                DoubleToString(sl, m_sm.Digits()),
                DoubleToString(HistoryDealGetDouble(deal, DEAL_PROFIT), 2),
                DoubleToString(HistoryDealGetDouble(deal, DEAL_COMMISSION), 2),
                DoubleToString(HistoryDealGetDouble(deal, DEAL_SWAP), 2),
                DoubleToString(HistoryDealGetDouble(deal, DEAL_FEE), 2),
                EnumToString(rsn),
                DoubleToString(m_sm.Spread(), m_sm.Digits()),          // spread al momento della transazione
                DoubleToString(m_sm.ValuePerPriceUnit(), 6),
                DoubleToString(dsl, m_sm.Digits()), DoubleToString(dtp, m_sm.Digits()),
                DoubleToString(req, m_sm.Digits()), DoubleToString(slip, m_sm.Digits() + 1),
                DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
                DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
                AccountInfoString(ACCOUNT_CURRENCY), AccountInfoString(ACCOUNT_COMPANY), AccountInfoString(ACCOUNT_SERVER));
      FileFlush(m_h);
     }
  };

#endif
//+------------------------------------------------------------------+
//=== fine TradeLog.mqh ==================================================
//=== inizio EventLog.mqh ================================================
//+------------------------------------------------------------------+
//|                                                 CTO/EventLog.mqh |
//|   Registro dei MOTIVI per cui un ingresso e' avvenuto, e' stato  |
//|   rinviato o e' stato saltato. Solo strumentazione: non cambia   |
//|   nessuna decisione di trading.                                  |
//|   File: Common\Files\CTO_events_<sym>_<magic>_<tester|live>.csv  |
//|                                                                  |
//|   Codici e categoria:                                            |
//|    SIGNAL             segnale generato (in attesa di esecuzione) |
//|    NO_SIGNAL          nessun segnale alla chiusura D1 (normale)  |
//|    TRADE_OPENED       eseguito                                   |
//|    SHADOW_OPENED      overlay "ombra" (edge monitor)             |
//|    MINLOT_OVERRIDE    eseguito al lotto minimo oltre il rischio  |
//|                       previsto (solo preset esperimento)         |
//|    DAYTP_NO_REENTRY   regola della variante C (normale)          |
//|    RISK_TOO_HIGH      CAPITALE: lotto minimo oltre il rischio    |
//|    LOT_BELOW_MINIMUM  GRANULARITA': volume sotto il lotto minimo |
//|    MARGIN_TOO_HIGH    CAPITALE/LEVA: margine insufficiente       |
//|    LEVERAGE_LIMIT     CAPITALE/LEVA: leva lorda massima          |
//|    HEAT_LIMIT         RISCHIO: heat di portafoglio               |
//|    ENTRIES_BLOCKED    RISCHIO: perdita giornaliera/stop operativo|
//|    SPREAD_TOO_HIGH    COSTO: rinvio per spread (filtro)          |
//|    ROLLOVER_BLOCKED   OPERATIVO: rinvio per rollover (filtro)    |
//|    TRADING_DISABLED   OPERATIVO: trading non consentito          |
//|    ORDER_FAILED       OPERATIVO: ordine rifiutato dal server     |
//|    SIGNAL_EXPIRED     segnale scaduto (con l'ultimo motivo)      |
//+------------------------------------------------------------------+
#ifndef CTO_EVENTLOG_MQH
#define CTO_EVENTLOG_MQH

class CEventLog
  {
private:
   int               m_h;
   string            m_sym;
   string            m_lastDefer[2];   // ultimo motivo di rinvio per ruolo (evita righe ripetute a ogni tick)

public:
                     CEventLog(void) : m_h(INVALID_HANDLE) {}

   void              Init(const string sym, const long magic, const bool enabled)
     {
      m_sym = sym;
      m_lastDefer[0] = ""; m_lastDefer[1] = "";
      if(!enabled || MQLInfoInteger(MQL_OPTIMIZATION)) return;
      bool tester = (bool)MQLInfoInteger(MQL_TESTER);
      string name = StringFormat("CTO_events_%s_%I64d_%s.csv", sym, magic, tester ? "tester" : "live");
      bool exists = !tester && FileIsExist(name, FILE_COMMON);
      int flags = FILE_CSV | FILE_COMMON | FILE_SHARE_READ | (tester ? FILE_WRITE : (FILE_READ | FILE_WRITE));
      m_h = FileOpen(name, flags, ';');
      if(m_h == INVALID_HANDLE) return;
      if(!tester) FileSeek(m_h, 0, SEEK_END);
      if(!exists) FileWrite(m_h, "time", "symbol", "role", "code", "dir", "detail", "equity");
     }

   void              Deinit(void) { if(m_h != INVALID_HANDLE) { FileClose(m_h); m_h = INVALID_HANDLE; } }

   //--- evento puntuale
   void              Log(const int role, const string code, const int dir, const string detail)
     {
      if(m_h == INVALID_HANDLE) return;
      FileWrite(m_h, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), m_sym, role == 0 ? "CORE" : "OVERLAY",
                code, IntegerToString(dir), detail, DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
     }

   //--- rinvio: registrato solo quando il motivo cambia per quel segnale
   void              Defer(const int role, const string code, const int dir, const string detail)
     {
      if(m_lastDefer[role] == code) return;
      m_lastDefer[role] = code;
      Log(role, code, dir, detail);
     }
   string            LastDefer(const int role) const { return m_lastDefer[role]; }
   void              ResetDefer(const int role) { m_lastDefer[role] = ""; }
  };

#endif
//+------------------------------------------------------------------+
//=== fine EventLog.mqh ==================================================

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
CEventLog      g_ev;
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

//--- codice evento per il motivo restituito da CCtoRisk::CanOpen (solo strumentazione)
string RiskReasonCode(const string why)
  {
   if(StringFind(why, "heat") >= 0) return "HEAT_LIMIT";
   if(StringFind(why, "leva") >= 0) return "LEVERAGE_LIMIT";
   if(StringFind(why, "margin") >= 0 || StringFind(why, "Margin") >= 0) return "MARGIN_TOO_HIGH";
   return "RISK_REJECTED";
  }

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
   if(g_pendCore.active) g_ev.Log(0, "SIGNAL_EXPIRED", g_pendCore.dir, "sostituito da nuova barra; ultimo rinvio: " + g_ev.LastDefer(0));
   g_pendCore.active = false;
   g_ev.ResetDefer(0);
   if(g_risk.EntriesBlocked())
     {
      int sb = g_core.EntrySignal();          // funzione pura: calcolata solo per il registro
      if(sb != 0) g_ev.Log(0, "ENTRIES_BLOCKED", sb, "segnale presente ma ingressi bloccati (perdita giornaliera/stop operativo)");
      return;
     }
   //--- nella giornata della presa di profitto non si valuta un nuovo ingresso (come nel backtest)
   if(InpCoreDayTpAtr > 0.0 && g_dayTpDay != 0 && g_dayTpDay == iTime(_Symbol, InpTfCore, 1))
     {
      int sd = g_core.EntrySignal();          // funzione pura: calcolata solo per il registro
      g_ev.Log(0, "DAYTP_NO_REENTRY", sd, "giornata della presa di profitto: nessun nuovo ingresso valutato");
      return;
     }
   int sig = g_core.EntrySignal();
   if(sig == 0) g_ev.Log(0, "NO_SIGNAL", 0, "regime " + IntegerToString(g_ind.Regime()));
   if(sig != 0)
     {
      g_ev.Log(0, "SIGNAL", sig, StringFormat("stop %.5f", g_core.InitialStopDistance()));
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
   if(TimeCurrent() - g_pendCore.created > g_s.signalExpiryHours * 3600)
     {
      g_ev.Log(0, "SIGNAL_EXPIRED", g_pendCore.dir, "ultimo rinvio: " + g_ev.LastDefer(0));
      g_pendCore.active = false;
      return;
     }
   if(g_risk.EntriesBlocked()) { g_ev.Defer(0, "ENTRIES_BLOCKED", g_pendCore.dir, "perdita giornaliera/stop operativo"); return; }
   if(g_exec.InRollover()) { g_ev.Defer(0, "ROLLOVER_BLOCKED", g_pendCore.dir, "finestra di rollover"); return; }
   if(!g_exec.TradingAllowed()) { g_ev.Defer(0, "TRADING_DISABLED", g_pendCore.dir, "trading non consentito"); return; }
   if(!g_exec.SpreadOk(g_ind.AtrCore(1))) { g_ev.Defer(0, "SPREAD_TOO_HIGH", g_pendCore.dir, StringFormat("spread %d pt", g_sm.SpreadPoints())); return; }
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
         g_ev.Log(0, "MINLOT_OVERRIDE", g_pendCore.dir, StringFormat("rischio reale %.2f%% (richiesto %.2f%%)", minRiskPct, g_s.coreRiskPct));
         PrintFormat("[CTO] ATTENZIONE: lotto minimo con rischio reale %.1f%% dell'equity (richiesto %.2f%%)", minRiskPct, g_s.coreRiskPct);
        }
      else
        {
         g_ev.Log(0, "RISK_TOO_HIGH", g_pendCore.dir, StringFormat("lotto minimo = %.2f%% dell'equity, limite %.2f%%, tetto %.1f%%",
                  minRiskPct, g_s.coreRiskPct, InpMinLotMaxRiskPct));
         PrintFormat("[CTO] ingresso saltato: il lotto minimo rischierebbe %.1f%% dell'equity (limite %.2f%%, tetto lotto minimo %.1f%%)",
                     minRiskPct, g_s.coreRiskPct, InpMinLotMaxRiskPct);
         g_pendCore.active = false;
         return;
        }
     }
   string why;
   if(!g_risk.CanOpen(g_pendCore.dir, lots, g_pendCore.stopDist, true, why))
     {
      g_ev.Log(0, RiskReasonCode(why), g_pendCore.dir, why + StringFormat(" (%.2f lotti)", lots));
      PrintFormat("[CTO] ingresso principale rifiutato: %s", why);
      g_pendCore.active = false;
      return;
     }
   double px = (g_pendCore.dir > 0) ? g_sm.Ask() : g_sm.Bid();
   double slp = px - g_pendCore.dir * g_pendCore.stopDist;
   SFillInfo fi;
   if(g_exec.Open(g_s.magicCore, g_pendCore.dir, lots, slp, 0.0, "CTO CORE", fi))
     {
      g_cost.OnFill(ROLE_CORE, lots, fi.spreadAtFill, fi.slippage);
      g_log.RememberFill(fi.deal, fi.requested, fi.slippage);
      g_coreStop = g_sm.NormalizePrice(slp);
      g_ev.Log(0, "TRADE_OPENED", g_pendCore.dir, StringFormat("%.2f lotti @ %.5f, spread %.1f pt, slippage %.1f pt", lots, fi.filled,
               fi.spreadAtFill / g_sm.Point(), fi.slippage / g_sm.Point()));
      g_ev.ResetDefer(0);
      PrintFormat("[CTO] principale %s %.2f lotti @ %.5f SL %.5f (spread %.1f pt, slippage %.1f pt)",
                  g_pendCore.dir > 0 ? "LONG" : "SHORT", lots, fi.filled, slp, fi.spreadAtFill / g_sm.Point(), fi.slippage / g_sm.Point());
      g_pendCore.active = false;
     }
   else
      g_ev.Defer(0, "ORDER_FAILED", g_pendCore.dir, "ordine rifiutato dal server (nuovo tentativo al tick successivo)");
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
   g_ev.ResetDefer(1);
   g_ev.Log(1, "SIGNAL", g_pendOv.dir, g_pendOv.shadow ? "ombra (edge monitor)" : "reale");
   PrintFormat("[CTO] segnale overlay %s (%s), edge R medio=%.3f su %d", g_pendOv.dir > 0 ? "LONG" : "SHORT",
               g_pendOv.shadow ? "OMBRA" : "REALE", g_edge.RecentMean(), g_edge.Count());
  }

void TryExecuteOverlay(void)
  {
   if(!g_pendOv.active) return;
   if(TimeCurrent() - g_pendOv.created > g_s.signalExpiryHours * 3600)
     {
      g_ev.Log(1, "SIGNAL_EXPIRED", g_pendOv.dir, "ultimo rinvio: " + g_ev.LastDefer(1));
      g_pendOv.active = false;
      return;
     }
   if(g_risk.EntriesBlocked()) { g_ev.Defer(1, "ENTRIES_BLOCKED", g_pendOv.dir, "perdita giornaliera/stop operativo"); return; }
   if(g_exec.InRollover()) { g_ev.Defer(1, "ROLLOVER_BLOCKED", g_pendOv.dir, "finestra di rollover"); return; }
   ulong t; int d; double v, e, sl; datetime ot;
   if(!GetCore(t, d, v, e, sl, ot)) { g_pendOv.active = false; return; }
   double coreNom = CoreNominalVolume(v);
   double room = g_s.maxRatio * coreNom - (OverlayVolumeReal() + g_book.VirtualVolume(true));
   //--- netting: una riduzione pari al 100% azzererebbe la posizione netta (MT5 la chiuderebbe);
   //    resta sempre almeno un lotto minimo di esposizione nella direzione della principale
   if(g_net && !g_pendOv.shadow) room = MathMin(room, v - g_sm.MinLot());
   double lots = g_sm.NormalizeLotsDown(MathMin(g_s.hStep * coreNom, room));
   if(lots <= 0.0)
     {
      g_ev.Log(1, "LOT_BELOW_MINIMUM", g_pendOv.dir, StringFormat("volume richiesto %.4f, spazio %.4f, lotto minimo %.2f",
               g_s.hStep * coreNom, room, g_sm.MinLot()));
      g_pendOv.active = false;
      return;
     }
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
      g_ev.Log(1, "SHADOW_OPENED", od, StringFormat("%.2f lotti virtuali @ %.5f", lots, l.entry));
      g_pendOv.active = false;
      return;
     }
   if(!g_exec.TradingAllowed()) { g_ev.Defer(1, "TRADING_DISABLED", g_pendOv.dir, "trading non consentito"); return; }
   if(!g_exec.SpreadOk(g_ind.AtrOv(1))) { g_ev.Defer(1, "SPREAD_TOO_HIGH", g_pendOv.dir, StringFormat("spread %d pt", g_sm.SpreadPoints())); return; }
   //--- in hedging il ticket opposto aggiunge nozionale e margine: controlli completi.
   //    in netting l'overlay RIDUCE l'esposizione: nessun controllo di leva/margine necessario.
   string why;
   if(!g_net && !g_risk.CanOpen(od, lots, R, false, why))
     {
      g_ev.Log(1, RiskReasonCode(why), od, why + StringFormat(" (%.2f lotti)", lots));
      PrintFormat("[CTO] overlay rifiutato: %s", why);
      g_pendOv.active = false;
      return;
     }

   if(g_net)
     {
      //--- NETTING: l'overlay riduce la posizione netta; stop/TP gestiti dall'EA
      SFillInfo fi;
      if(!g_exec.Open(g_s.magicOv, od, lots, 0.0, 0.0, "CTO OV net", fi))
        {
         g_ev.Defer(1, "ORDER_FAILED", od, "ordine rifiutato dal server (nuovo tentativo al tick successivo)");
         return;
        }
      g_ev.Log(1, "TRADE_OPENED", od, StringFormat("netting %.2f lotti @ %.5f", lots, fi.filled));
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
      if(en.openTickets > 0)
        {
         g_book.AddEntry(en);
         g_ev.Log(1, "TRADE_OPENED", od, StringFormat("hedge %d ticket, %.2f lotti", en.openTickets, vA + vB));
        }
      else
         g_ev.Log(1, "ORDER_FAILED", od, "nessun ticket aperto");
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
   g_ev.Init(_Symbol, g_s.magicCore, InpTradeLog);
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
   g_ev.Deinit();
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
