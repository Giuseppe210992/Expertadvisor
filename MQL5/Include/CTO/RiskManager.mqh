//+------------------------------------------------------------------+
//|                                              CTO/RiskManager.mqh |
//|   Dimensionamento a rischio fisso, limiti di esposizione, heat   |
//|   di portafoglio, margine, perdita giornaliera, stop operativo.  |
//|   Stato persistente in GlobalVariables (sopravvive ai riavvii).  |
//+------------------------------------------------------------------+
#ifndef CTO_RISKMANAGER_MQH
#define CTO_RISKMANAGER_MQH

#include "Defines.mqh"
#include "SymbolMath.mqh"

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
