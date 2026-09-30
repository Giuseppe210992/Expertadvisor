//+------------------------------------------------------------------+
//|                                                CTO/Execution.mqh |
//|   Invio ordini con filtri di costo: spread massimo, finestra di  |
//|   rollover, retry su requote, misura dello slippage reale.       |
//+------------------------------------------------------------------+
#ifndef CTO_EXECUTION_MQH
#define CTO_EXECUTION_MQH

#include <Trade\Trade.mqh>
#include "Defines.mqh"
#include "SymbolMath.mqh"

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
