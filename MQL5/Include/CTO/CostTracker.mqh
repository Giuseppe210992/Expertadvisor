//+------------------------------------------------------------------+
//|                                              CTO/CostTracker.mqh |
//|   Contabilita' separata PRINCIPALE / OVERLAY / COSTI:            |
//|   profitto lordo, commissioni, fee, swap, costo spread stimato,  |
//|   slippage misurato, statistiche di spread, report giornaliero.  |
//+------------------------------------------------------------------+
#ifndef CTO_COSTTRACKER_MQH
#define CTO_COSTTRACKER_MQH

#include "Defines.mqh"
#include "SymbolMath.mqh"

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
      m_spSum += sp; m_spN++; m_spMax = MathMax(m_spMax, sp);
      m_daySpSum += sp; m_daySpN++; m_daySpMax = MathMax(m_daySpMax, sp);
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
