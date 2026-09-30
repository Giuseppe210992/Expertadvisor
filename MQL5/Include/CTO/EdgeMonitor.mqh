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

#include "Defines.mqh"

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
