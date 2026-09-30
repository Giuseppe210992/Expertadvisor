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

#include "Defines.mqh"

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
