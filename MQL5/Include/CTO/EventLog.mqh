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
