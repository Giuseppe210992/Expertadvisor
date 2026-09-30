//+------------------------------------------------------------------+
//|                                                 CTO/TradeLog.mqh |
//|   Registro di OGNI deal dell'EA (ingressi e uscite) in CSV, per  |
//|   l'analisi esterna dei backtest e del conto reale:              |
//|   validation/analyze_mt5.py (stress costi, Monte Carlo, criteri).|
//|   File: Common\Files\CTO_trades_<sym>_<magic>_<tester|live>.csv  |
//+------------------------------------------------------------------+
#ifndef CTO_TRADELOG_MQH
#define CTO_TRADELOG_MQH

#include "Defines.mqh"
#include "SymbolMath.mqh"

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
